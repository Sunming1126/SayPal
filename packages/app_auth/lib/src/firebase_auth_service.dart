import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'account_client.dart';
import 'auth_models.dart';
import 'auth_service.dart';
import 'email_otp_client.dart';

class FirebaseAuthService implements AuthService {
  FirebaseAuthService({
    FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
    this.emailOtpClient,
    this.accountClient,
    this.fallbackDisplayName = 'App user',
  }) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
       _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;
  final EmailOtpClient? emailOtpClient;
  final AccountClient? accountClient;
  final String fallbackDisplayName;
  Future<void>? _googleInitialization;

  Future<void> _initializeGoogle() =>
      _googleInitialization ??= _googleSignIn.initialize();

  @override
  Stream<AuthSession?> authStateChanges() => _firebaseAuth
      .authStateChanges()
      .map((user) => user == null ? null : _sessionFromUser(user));

  @override
  Future<AuthSession?> restore() async {
    final user = _firebaseAuth.currentUser;
    return user == null ? null : _sessionFromUser(user);
  }

  @override
  Future<AuthSession> register({
    required String email,
    required String displayName,
    required String password,
  }) async {
    _validateEmail(email);
    _validatePassword(password);
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = _requireUser(credential);
      final trimmedName = displayName.trim();
      if (trimmedName.isNotEmpty) {
        await user.updateDisplayName(trimmedName);
        await user.reload();
      }
      return _sessionFromUser(
        _firebaseAuth.currentUser ?? user,
        preferredProvider: AuthProviderType.password,
      );
    } on FirebaseAuthException catch (error) {
      throw _failureFromFirebase(error);
    }
  }

  @override
  Future<AuthSession> registerWithEmailCode({
    required String email,
    required String displayName,
    required String password,
    required String challengeId,
    required String code,
  }) async {
    _validateEmail(email);
    _validatePassword(password);
    if (!RegExp(r'^\d{6}$').hasMatch(code.trim())) {
      throw const AuthFailure('email-code-invalid');
    }
    final client = emailOtpClient;
    if (client == null) throw const AuthFailure('email-code-not-configured');
    final normalizedEmail = email.trim().toLowerCase();
    final requestedDisplayName = displayName.trim();
    try {
      final currentUser = _firebaseAuth.currentUser;
      late final User user;
      if (_isVerifiedUserForEmail(currentUser, normalizedEmail)) {
        user = currentUser!;
      } else {
        final customToken = await client.verifyCode(
          email: normalizedEmail,
          challengeId: challengeId,
          code: code.trim(),
        );
        final credential = await _firebaseAuth.signInWithCustomToken(
          customToken,
        );
        user = _requireUser(credential);
      }
      await user.updatePassword(password);
      await _updateRegistrationProfileBestEffort(user, requestedDisplayName);
      return _sessionFromUser(
        _firebaseAuth.currentUser ?? user,
        preferredProvider: AuthProviderType.password,
        preferredDisplayName: requestedDisplayName,
      );
    } on AuthFailure {
      rethrow;
    } on FirebaseAuthException catch (error) {
      throw _failureFromFirebase(error);
    } catch (error) {
      throw AuthFailure('network-request-failed', error.toString());
    }
  }

  bool _isVerifiedUserForEmail(User? user, String email) =>
      user != null &&
      user.emailVerified &&
      user.email?.trim().toLowerCase() == email;

  Future<void> _updateRegistrationProfileBestEffort(
    User user,
    String displayName,
  ) async {
    if (displayName.isNotEmpty) {
      try {
        await user.updateDisplayName(displayName);
      } on FirebaseAuthException {
        // Authentication and password setup already succeeded. The profile can
        // be retried later without forcing the user to reuse a consumed OTP.
      }
    }
    try {
      await user.reload();
    } on FirebaseAuthException {
      // A refresh failure must not turn a completed registration into an
      // apparent failure. Firebase keeps the authenticated user locally.
    }
  }

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    _validateEmail(email);
    _validatePassword(password);
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return _sessionFromUser(
        _requireUser(credential),
        preferredProvider: AuthProviderType.password,
      );
    } on FirebaseAuthException catch (error) {
      throw _failureFromFirebase(error);
    }
  }

  @override
  Future<EmailCodeChallenge> requestEmailCode(String email) async {
    _validateEmail(email);
    final client = emailOtpClient;
    if (client == null) throw const AuthFailure('email-code-not-configured');
    try {
      return await client.requestCode(email.trim().toLowerCase());
    } on AuthFailure {
      rethrow;
    } catch (error) {
      throw AuthFailure('network-request-failed', error.toString());
    }
  }

  @override
  Future<AuthSession> signInWithEmailCode({
    required String email,
    required String challengeId,
    required String code,
  }) async {
    _validateEmail(email);
    if (!RegExp(r'^\d{6}$').hasMatch(code.trim())) {
      throw const AuthFailure('email-code-invalid');
    }
    final client = emailOtpClient;
    if (client == null) throw const AuthFailure('email-code-not-configured');
    try {
      final customToken = await client.verifyCode(
        email: email.trim().toLowerCase(),
        challengeId: challengeId,
        code: code.trim(),
      );
      final credential = await _firebaseAuth.signInWithCustomToken(customToken);
      return _sessionFromUser(
        _requireUser(credential),
        preferredProvider: AuthProviderType.emailCode,
      );
    } on AuthFailure {
      rethrow;
    } on FirebaseAuthException catch (error) {
      throw _failureFromFirebase(error);
    } catch (error) {
      throw AuthFailure('network-request-failed', error.toString());
    }
  }

  @override
  Future<AuthSession> signInWithGoogle() async {
    try {
      await _initializeGoogle();
      final googleUser = await _googleSignIn.authenticate();
      final idToken = googleUser.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const AuthFailure('google-token-missing');
      }
      final credential = await _firebaseAuth.signInWithCredential(
        GoogleAuthProvider.credential(idToken: idToken),
      );
      return _sessionFromUser(
        _requireUser(credential),
        preferredProvider: AuthProviderType.google,
      );
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        throw const AuthFailure('cancelled');
      }
      throw AuthFailure('google-${error.code.name}', error.description);
    } on FirebaseAuthException catch (error) {
      throw _failureFromFirebase(error);
    }
  }

  @override
  Future<AuthSession> signInWithApple() async {
    try {
      final provider = AppleAuthProvider()
        ..addScope('email')
        ..addScope('name');
      final credential = await _firebaseAuth.signInWithProvider(provider);
      return _sessionFromUser(
        _requireUser(credential),
        preferredProvider: AuthProviderType.apple,
      );
    } on FirebaseAuthException catch (error) {
      throw _failureFromFirebase(error);
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    _validateEmail(email);
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (error) {
      throw _failureFromFirebase(error);
    }
  }

  @override
  Future<String> getIdToken({bool forceRefresh = false}) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) throw const AuthFailure('not-authenticated');
    try {
      final token = await user.getIdToken(forceRefresh);
      if (token == null || token.isEmpty) {
        throw const AuthFailure('token-missing');
      }
      return token;
    } on FirebaseAuthException catch (error) {
      throw _failureFromFirebase(error);
    }
  }

  @override
  Future<void> logout() async {
    await _firebaseAuth.signOut();
    try {
      await _initializeGoogle();
      await _googleSignIn.signOut();
    } on GoogleSignInException {
      // Firebase has already signed out. Google may have no active session.
    }
  }

  @override
  Future<void> deleteAccount() async {
    final client = accountClient;
    if (client == null) {
      throw const AuthFailure('account-deletion-not-configured');
    }
    // Mint a fresh ID token so the backend can verify the caller before
    // deleting. getIdToken throws 'not-authenticated' when there is no user,
    // which surfaces a clear failure before any network call.
    final token = await getIdToken(forceRefresh: true);
    try {
      await client.deleteAccount(token);
    } on AuthFailure {
      rethrow;
    } catch (error) {
      throw AuthFailure('network-request-failed', error.toString());
    }
    // The backend has removed the Firebase user via the Admin SDK; clear the
    // now-invalid local session. signOut() is local and does not require the
    // (deleted) user to still exist server-side.
    await _firebaseAuth.signOut();
    try {
      await _initializeGoogle();
      await _googleSignIn.signOut();
    } on GoogleSignInException {
      // Best-effort: the Firebase session is already gone.
    }
  }

  void _validateEmail(String email) {
    final value = email.trim();
    if (!value.contains('@') || value.length < 5) {
      throw const AuthFailure('invalid-email');
    }
  }

  void _validatePassword(String password) {
    if (password.length < 6) {
      throw const AuthFailure('weak-password');
    }
  }

  User _requireUser(UserCredential credential) {
    final user = credential.user;
    if (user == null) throw const AuthFailure('missing-user');
    return user;
  }

  AuthSession _sessionFromUser(
    User user, {
    AuthProviderType? preferredProvider,
    String? preferredDisplayName,
  }) {
    final email = user.email?.trim() ?? '';
    final displayName = user.displayName?.trim();
    final requestedName = preferredDisplayName?.trim();
    return AuthSession(
      userId: user.uid,
      displayName: displayName == null || displayName.isEmpty
          ? requestedName != null && requestedName.isNotEmpty
                ? requestedName
                : (email.isEmpty ? fallbackDisplayName : email.split('@').first)
          : displayName,
      email: email,
      provider: preferredProvider ?? _providerFromUser(user),
    );
  }

  AuthProviderType _providerFromUser(User user) {
    final providers = user.providerData.map((data) => data.providerId).toSet();
    if (providers.contains('google.com')) return AuthProviderType.google;
    if (providers.contains('apple.com')) return AuthProviderType.apple;
    if (providers.isEmpty && user.emailVerified) {
      return AuthProviderType.emailCode;
    }
    return AuthProviderType.password;
  }

  AuthFailure _failureFromFirebase(FirebaseAuthException error) {
    const cancelledCodes = {
      'canceled',
      'cancelled',
      'user-cancelled',
      'web-context-cancelled',
      'popup-closed-by-user',
    };
    return AuthFailure(
      cancelledCodes.contains(error.code) ? 'cancelled' : error.code,
      error.message,
    );
  }
}
