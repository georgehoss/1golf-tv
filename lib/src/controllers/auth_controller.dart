import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/auth_api_service.dart';
import '../services/secure_storage_service.dart';
import '../models/auth_models.dart';

/// Controller for the TV app's QR device-flow authentication against 1Access.
class AuthController extends GetxController {
  final AuthApiService _apiService = AuthApiService();
  final SecureStorageService _storageService = SecureStorageService();

  final RxBool isLoading = false.obs;
  final RxBool isAuthenticated = false.obs;
  final RxString errorMessage = ''.obs;

  final Rx<TokenResponse?> tokenResponse = Rx<TokenResponse?>(null);
  final Rx<UserInfo?> userInfo = Rx<UserInfo?>(null);

  final Rx<DeviceAuthorizationResponse?> deviceAuth =
      Rx<DeviceAuthorizationResponse?>(null);
  final RxInt remainingSeconds = 0.obs;
  final RxBool isPolling = false.obs;

  Timer? _tokenRefreshTimer;
  Timer? _pollingTimer;
  Timer? _countdownTimer;

  DateTime? _lastValidationTime;

  @override
  void onInit() {
    super.onInit();
    _initializeAuth();
  }

  @override
  void onClose() {
    _tokenRefreshTimer?.cancel();
    _pollingTimer?.cancel();
    _countdownTimer?.cancel();
    super.onClose();
  }

  Future<void> _initializeAuth() async {
    try {
      await _checkStoredSession();
    } catch (e) {
      debugPrint('❌ Error initializing auth: $e');
    }
  }

  Future<void> _checkStoredSession() async {
    final storedToken = await _storageService.getTokenResponse();
    final storedUser = await _storageService.getUserInfo();

    if (storedToken == null) return;

    if (storedToken.isExpired) {
      tokenResponse.value = storedToken;
      await _refreshAccessToken();
      return;
    }

    tokenResponse.value = storedToken;
    userInfo.value = storedUser;

    if (storedToken.isExpiringSoon) {
      await _refreshAccessToken();
    }

    final valid = await _validateCurrentSession();
    isAuthenticated.value = valid && tokenResponse.value != null;
    if (isAuthenticated.value) {
      _startTokenRefreshTimer();
    }
  }

  /// Start the QR login flow: request a device code and begin polling.
  Future<void> startQRLogin() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final authResponse = await _apiService.requestDeviceAuthorization();
      deviceAuth.value = authResponse;
      remainingSeconds.value = authResponse.expiresIn;

