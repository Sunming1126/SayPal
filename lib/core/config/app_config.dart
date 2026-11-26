import 'package:flutter/foundation.dart';

/// 构建配置。调试版默认连接线上语音服务，`--dart-define` 可显式覆盖。
/// 凭证配置不提交到仓库、不打印到日志。
///
/// 用法示例（不提交到仓库的本地命令行）：
/// ```
/// flutter run \
///   --dart-define=SAYPAL_API_BASE_URL=<真实后端地址> \
///   --dart-define=SAYPAL_RTC_APP_ID=<App ID> \
///   --dart-define=SAYPAL_CLIENT_ID=<client id> \
///   --dart-define=SAYPAL_ACCOUNT_API_BASE_URL=<账号/会员服务地址>
/// ```
class AppConfig {
  const AppConfig({
    required this.apiBaseUrl,
    required this.rtcAppId,
    required this.clientId,
    required this.accountApiBaseUrl,
    this.googleSignInEnabled = false,
    this.appleSignInEnabled = false,
  });

  static const String _apiBaseUrl = String.fromEnvironment(
    'SAYPAL_API_BASE_URL',
    defaultValue: kDebugMode ? 'https://onesay.top/saypal/voice' : '',
  );
  static const String chatTransport = String.fromEnvironment(
    'SAYPAL_CHAT_TRANSPORT',
    defaultValue: _apiBaseUrl == '' ? '' : 'rtc',
  );
  static const String chatToken = String.fromEnvironment('SAYPAL_CHAT_TOKEN');
  static const String _rtcAppId = String.fromEnvironment('SAYPAL_RTC_APP_ID');
  static const String _clientId = String.fromEnvironment('SAYPAL_CLIENT_ID');
  static const String _accountApiBaseUrl = String.fromEnvironment(
    'SAYPAL_ACCOUNT_API_BASE_URL',
  );
  static const bool _googleSignInEnabled = bool.fromEnvironment(
    'SAYPAL_GOOGLE_SIGN_IN_ENABLED',
  );
  static const bool _appleSignInEnabled = bool.fromEnvironment(
    'SAYPAL_APPLE_SIGN_IN_ENABLED',
  );

  static AppConfig get instance => const AppConfig(
    apiBaseUrl: _apiBaseUrl,
    rtcAppId: _rtcAppId,
    clientId: _clientId,
    accountApiBaseUrl: _accountApiBaseUrl,
    googleSignInEnabled: _googleSignInEnabled,
    appleSignInEnabled: _appleSignInEnabled,
  );

  final String apiBaseUrl;
  final String rtcAppId;
  final String clientId;

  /// 账号 / 会员服务（Fastify membership-server）的基地址。
  /// 与语音服务（apiBaseUrl）相互独立，可分别部署。
  final String accountApiBaseUrl;

  /// 社交登录必须在 Firebase / Apple Developer 与 iOS 原生配置全部完成后
  /// 再显式开启，避免把尚不可用的按钮展示给用户。
  final bool googleSignInEnabled;
  final bool appleSignInEnabled;

  /// 是否已配置足够的真实实时服务参数。
  /// 只有全部必填项非空时才尝试走真实链路，否则一律使用离线演示实现。
  bool get isRealtimeConfigured =>
      apiBaseUrl.isNotEmpty && rtcAppId.isNotEmpty && clientId.isNotEmpty;

  /// 是否已配置账号 / 会员服务。未配置时登录与会员走离线演示实现。
  bool get isAccountConfigured => accountApiBaseUrl.isNotEmpty;

  /// 是否处于离线演示形态（未配置真实服务）。
  bool get isDemoMode => !isRealtimeConfigured;

  @override
  String toString() => 'AppConfig(demoMode: $isDemoMode)'; // 不输出任何配置值，避免泄露。
}
