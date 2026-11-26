/// 法律文档地址（App Store 审核要求）。
///
/// 订阅类 App 需要在购买按钮附近提供可点击的《使用条款》与《隐私政策》链接，
/// 并使用 `launchUrl(uri, mode: LaunchMode.externalApplication)` 在系统浏览器
/// 打开（避免 App 内 WebView 引发审核摩擦）。
///
/// TODO: 上架前替换为 SayPal 自己的正式页面地址。
abstract final class AppLegalUrls {
  /// 使用条款。Apple 为开发者提供标准 EULA；提供内购的 App 可直接引用它。
  static const termsOfUse =
      'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/';

  /// 隐私政策。需托管在 SayPal 自己的 HTTPS 域名下；页面更新时递增版本参数
  /// 以避免 iOS 复用缓存的 Safari 标签页。
  static const privacyPolicy =
      'https://saypal.example.com/privacy.html?v=20260907';

  /// 支持页面（联系邮箱、常见问题、订阅管理）。
  static const supportUrl = 'https://saypal.example.com/support.html';
}
