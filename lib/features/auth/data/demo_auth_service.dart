import 'dart:async';

import 'package:app_auth/app_auth.dart';

/// 离线演示登录服务：未配置账号服务（`SAYPAL_ACCOUNT_API_BASE_URL`）时使用。
/// 所有登录方式都返回一个本机模拟会话，绝不发起网络请求。
class DemoAuthService implements AuthService {
  final StreamController<AuthSession?> _controller =
      StreamController<AuthSession?>.broadcast();

  AuthSession? _session;

  @override
  Stream<AuthSession?> authStateChanges() async* {
    // 新订阅者先拿到当前值，再跟随后续变化。
    yield _session;
    yield* _controller.stream;
  }

  @override
  Future<AuthSession?> restore() async => _session;

  @override
  Future<AuthSession> register({
    required String email,
    required String displayName,
    required String password,
  }) async =>
      _signIn(email, displayName);

  @override
  Future<AuthSession> registerWithEmailCode({
    required String email,
    required String displayName,
    required String password,
    required String challengeId,
    required String code,
  }) async =>
      _signIn(email, displayName);

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async =>
      _signIn(email, email.isEmpty ? '演示用户' : email);

  @override
  Future<EmailCodeChallenge> requestEmailCode(String email) async =>
      const EmailCodeChallenge(
        challengeId: 'demo-challenge',
        expiresInSeconds: 600,
        resendAfterSeconds: 60,
      );

  @override
  Future<AuthSession> signInWithEmailCode({
    required String email,
    required String challengeId,
    required String code,
  }) async =>
      _signIn(email, email.isEmpty ? '演示用户' : email);

  @override
  Future<AuthSession> signInWithGoogle() async =>
      _signIn('demo.google@saypal.local', '演示用户');

  @override
  Future<AuthSession> signInWithApple() async =>
      _signIn('demo.apple@saypal.local', '演示用户');

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<String> getIdToken({bool forceRefresh = false}) async =>
      _session == null ? throw const AuthFailure('not-authenticated') : 'demo-token';

  @override
  Future<void> logout() async {
    _session = null;
    _controller.add(null);
  }

  @override
  Future<void> deleteAccount() async => logout();

  AuthSession _signIn(String email, String displayName) {
    final session = AuthSession(
      userId: 'demo-user',
      displayName: displayName,
      email: email,
      isMock: true,
    );
    _session = session;
    _controller.add(session);
    return session;
  }
}
