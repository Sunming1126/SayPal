import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/providers/auth_providers.dart';

/// 会员购买入口（premiumGate）：未登录先弹登录页，登录成功后进入会员详情。
/// 后续所有需要会员的付费功能都从这个入口进入。
Future<void> openPremiumGate(BuildContext context, WidgetRef ref) async {
  if (ref.read(authSessionProvider).valueOrNull == null) {
    await context.push('/auth');
    if (!ref.read(signedInProvider)) return;
  }
  if (context.mounted) await context.push('/profile/membership');
}
