import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/auth_models.dart';
import '../utils/auth_config.dart';

/// Distinguishes network failures (host unreachable, no connection) from
/// explicit server responses, so callers can avoid logging the user out on a
/// transient connectivity issue.
class AuthNetworkException implements Exception {
  final Object cause;
  AuthNetworkException(this.cause);
  @override
  String toString() => 'AuthNetworkException: $cause';
}

bool isNetworkError(Object e) =>
    e is SocketException ||
    e is http.ClientException ||
    e is AuthNetworkException ||
    e.toString().contains('SocketException') ||
    e.toString().contains('Failed host lookup');

/// Handles the QR device-flow login and session management against the
/// 1Access API (see AuthConfig for the endpoints).
class AuthApiService {
  /// Request a new QR device code.
  ///
  /// GET {AuthConfig.qrCodesUrl}
  /// Response: { device_code, expires_in, interval, user_code,
  ///             verification_uri, verification_uri_complete }
  Future<DeviceAuthorizationResponse> requestDeviceAuthorization() async {
    try {
      debugPrint('🔄 Requesting QR device code...');

      final response = await http.get(
        Uri.parse(AuthConfig.qrCodesUrl),
        headers: {'Accept': 'application/json'},
      );

      debugPrint('📥 qr-codes response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        debugPrint('✅ QR device code generated: ${data['user_code']}');
        return DeviceAuthorizationResponse.fromJson(data);
      }
      throw Exception('Error al solicitar el código QR');
    } catch (e) {
      debugPrint('❌ Error requesting QR device code: $e');
      if (isNetworkError(e)) throw AuthNetworkException(e);
      rethrow;
    }
  }

  /// Poll to check whether the user has authorized the device code.
  ///
  /// GET {AuthConfig.qrCodesVerifyUrl}?device_code=xxx
  ///
  /// The API always answers 200; while pending it returns
  /// `{ "error": "authorization_pending", ... }`. Any other `error` value is
  /// a real failure (expired/invalid code). On success it returns the token
  /// payload directly (no `error` key).
  Future<TokenResponse?> pollDeviceAuthorization({
    required String deviceCode,
  }) async {
    try {
      final uri = Uri.parse(
        AuthConfig.qrCodesVerifyUrl,
      ).replace(queryParameters: {'device_code': deviceCode});

      final response = await http.get(uri, headers: {'Accept': 'application/json'});

      if (response.statusCode != 200) {
        debugPrint('⏳ qr-codes/verify status ${response.statusCode}, retrying...');
        return null;
      }

      final data = json.decode(response.body) as Map<String, dynamic>;

      if (data.containsKey('error')) {
        final error = data['error'] as String?;
        if (error == 'authorization_pending') {
          return null;
        }
        debugPrint('❌ qr-codes/verify error: $error — ${data['error_description']}');
        throw Exception(data['error_description'] as String? ?? error);
      }

      debugPrint('🎉 QR device code authorized');
      return TokenResponse.fromJson(data);
    } catch (e) {
      if (isNetworkError(e)) {
        debugPrint('🌐 Network error polling QR code, will retry: $e');
        return null;
      }
      rethrow;
    }
  }

  /// POST {AuthConfig.validateTokenUrl}  Body: { "token": "`blob`" }
  Future<bool> validateToken({required String token}) async {
    try {
      final response = await http.post(
        Uri.parse(AuthConfig.validateTokenUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({'token': token}),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint('❌ Token validation failed (${response.statusCode})');
        return false;
      }

      try {
        final data = json.decode(response.body);
        if (data is Map<String, dynamic>) {
          final status = data['status_token'] ?? data['valid'] ?? data['status'];
          if (status is bool) return status;
        }
      } catch (_) {}

      return true;
    } catch (e) {
      // A network failure doesn't mean the token is invalid: keep the
      // session alive and let the caller retry later.
      if (isNetworkError(e)) {
        debugPrint('🌐 Network error validating token, keeping session: $e');
        return true;
      }
      debugPrint('❌ Error validating token: $e');
      return false;
    }
  }

  /// POST {AuthConfig.refreshTokenUrl}  Body: { "token": "`blob`" }
  Future<TokenResponse> refreshToken({required String token}) async {
    try {
      final response = await http.post(
        Uri.parse(AuthConfig.refreshTokenUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({'token': token}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return TokenResponse.fromJson(data);
      }

      try {
        final errorData = json.decode(response.body) as Map<String, dynamic>;
        final detail = errorData['detail'] as String? ?? 'Error al refrescar token';
        throw Exception(detail);
      } catch (_) {
        throw Exception('refreshing token no valid');
      }
    } catch (e) {
      if (isNetworkError(e)) throw AuthNetworkException(e);
      rethrow;
    }
  }

  /// POST {AuthConfig.revokeTokenUrl}  Body: { "token": "`blob`" }
  Future<bool> logout({required String token}) async {
    try {
      final response = await http.post(
        Uri.parse(AuthConfig.revokeTokenUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({'token': token}),
      );
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      debugPrint('❌ Error during server revoke: $e');
      // Continue with local logout regardless of server response.
      return true;
    }
  }
}
