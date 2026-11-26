import 'dart:async';

import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'auth_models.dart';
import 'auth_service.dart';
import 'auth_strings.dart';

class AuthPanelAppearance {
  const AuthPanelAppearance({
    required this.primaryColor,
    required this.textColor,
    required this.mutedTextColor,
    required this.borderColor,
    this.socialButtonBackground = Colors.white,
    this.cornerRadius = 16,
  });

  factory AuthPanelAppearance.fromTheme(ThemeData theme) {
    final colors = theme.colorScheme;
    return AuthPanelAppearance(
      primaryColor: colors.primary,
      textColor: colors.onSurface,
      mutedTextColor: colors.onSurfaceVariant,
      borderColor: colors.outlineVariant,
      socialButtonBackground: colors.surface,
    );
  }

  final Color primaryColor;
  final Color textColor;
  final Color mutedTextColor;
  final Color borderColor;
  final Color socialButtonBackground;
  final double cornerRadius;
}

class AuthPanel extends StatefulWidget {
  const AuthPanel({
    super.key,
    required this.authService,
    required this.onAuthenticated,
    this.strings = const AuthStrings.english(),
    this.appearance,
    this.onMessage,
    this.registrationExtraBuilder,
    this.onBeforeRegistration,
    this.enabledProviders = const {
      AuthProviderType.emailCode,
      AuthProviderType.google,
      AuthProviderType.apple,
    },
  });

  final AuthService authService;
  final FutureOr<void> Function(AuthSession session) onAuthenticated;
  final AuthStrings strings;
  final AuthPanelAppearance? appearance;
  final void Function(String message)? onMessage;

  /// Optional app-owned content shown only while the panel is in registration
  /// mode. The shared package deliberately does not interpret its contents.
  final Widget Function(BuildContext context, bool busy)?
  registrationExtraBuilder;

  /// Lets a host validate or persist app-specific registration input before an
  /// email, Apple, or Google registration attempt. Returning false cancels the
  /// authentication attempt without changing the panel state.
  final Future<bool> Function()? onBeforeRegistration;
  final Set<AuthProviderType> enabledProviders;

  @override
  State<AuthPanel> createState() => _AuthPanelState();
}

class _AuthPanelState extends State<AuthPanel> {
  bool _register = false;
  bool _busy = false;
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;
  late _EmailMode _emailMode;
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _name = TextEditingController();
  final _code = TextEditingController();
  EmailCodeChallenge? _emailChallenge;
  Timer? _resendTimer;
  int _resendSeconds = 0;

