import 'package:flutter_test/flutter_test.dart';
import 'package:one_golf_android_tv/src/models/auth_models.dart';

/// These fixtures were captured live from the cert 1Access API
/// (`GET https://dev.1accessplus.io/apiCert/v2/onegolf/qr-codes` and
/// `.../qr-codes/verify`) — see plans/fase-1-03-autenticacion-qr.md.
void main() {
  group('DeviceAuthorizationResponse', () {
    test('parses the real GET /onegolf/qr-codes payload', () {
      final response = DeviceAuthorizationResponse.fromJson({
        'device_code': 'KOKuEjcUTnPq9oCjhbQnctsdnLeUOrPeJPMFbOxvZps',
        'expires_in': 50000,
        'interval': 5,
        'user_code': '9Q2SFC',
        'verification_uri': 'https://cert.1accessplus.io/idp-onegolf/home',
        'verification_uri_complete':
            'https://cert.1accessplus.io/idp-onegolf/home?user_code=9Q2SFC',
      });

      expect(response.deviceCode, 'KOKuEjcUTnPq9oCjhbQnctsdnLeUOrPeJPMFbOxvZps');
      expect(response.userCode, '9Q2SFC');
      expect(response.interval, 5);
      expect(response.expiresIn, 50000);
      expect(response.isExpired, isFalse);
      expect(response.remainingSeconds, greaterThan(0));
    });
  });

  group('TokenResponse', () {
    test('parses a flat token payload (blob under "token")', () {
      final token = TokenResponse.fromJson({
        'token': 'gAAAAABp...blob',
        'userId': 'user-123',
        'expires_in': 3600,
      });

      expect(token.token, 'gAAAAABp...blob');
      expect(token.accessToken, 'gAAAAABp...blob');
      expect(token.refreshToken, 'gAAAAABp...blob');
      expect(token.userId, 'user-123');
      expect(token.isExpired, isFalse);
    });

    test('parses a refresh-token payload nested under "tokens"', () {
      final token = TokenResponse.fromJson({
        'tokens': {
          'one_access_token': 'gAAAAABp...refreshed',
          'userId': 'user-123',
        },
      });

      expect(token.token, 'gAAAAABp...refreshed');
      expect(token.accessToken, 'gAAAAABp...refreshed');
      expect(token.refreshToken, 'gAAAAABp...refreshed');
    });
  });
}
