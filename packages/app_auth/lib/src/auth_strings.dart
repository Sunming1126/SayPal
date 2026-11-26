class AuthStrings {
  const AuthStrings({
    required this.signIn,
    required this.register,
    required this.intro,
    required this.continueWithApple,
    required this.continueWithGoogle,
    required this.orUseEmail,
    required this.displayName,
    required this.email,
    required this.password,
    required this.forgotPassword,
    required this.passwordResetSent,
    required this.invalidEmail,
    required this.weakPassword,
    required this.emailInUse,
    required this.invalidCredential,
    required this.networkError,
    required this.configurationError,
    required this.genericError,
    this.emailCodeSignIn = 'Sign in with email code',
    this.passwordSignIn = 'Sign in with password',
    this.noAccount = "Don't have an account?",
    this.haveAccount = 'Already have an account?',
    this.showPassword = 'Show password',
    this.hidePassword = 'Hide password',
    this.confirmPassword = 'Confirm password',
    this.passwordMismatch = 'The two passwords do not match.',
    this.verifyAndRegister = 'Verify and create account',
    this.registerIntro =
        'Verify your email to create an account and keep sign-in secure.',
    this.sendCode = 'Send verification code',
    this.resendCode = 'Resend code',
    this.resendIn = 'Resend in {seconds}s',
    this.verificationCode = '6-digit verification code',
    this.codeSent = 'A verification code was sent to your email.',
    this.useDifferentEmail = 'Use a different email',
    this.invalidCode = 'Enter the 6-digit verification code.',
    this.expiredCode = 'The verification code has expired. Request a new one.',
    this.tooManyCodeAttempts = 'Too many attempts. Request a new code.',
    this.codeRequestLimited = 'Please wait before requesting another code.',
  });

  const AuthStrings.english()
    : signIn = 'Sign in',
      register = 'Create account',
      intro = 'Sign in securely to access your account on another device.',
      continueWithApple = 'Sign in with Apple',
      continueWithGoogle = 'Continue with Google',
      orUseEmail = 'or use email',
      displayName = 'Display name',
      email = 'Email',
      password = 'Password',
      forgotPassword = 'Forgot password?',
      passwordResetSent = 'Password reset email sent. Check your inbox.',
      invalidEmail = 'Enter a valid email address.',
      weakPassword = 'Password must be at least 6 characters.',
      emailInUse = 'This email is already registered. Sign in instead.',
      invalidCredential = 'The email or password is incorrect.',
      networkError = 'Network connection failed. Try again later.',
      configurationError =
          'Sign-in configuration is incomplete. Contact support.',
      genericError = 'Sign-in failed. Try again later.',
      emailCodeSignIn = 'Sign in with email code',
      passwordSignIn = 'Sign in with password',
      noAccount = "Don't have an account?",
      haveAccount = 'Already have an account?',
      showPassword = 'Show password',
      hidePassword = 'Hide password',
      confirmPassword = 'Confirm password',
      passwordMismatch = 'The two passwords do not match.',
      verifyAndRegister = 'Verify and create account',
      registerIntro =
          'Verify your email to create an account and keep sign-in secure.',
      sendCode = 'Send verification code',
      resendCode = 'Resend code',
      resendIn = 'Resend in {seconds}s',
      verificationCode = '6-digit verification code',
      codeSent = 'A verification code was sent to your email.',
      useDifferentEmail = 'Use a different email',
      invalidCode = 'Enter the correct 6-digit verification code.',
      expiredCode = 'The verification code has expired. Request a new one.',
      tooManyCodeAttempts = 'Too many attempts. Request a new code.',
      codeRequestLimited = 'Please wait before requesting another code.';

  final String signIn;
  final String register;
  final String intro;
  final String continueWithApple;
  final String continueWithGoogle;
  final String orUseEmail;
  final String displayName;
  final String email;
  final String password;
  final String forgotPassword;
  final String passwordResetSent;
  final String invalidEmail;
  final String weakPassword;
  final String emailInUse;
  final String invalidCredential;
  final String networkError;
  final String configurationError;
  final String genericError;
  final String emailCodeSignIn;
  final String passwordSignIn;
  final String noAccount;
  final String haveAccount;
  final String showPassword;
  final String hidePassword;
  final String confirmPassword;
  final String passwordMismatch;
  final String verifyAndRegister;
  final String registerIntro;
  final String sendCode;
  final String resendCode;
  final String resendIn;
  final String verificationCode;
  final String codeSent;
  final String useDifferentEmail;
  final String invalidCode;
  final String expiredCode;
  final String tooManyCodeAttempts;
  final String codeRequestLimited;

  String resendInSeconds(int seconds) =>
      resendIn.replaceAll('{seconds}', '$seconds');
}
