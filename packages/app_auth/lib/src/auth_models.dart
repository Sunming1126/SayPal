enum AuthProviderType { password, emailCode, google, apple }

class EmailCodeChallenge {
  const EmailCodeChallenge({
    required this.challengeId,
    required this.expiresInSeconds,
    required this.resendAfterSeconds,
  });

  final String challengeId;
  final int expiresInSeconds;
  final int resendAfterSeconds;
}

class AuthSession {
  const AuthSession({
    required this.userId,
    required this.displayName,
    required this.email,
    this.isMock = false,
    this.provider = AuthProviderType.password,
  });

  final String userId;
  final String displayName;
  final String email;
  final bool isMock;
  final AuthProviderType provider;

  String get accountLabel => email.isEmpty ? displayName : email;
}

class AuthFailure implements Exception {
  const AuthFailure(this.code, [this.details]);

  final String code;
  final String? details;

  @override
  String toString() =>
      details == null ? 'AuthFailure($code)' : 'AuthFailure($code, $details)';
}
