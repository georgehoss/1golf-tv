import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/auth_models.dart';

/// Service to securely store authentication tokens and user info.
class SecureStorageService {
  static const String _keyAccessToken = 'auth_access_token';
  static const String _keyRefreshToken = 'auth_refresh_token';
  static const String _keyTokenResponse = 'auth_token_response';
  static const String _keyUserInfo = 'auth_user_info';
  static const String _keySessionId = 'auth_session_id';

  final FlutterSecureStorage _storage;

  SecureStorageService()
      : _storage = const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
          iOptions: IOSOptions(
            accessibility: KeychainAccessibility.first_unlock,
          ),
        );

  Future<void> saveTokenResponse(TokenResponse tokenResponse) async {
    try {
      await _storage.write(
        key: _keyAccessToken,
        value: tokenResponse.accessToken,
      );
      await _storage.write(
        key: _keyRefreshToken,
        value: tokenResponse.refreshToken,
      );
      await _storage.write(
        key: _keyTokenResponse,
        value: json.encode(tokenResponse.toJson()),
      );
    } catch (e) {
      debugPrint('❌ Error saving token response: $e');
      rethrow;
    }
  }

  Future<TokenResponse?> getTokenResponse() async {
    try {
      final tokenResponseStr = await _storage.read(key: _keyTokenResponse);
      if (tokenResponseStr == null) return null;

      final tokenData = json.decode(tokenResponseStr) as Map<String, dynamic>;
      return TokenResponse.fromJson(tokenData);
    } catch (e) {
      debugPrint('❌ Error getting token response: $e');
      return null;
    }
  }

  Future<void> saveUserInfo(UserInfo userInfo) async {
    try {
      await _storage.write(
        key: _keyUserInfo,
        value: json.encode(userInfo.toJson()),
      );
    } catch (e) {
      debugPrint('❌ Error saving user info: $e');
      rethrow;
    }
  }

  Future<UserInfo?> getUserInfo() async {
    try {
      final userInfoStr = await _storage.read(key: _keyUserInfo);
      if (userInfoStr == null) return null;

      final userData = json.decode(userInfoStr) as Map<String, dynamic>;
      return UserInfo.fromJson(userData);
    } catch (e) {
      debugPrint('❌ Error getting user info: $e');
      return null;
    }
  }

  Future<void> saveSessionId(String sessionId) async {
    try {
      await _storage.write(key: _keySessionId, value: sessionId);
    } catch (e) {
      debugPrint('❌ Error saving session ID: $e');
    }
  }

  Future<String?> getSessionId() async {
    try {
      return await _storage.read(key: _keySessionId);
    } catch (e) {
      debugPrint('❌ Error getting session ID: $e');
      return null;
    }
  }

  Future<void> clearAll() async {
    try {
      await _storage.delete(key: _keyAccessToken);
      await _storage.delete(key: _keyRefreshToken);
      await _storage.delete(key: _keyTokenResponse);
      await _storage.delete(key: _keyUserInfo);
      await _storage.delete(key: _keySessionId);
    } catch (e) {
      debugPrint('❌ Error clearing auth data: $e');
      rethrow;
    }
  }

  Future<bool> hasStoredCredentials() async {
    try {
      final token = await _storage.read(key: _keyAccessToken);
      return token != null && token.isNotEmpty;
    } catch (e) {
      debugPrint('❌ Error checking stored credentials: $e');
      return false;
    }
  }
}
