/// Encrypted token blob returned by the 1Access session endpoints
/// (`validation-token` / `refresh-token` / `revoke-token` / QR `qr-codes/verify`).
/// It is not a classic access/refresh pair: the same opaque `token` string is
/// what gets sent back on every subsequent call.
class TokenResponse {
  final String token;
  final String accessToken;
  final String refreshToken;
  final String refreshTokenId;
  final String tokenType;
  final String userId;
  final String? client;
  final String? idToken;
  final int? expiresIn;
  final DateTime expiresAt;

  TokenResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.refreshTokenId,
    required this.userId,
    String? token,
    this.tokenType = 'Bearer',
    this.client,
    this.idToken,
    this.expiresIn,
    DateTime? expiresAt,
  })  : token = token ?? accessToken,
        expiresAt = expiresAt ??
            (expiresIn != null
                ? DateTime.now().add(Duration(seconds: expiresIn))
                : DateTime.now().add(const Duration(hours: 12)));

  factory TokenResponse.fromJson(Map<String, dynamic> json) {
    // El endpoint de refresh puede anidar los tokens bajo "tokens".
    final tokensData = json.containsKey('tokens')
        ? json['tokens'] as Map<String, dynamic>
        : json;

    // refresh-token devuelve el nuevo blob en `one_access_token`.
    final oneAccess = tokensData['one_access_token'] as String?;

    return TokenResponse(
      token: (tokensData['token'] ?? oneAccess ?? tokensData['access_token'])
          as String?,
      accessToken:
          (tokensData['access_token'] ?? oneAccess ?? tokensData['token'] ?? '')
              as String,
      refreshToken: (tokensData['refresh_token'] ??
          oneAccess ??
          tokensData['token'] ??
          '') as String,
      refreshTokenId: tokensData['refresh_token_id'] as String? ?? '',
      userId: (tokensData['userId'] ?? tokensData['user_id'] ?? '') as String,
      tokenType: tokensData['token_type'] as String? ?? 'Bearer',
      client: tokensData['client'] as String?,
      idToken: tokensData['id_token'] as String?,
      expiresIn: tokensData['expires_in'] as int?,
    );
  }

  /// Copy preserving fields the refresh-token response doesn't resend
  /// (e.g. `userId`).
  TokenResponse copyWith({String? userId}) => TokenResponse(
        token: token,
        accessToken: accessToken,
        refreshToken: refreshToken,
        refreshTokenId: refreshTokenId,
        userId: userId ?? this.userId,
        tokenType: tokenType,
        client: client,
        idToken: idToken,
        expiresIn: expiresIn,
        expiresAt: expiresAt,
      );

  Map<String, dynamic> toJson() {
    return {
      'token': token,
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'refresh_token_id': refreshTokenId,
      'token_type': tokenType,
      'userId': userId,
      'client': client,
      'id_token': idToken,
      'expires_in': expiresIn,
      'expires_at': expiresAt.toIso8601String(),
    };
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  bool get isExpiringSoon {
    final now = DateTime.now();
    final twoHoursBeforeExpiry = expiresAt.subtract(const Duration(hours: 2));
    return now.isAfter(twoHoursBeforeExpiry);
  }
}

class UserInfo {
  final String userId;
  final String email;
  final String? name;
  final String? phoneNumber;
  final Map<String, dynamic>? customAttributes;
  final int? maxSessions;
  final int? activeSessions;
  final String? subscriptionStatus;
  final DateTime? subscriptionExpiresAt;

  UserInfo({
    required this.userId,
    required this.email,
    this.name,
    this.phoneNumber,
    this.customAttributes,
    this.maxSessions,
    this.activeSessions,
    this.subscriptionStatus,
    this.subscriptionExpiresAt,
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    return UserInfo(
      userId: json['user_id'] as String? ?? json['userId'] as String? ?? '',
      email: json['email'] as String? ?? '',
      name: json['name'] as String?,
      phoneNumber:
          json['phone_number'] as String? ?? json['phoneNumber'] as String?,
      customAttributes: json['custom_attributes'] as Map<String, dynamic>? ??
          json['customAttributes'] as Map<String, dynamic>?,
      maxSessions: json['max_sessions'] as int? ?? json['maxSessions'] as int?,
      activeSessions:
          json['active_sessions'] as int? ?? json['activeSessions'] as int?,
      subscriptionStatus: json['subscription_status'] as String? ??
          json['subscriptionStatus'] as String?,
      subscriptionExpiresAt: json['subscription_expires_at'] != null
          ? DateTime.parse(json['subscription_expires_at'] as String)
          : (json['subscriptionExpiresAt'] != null
              ? DateTime.parse(json['subscriptionExpiresAt'] as String)
              : null),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'email': email,
      'name': name,
      'phone_number': phoneNumber,
      'custom_attributes': customAttributes,
      'max_sessions': maxSessions,
      'active_sessions': activeSessions,
      'subscription_status': subscriptionStatus,
      'subscription_expires_at': subscriptionExpiresAt?.toIso8601String(),
    };
  }

  bool get hasReachedSessionLimit {
    if (maxSessions == null || activeSessions == null) return false;
    return activeSessions! >= maxSessions!;
  }

  bool get hasActiveSubscription {
    if (subscriptionStatus == null) return true;
    if (subscriptionStatus != 'active') return false;
    if (subscriptionExpiresAt == null) return true;
    return DateTime.now().isBefore(subscriptionExpiresAt!);
  }
}

/// Response of `GET /{app}/qr-codes` (device authorization for QR login).
class DeviceAuthorizationResponse {
  final String? nextRequest;
  final String deviceCode;
  final int expiresIn;
  final int interval;
  final String userCode;
  final String verificationUri;
  final String verificationUriComplete;
  final DateTime createdAt;

  DeviceAuthorizationResponse({
    this.nextRequest,
    required this.deviceCode,
    required this.expiresIn,
    required this.interval,
    required this.userCode,
    required this.verificationUri,
    required this.verificationUriComplete,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory DeviceAuthorizationResponse.fromJson(Map<String, dynamic> json) {
    return DeviceAuthorizationResponse(
      nextRequest: json['next_request'] as String?,
      deviceCode: json['device_code'] as String,
      expiresIn: json['expires_in'] as int,
      interval: json['interval'] as int,
      userCode: json['user_code'] as String,
      verificationUri: json['verification_uri'] as String,
      verificationUriComplete: json['verification_uri_complete'] as String,
    );
  }

  bool get isExpired {
    final expirationTime = createdAt.add(Duration(seconds: expiresIn));
    return DateTime.now().isAfter(expirationTime);
  }

  int get remainingSeconds {
    final expirationTime = createdAt.add(Duration(seconds: expiresIn));
    final remaining = expirationTime.difference(DateTime.now()).inSeconds;
    return remaining > 0 ? remaining : 0;
  }
}
