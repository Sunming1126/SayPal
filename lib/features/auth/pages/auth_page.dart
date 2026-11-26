import 'package:app_auth/app_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../auth_strings_zh.dart';
import '../providers/auth_providers.dart';

/// 登录 / 注册页：包裹 app_auth 包中的应用无关面板 AuthPanel。
/// 未登录也能使用 App；本页仅从「我的」页或购买会员前进入，永不强制。
class AuthPage extends ConsumerWidget {
  const AuthPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppConfig config = AppConfig.instance;
    final Set<AuthProviderType> enabledProviders = <AuthProviderType>{
      AuthProviderType.password,
      AuthProviderType.emailCode,
      if (config.googleSignInEnabled) AuthProviderType.google,
      if (config.appleSignInEnabled) AuthProviderType.apple,
    };

    return Scaffold(
      appBar: AppBar(title: const Text('登录')),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) =>
              SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              24,
              18,
              24,
              24 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: AuthPanel(
                  authService: ref.read(authServiceProvider),
                  strings: authStringsZh,
                  appearance: AuthPanelAppearance(
                    primaryColor: AppColors.primary,
                    textColor: AppColors.textPrimary,
                    mutedTextColor: AppColors.textSecondary,
                    borderColor: AppColors.outline,
                    socialButtonBackground: Colors.white.withValues(alpha: .82),
                  ),
                  enabledProviders: enabledProviders,
                  onAuthenticated: (AuthSession session) async {
                    if (context.mounted) Navigator.pop(context);
                  },
                  onMessage: (String message) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(SnackBar(content: Text(message)));
                    }
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
