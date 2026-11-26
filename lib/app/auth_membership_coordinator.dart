import 'dart:async';

import 'package:app_auth/app_auth.dart';
import 'package:app_membership/app_membership.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/providers/auth_providers.dart';
import '../features/membership/providers/membership_providers.dart';

/// 登录态 → 会员生命周期的协调器（App 级唯一的跨 feature 接线点）。
///
/// 职责（对应 Lighter AppController.setAuthSession 的会员部分）：
/// - 启动时初始化会员服务（恢复未完成的购买）；
/// - 新登录 → 刷新会员快照；换账号登录 → 先清掉上一账号的设备缓存；
/// - 登出 → 清空会员状态；
/// - Provider 销毁时释放会员服务。
///
/// 在 SayPalApp.build 中 `ref.watch` 激活。
final authMembershipCoordinatorProvider = Provider<void>((ref) {
  final MembershipService membership = ref.watch(membershipServiceProvider);
  unawaited(membership.initialize());

  ref.listen<AsyncValue<AuthSession?>>(authSessionProvider, (
    AsyncValue<AuthSession?>? previous,
    AsyncValue<AuthSession?> next,
  ) {
    final String? previousUserId = previous?.valueOrNull?.userId;
    final AuthSession? session = next.valueOrNull;
    final String? nextUserId = session?.userId;
    if (previousUserId == nextUserId) return;

    if (nextUserId == null) {
      unawaited(membership.signedOut());
      return;
    }
    unawaited(() async {
      if (previousUserId != null) {
        // 换了账号：设备上缓存的是上一个账号的权益，必须先清掉。
        await membership.signedOut();
      }
      await membership.refresh();
    }());
  });

  ref.onDispose(() => unawaited(membership.dispose()));
});
