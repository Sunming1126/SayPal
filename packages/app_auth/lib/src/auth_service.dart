import 'auth_models.dart';

abstract interface class AuthService {
  Stream<AuthSession?> authStateChanges();

  Future<AuthSession?> restore();

  Future<AuthSession> register({
    required String email,
    required String displayName,
    required String password,
  });

  Future<AuthSession> registerWithEmailCode({
    required String email,
    required String displayName,
    required String password,
    required String challengeId,
    required String code,
  });

  Future<AuthSession> login({required String email, required String password});

  Future<EmailCodeChallenge> requestEmailCode(String email);

  Future<AuthSession> signInWithEmailCode({
    required String email,
    required String challengeId,
    required String code,
  });

  Future<AuthSession> signInWithGoogle();

  Future<AuthSession> signInWithApple();

  Future<void> sendPasswordResetEmail(String email);

  /// Returns the current Firebase ID token for authenticating with an app's
  /// own backend. The backend must verify this token with Firebase Admin SDK.
  Future<String> getIdToken({bool forceRefresh = false});

  Future<void> logout();

  /// Permanently deletes the account. Calls the backend, which removes the
  /// Firebase user record and all server-side data for the UID, then clears
  /// the local session. Required for App Store account-deletion compliance.
  Future<void> deleteAccount();
}