      _startCountdown();
      _startPolling(authResponse.deviceCode, authResponse.interval);
    } catch (e) {
      debugPrint('❌ Error starting QR login: $e');
      errorMessage.value = 'Error al iniciar el login con QR';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> refreshQRCode() async {
    _stopPolling();
    await startQRLogin();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (remainingSeconds.value > 0) {
        remainingSeconds.value--;
      } else {
        timer.cancel();
        if (!isAuthenticated.value && deviceAuth.value != null) {
          refreshQRCode();
        }
      }
    });
  }

  void _startPolling(String deviceCode, int intervalSeconds) {
    _pollingTimer?.cancel();
    isPolling.value = true;

    _pollingTimer = Timer.periodic(Duration(seconds: intervalSeconds), (
      timer,
    ) async {
      if (!isPolling.value || isAuthenticated.value) {
        timer.cancel();
        return;
      }

      if (deviceAuth.value?.isExpired == true) {
        timer.cancel();
        isPolling.value = false;
        return;
      }

      TokenResponse? token;
      try {
        token = await _apiService.pollDeviceAuthorization(
          deviceCode: deviceCode,
        );
      } catch (e) {
        debugPrint('❌ QR code rejected: $e');
        timer.cancel();
        isPolling.value = false;
        _countdownTimer?.cancel();
        errorMessage.value = 'El código QR ya no es válido';
        deviceAuth.value = null;
        return;
      }

      if (token != null) {
        timer.cancel();
        isPolling.value = false;
        _countdownTimer?.cancel();
        await _handleSuccessfulAuth(token);
      }
    });
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _countdownTimer?.cancel();
    isPolling.value = false;
    deviceAuth.value = null;
    remainingSeconds.value = 0;
  }

  Future<void> _handleSuccessfulAuth(TokenResponse token) async {
    try {
      final user = UserInfo(
        userId: token.userId,
        email: '',
        maxSessions: 3,
        activeSessions: 1,
        subscriptionStatus: 'active',
      );

      await _storageService.saveTokenResponse(token);
      await _storageService.saveUserInfo(user);

      tokenResponse.value = token;
      userInfo.value = user;
      isAuthenticated.value = true;
      isLoading.value = false;

      _startTokenRefreshTimer();

      Get.offAllNamed('/home');
      Get.snackbar(
        '¡Bienvenido!',
        'Has iniciado sesión correctamente',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 3),
      );
    } catch (e) {
      debugPrint('❌ Error handling successful auth: $e');
      errorMessage.value = 'Error al completar la autenticación';
    }
  }

  Future<void> _refreshAccessToken() async {
    final currentToken = tokenResponse.value;
    if (currentToken == null) {
      await logout();
      return;
    }

    try {
      final newToken = await _apiService.refreshToken(token: currentToken.token);
      final merged = newToken.userId.isEmpty
          ? newToken.copyWith(userId: currentToken.userId)
          : newToken;

      await _storageService.saveTokenResponse(merged);
      tokenResponse.value = merged;

      _startTokenRefreshTimer();
    } catch (e) {
      if (isNetworkError(e)) {
        debugPrint('🌐 Network error refreshing token, keeping session: $e');
        return;
      }

      debugPrint('❌ Refresh failed, logging out: $e');
      Get.snackbar(
        'Sesión expirada',
        'Tu sesión ha expirado. Por favor, inicia sesión de nuevo.',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 3),
      );
      await logout();
    }
  }

  Future<bool> _validateCurrentSession() async {
    final token = tokenResponse.value;
    if (token == null) return false;

    final isValid = await _apiService.validateToken(token: token.token);
    _lastValidationTime = DateTime.now();
    if (!isValid) {
      await _refreshAccessToken();
      return tokenResponse.value != null;
    }
    return true;
  }

  /// Re-validate the session with the server if more than 5 minutes have
  /// passed since the last check (called when the app resumes from
  /// background, not on every frame).
  Future<void> validateSessionIfNeeded() async {
    if (!isAuthenticated.value) return;

    if (_lastValidationTime != null &&
        DateTime.now().difference(_lastValidationTime!).inMinutes < 5) {
      return;
    }

    await _validateCurrentSession();
  }

  void _startTokenRefreshTimer() {
    _tokenRefreshTimer?.cancel();

    final token = tokenResponse.value;
    if (token == null) return;

    final refreshTime = token.expiresAt.subtract(const Duration(minutes: 5));
    final now = DateTime.now();

    if (refreshTime.isBefore(now)) {
      _refreshAccessToken();
      return;
    }

    _tokenRefreshTimer = Timer(refreshTime.difference(now), () {
      _refreshAccessToken();
    });
  }

  Future<void> logout() async {
    try {
      isLoading.value = true;
      _stopPolling();

      final token = tokenResponse.value;
      if (token != null && token.token.isNotEmpty) {
        await _apiService.logout(token: token.token);
      }

      _tokenRefreshTimer?.cancel();
      await _storageService.clearAll();

      tokenResponse.value = null;
      userInfo.value = null;
      isAuthenticated.value = false;
      errorMessage.value = '';
      isLoading.value = false;

      Get.offAllNamed('/login');
      Get.snackbar(
        'Sesión cerrada',
        'Has cerrado sesión correctamente',
        backgroundColor: Colors.grey[800],
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      debugPrint('❌ Error during logout: $e');
      isLoading.value = false;
      Get.offAllNamed('/login');
    }
  }

  bool get hasValidSession =>
      isAuthenticated.value &&
      tokenResponse.value != null &&
      !tokenResponse.value!.isExpired;

  Future<void> restoreSession() async {
    await _checkStoredSession();
  }

  String get formattedRemainingTime {
    final minutes = remainingSeconds.value ~/ 60;
    final seconds = remainingSeconds.value % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
