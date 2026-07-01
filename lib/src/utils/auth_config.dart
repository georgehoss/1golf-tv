/// Configuration for 1Golf's authentication (1Access) on TV.
///
/// TV uses the QR device-flow (the user scans a code with their phone and
/// authorizes there), unlike the mobile app which uses a PKCE + WebView flow.
/// See `One-Golf.postman_collection.json` and `plans/fase-1-03-autenticacion-qr.md`.
class AuthConfig {
  // 1Access API — certification environment for now.
  // TODO(prod): switch cert/dev to production once available.
  static const String apiBaseUrl = 'https://dev.1accessplus.io/apiCert/v2';
  static const String appName = 'onegolf';

  static String get _appBase => '$apiBaseUrl/$appName';

  static String get qrCodesUrl => '$_appBase/qr-codes';
  static String get qrCodesVerifyUrl => '$_appBase/qr-codes/verify';
  static String get validateTokenUrl => '$_appBase/validation-token';
  static String get refreshTokenUrl => '$_appBase/refresh-token';
  static String get revokeTokenUrl => '$_appBase/revoke-token';
  static String get userInfoUrl => '$_appBase/user-info';
  static String get sessionsUrl => '$_appBase/sessions';
}
