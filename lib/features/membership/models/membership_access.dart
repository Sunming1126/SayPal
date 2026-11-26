import 'package:app_membership/app_membership.dart';

/// SayPal 的内购商品 ID。必须与 App Store Connect 中配置的商品
/// 以及 membership-server 的 `APPLE_PRODUCT_*` 环境变量保持一致。
const saypalMembershipProductIds = MembershipProductIds(
  monthly: 'com.caoyuming.saypalapp.premium_monthly',
  annual: 'com.caoyuming.saypalapp.premium_yearly',
  lifetime: 'com.caoyuming.saypalapp.premium_lifetime',
);