  @override
  void initState() {
    super.initState();
    _emailMode = widget.enabledProviders.contains(AuthProviderType.password)
        ? _EmailMode.password
        : _EmailMode.code;
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    _name.dispose();
    _code.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = widget.strings;
    final appearance =
        widget.appearance ?? AuthPanelAppearance.fromTheme(Theme.of(context));
    final emailCodeEnabled = widget.enabledProviders.contains(
      AuthProviderType.emailCode,
    );
    final passwordEnabled = widget.enabledProviders.contains(
      AuthProviderType.password,
    );
    final showEmail = emailCodeEnabled || passwordEnabled;
    final useEmailCode = _emailMode == _EmailMode.code;
    final registrationUsesCode = _register && emailCodeEnabled;
    final showSocial =
        widget.enabledProviders.contains(AuthProviderType.apple) ||
        widget.enabledProviders.contains(AuthProviderType.google);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .88,
      ),
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _register ? strings.register : strings.signIn,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 6),
            Text(
              _register ? strings.registerIntro : strings.intro,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: appearance.mutedTextColor,
              ),
            ),
            const SizedBox(height: 20),
            if (_register && widget.registrationExtraBuilder != null) ...[
              widget.registrationExtraBuilder!(context, _busy),
              const SizedBox(height: 10),
            ],
            if (widget.enabledProviders.contains(AuthProviderType.apple)) ...[
              _AppleButton(
                label: strings.continueWithApple,
                busy: _busy,
                cornerRadius: appearance.cornerRadius,
                onPressed: () => _runAuth(
                  widget.authService.signInWithApple,
                  registrationAttempt: _register,
                ),
              ),
              const SizedBox(height: 10),
            ],
            if (widget.enabledProviders.contains(AuthProviderType.google))
              _GoogleButton(
                label: strings.continueWithGoogle,
                busy: _busy,
                appearance: appearance,
                onPressed: () => _runAuth(
                  widget.authService.signInWithGoogle,
                  registrationAttempt: _register,
                ),
              ),
            if (showEmail && showSocial)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        strings.orUseEmail,
                        style: TextStyle(
                          color: appearance.mutedTextColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
              )
            else if (showEmail)
              const SizedBox(height: 18),
            if (showEmail) ...[
              if (_register) ...[
                TextField(
                  controller: _name,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.name],
                  decoration: InputDecoration(labelText: strings.displayName),
                ),
                const SizedBox(height: 10),
              ],
              TextField(
                controller: _email,
                enabled: !_busy && _emailChallenge == null,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                autofillHints: const [AutofillHints.email],
                decoration: InputDecoration(labelText: strings.email),
              ),
              const SizedBox(height: 10),
              if (useEmailCode)
                _buildEmailCodeFields(
                  strings,
                  appearance,
                  onSubmitted: _submitEmailCode,
                )
              else ...[
                TextField(
                  controller: _password,
                  obscureText: _obscurePassword,
                  textInputAction: _register
                      ? TextInputAction.next
                      : TextInputAction.done,
                  autofillHints: [
                    _register
                        ? AutofillHints.newPassword
                        : AutofillHints.password,
                  ],
                  onSubmitted: _busy || _register ? null : (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: strings.password,
                    suffixIcon: IconButton(
                      onPressed: _busy
                          ? null
                          : () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                      tooltip: _obscurePassword
                          ? strings.showPassword
                          : strings.hidePassword,
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                ),
                if (_register) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: _confirmPassword,
                    obscureText: _obscureConfirmation,
                    autofillHints: const [AutofillHints.newPassword],
                    onSubmitted: _busy
                        ? null
                        : (_) => registrationUsesCode
                              ? (_emailChallenge == null
                                    ? _requestRegistrationCode()
                                    : _submitVerifiedRegistration())
                              : _submit(),
                    decoration: InputDecoration(
                      labelText: strings.confirmPassword,
                      suffixIcon: IconButton(
                        onPressed: _busy
                            ? null
                            : () => setState(
                                () => _obscureConfirmation =
                                    !_obscureConfirmation,
                              ),
                        tooltip: _obscureConfirmation
                            ? strings.showPassword
                            : strings.hidePassword,
                        icon: Icon(
                          _obscureConfirmation
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                  ),
                  if (_emailChallenge != null) ...[
                    const SizedBox(height: 10),
                    _buildEmailCodeFields(
                      strings,
                      appearance,
                      onSubmitted: _submitVerifiedRegistration,
                    ),
                  ],
                ],
              ],
              const SizedBox(height: 12),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _busy
                      ? null
                      : _register
                      ? (registrationUsesCode
                            ? (_emailChallenge == null
                                  ? _requestRegistrationCode
                                  : _submitVerifiedRegistration)
                            : _submit)
                      : useEmailCode
                      ? (_emailChallenge == null
                            ? _requestCode
                            : _submitEmailCode)
                      : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: appearance.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        appearance.cornerRadius,
                      ),
                    ),
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _register && registrationUsesCode
                              ? (_emailChallenge == null
                                    ? strings.sendCode
                                    : strings.verifyAndRegister)
                              : useEmailCode && _emailChallenge == null
                              ? strings.sendCode
                              : (_register ? strings.register : strings.signIn),
                        ),
                ),
              ),
              if (!_register) ...[
                const SizedBox(height: 2),
                _buildAccountUtilities(
                  strings,
                  passwordEnabled: passwordEnabled,
                  emailCodeEnabled: emailCodeEnabled,
                ),
              ],
              if (passwordEnabled) ...[
                const SizedBox(height: 4),
                const Divider(),
                const SizedBox(height: 4),
                _buildRegistrationPrompt(strings),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAccountUtilities(
    AuthStrings strings, {
    required bool passwordEnabled,
    required bool emailCodeEnabled,
  }) {
    final leftAction = _emailMode == _EmailMode.password
        ? (emailCodeEnabled
              ? _UtilityAction(
                  label: strings.emailCodeSignIn,
                  onPressed: () => _switchEmailMode(_EmailMode.code),
                )
              : null)
        : (passwordEnabled
              ? _UtilityAction(
                  label: strings.passwordSignIn,
                  onPressed: () => _switchEmailMode(_EmailMode.password),
                )
              : null);

    return Row(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: leftAction == null
                ? const SizedBox(height: 44)
                : _UtilityTextButton(
                    label: leftAction.label,
                    onPressed: _busy ? null : leftAction.onPressed,
                    alignment: Alignment.centerLeft,
                  ),
          ),
        ),
        if (_emailMode == _EmailMode.password && passwordEnabled)
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: _UtilityTextButton(
                label: strings.forgotPassword,
                onPressed: _busy ? null : _resetPassword,
                alignment: Alignment.centerRight,
              ),
            ),
          )
        else
          const Spacer(),
      ],
    );
  }

  Widget _buildRegistrationPrompt(AuthStrings strings) => Wrap(
    alignment: WrapAlignment.center,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      Text(
        _register ? strings.haveAccount : strings.noAccount,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: widget.appearance?.mutedTextColor,
        ),
      ),
      _UtilityTextButton(
        label: _register ? strings.signIn : strings.register,
        onPressed: _busy ? null : _toggleRegistration,
        alignment: Alignment.center,
      ),
    ],
  );

  void _switchEmailMode(_EmailMode mode) {
    _resendTimer?.cancel();
    setState(() {
      _emailMode = mode;
      _register = false;
      _emailChallenge = null;
      _resendSeconds = 0;
      _code.clear();
    });
  }

  void _toggleRegistration() {
    _resendTimer?.cancel();
    setState(() {
      _register = !_register;
      _emailMode = _EmailMode.password;
      _emailChallenge = null;
      _resendSeconds = 0;
      _code.clear();
      _password.clear();
      _confirmPassword.clear();
    });
  }

  Widget _buildEmailCodeFields(
    AuthStrings strings,
    AuthPanelAppearance appearance, {
    required Future<void> Function() onSubmitted,
  }) {
    if (_emailChallenge == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _code,
          autofocus: true,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.oneTimeCode],
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          onSubmitted: _busy ? null : (_) => onSubmitted(),
          decoration: InputDecoration(labelText: strings.verificationCode),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Text(
                strings.codeSent,
                style: TextStyle(
                  color: appearance.mutedTextColor,
                  fontSize: 12,
                ),
              ),
            ),
            TextButton(
              onPressed: _busy || _resendSeconds > 0 ? null : _requestCode,
              child: Text(
                _resendSeconds > 0
                    ? strings.resendInSeconds(_resendSeconds)
                    : strings.resendCode,
              ),
            ),
          ],
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: _busy ? null : _resetEmailCode,
            child: Text(strings.useDifferentEmail),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Future<void> _submit() => _runAuth(() {
    if (_register) {
      return widget.authService.register(
        email: _email.text,
        displayName: _name.text,
        password: _password.text,
      );
    }
    return widget.authService.login(
      email: _email.text,
      password: _password.text,
    );
  }, registrationAttempt: _register);

  Future<void> _requestRegistrationCode() async {
    if (!_registrationPasswordsAreValid()) return;
    if (!await _registrationPreflight()) return;
    await _requestCode();
  }

  Future<void> _submitVerifiedRegistration() {
    if (!_registrationPasswordsAreValid()) return Future.value();
    final challenge = _emailChallenge;
    if (challenge == null) return _requestRegistrationCode();
    return _runAuth(
      () => widget.authService.registerWithEmailCode(
        email: _email.text,
        displayName: _name.text,
        password: _password.text,
        challengeId: challenge.challengeId,
        code: _code.text,
      ),
      registrationAttempt: true,
    );
  }

  bool _registrationPasswordsAreValid() {
    if (_password.text.length < 6) {
      _showMessage(widget.strings.weakPassword);
      return false;
    }
    if (_password.text != _confirmPassword.text) {
      _showMessage(widget.strings.passwordMismatch);
      return false;
    }
    return true;
  }

  Future<void> _requestCode() async {
    setState(() => _busy = true);
    try {
      final challenge = await widget.authService.requestEmailCode(_email.text);
      if (!mounted) return;
      setState(() {
        _emailChallenge = challenge;
        _code.clear();
        _resendSeconds = challenge.resendAfterSeconds;
      });
      _startResendTimer();
    } on AuthFailure catch (error) {
      _showMessage(_messageFor(error));
    } catch (_) {
      _showMessage(widget.strings.genericError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitEmailCode() {
    final challenge = _emailChallenge;
    if (challenge == null) return _requestCode();
    return _runAuth(
      () => widget.authService.signInWithEmailCode(
        email: _email.text,
        challengeId: challenge.challengeId,
        code: _code.text,
      ),
    );
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _resendSeconds <= 1) {
        timer.cancel();
        if (mounted) setState(() => _resendSeconds = 0);
        return;
      }
      setState(() => _resendSeconds -= 1);
    });
  }

  void _resetEmailCode() {
    _resendTimer?.cancel();
    setState(() {
      _emailChallenge = null;
      _resendSeconds = 0;
      _code.clear();
    });
  }

  Future<void> _runAuth(
    Future<AuthSession> Function() action, {
    bool registrationAttempt = false,
  }) async {
    setState(() => _busy = true);
    try {
      if (registrationAttempt && !await _registrationPreflight()) return;
      final session = await action();
      await widget.onAuthenticated(session);
    } on AuthFailure catch (error) {
      if (error.code != 'cancelled') _showMessage(_messageFor(error));
    } catch (_) {
      _showMessage(widget.strings.genericError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _registrationPreflight() async =>
      await widget.onBeforeRegistration?.call() ?? true;

  Future<void> _resetPassword() async {
    setState(() => _busy = true);
    try {
      await widget.authService.sendPasswordResetEmail(_email.text);
      _showMessage(widget.strings.passwordResetSent);
    } on AuthFailure catch (error) {
      _showMessage(_messageFor(error));
    } catch (_) {
      _showMessage(widget.strings.genericError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    final callback = widget.onMessage;
    if (callback != null) {
      callback(message);
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _messageFor(AuthFailure failure) {
    final strings = widget.strings;
    return switch (failure.code) {
      'invalid-email' => strings.invalidEmail,
      'weak-password' => strings.weakPassword,
      'email-already-in-use' ||
      'account-exists-with-different-credential' => strings.emailInUse,
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' => strings.invalidCredential,
      'network-request-failed' => strings.networkError,
      'email-code-invalid' || 'email_code_invalid' => strings.invalidCode,
      'email_code_expired' => strings.expiredCode,
      'email_code_attempts_exceeded' => strings.tooManyCodeAttempts,
      'email_code_too_frequent' ||
      'email_code_daily_limit' ||
      'email_code_ip_limit' => strings.codeRequestLimited,
      'email-code-not-configured' ||
      'email-code-token-missing' ||
      'email_delivery_failed' => strings.configurationError,
      'operation-not-allowed' ||
      'google-clientConfigurationError' ||
      'google-providerConfigurationError' ||
      'google-token-missing' => strings.configurationError,
      _ => strings.genericError,
    };
  }
}

class _AppleButton extends StatelessWidget {
  const _AppleButton({
    required this.label,
    required this.busy,
    required this.cornerRadius,
    required this.onPressed,
  });

  final String label;
  final bool busy;
  final double cornerRadius;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 52,
    child: FilledButton.icon(
      onPressed: busy ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.black.withValues(alpha: .45),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cornerRadius),
        ),
      ),
      icon: const FaIcon(FontAwesomeIcons.apple, size: 23),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    ),
  );
}

class _GoogleButton extends StatelessWidget {
  const _GoogleButton({
    required this.label,
    required this.busy,
    required this.appearance,
    required this.onPressed,
  });

  final String label;
  final bool busy;
  final AuthPanelAppearance appearance;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 52,
    child: OutlinedButton.icon(
      onPressed: busy ? null : onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: appearance.socialButtonBackground,
        foregroundColor: appearance.textColor,
        side: BorderSide(color: appearance.borderColor),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(appearance.cornerRadius),
        ),
      ),
      icon: const FaIcon(
        FontAwesomeIcons.google,
        size: 20,
        color: Color(0xFF4285F4),
      ),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    ),
  );
}

enum _EmailMode { password, code }

class _UtilityAction {
  const _UtilityAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;
}

class _UtilityTextButton extends StatelessWidget {
  const _UtilityTextButton({
    required this.label,
    required this.onPressed,
    required this.alignment,
  });

  final String label;
  final VoidCallback? onPressed;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      alignment: alignment,
      minimumSize: const Size(0, 44),
      padding: EdgeInsets.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
    child: Text(label),
  );
}
