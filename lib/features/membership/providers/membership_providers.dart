import 'package:app_membership/app_membership.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/demo_membership_service.dart';

/// 会员服务。默认离线演示实现；在 main.dart 中
/// （配置了 `SAYPAL_ACCOUNT_API_BASE_URL` 时）override 为 AppleMembershipService。
final membershipServiceProvider = Provider<MembershipService>(
  (ref) => DemoMembershipService(),
);

/// 会员状态快照流。
final membershipSnapshotProvider = StreamProvider<MembershipSnapshot>(
  (ref) => ref.watch(membershipServiceProvider).states,
);

/// 当前是否拥有会员权益（体验 / 生效 / 宽限期均视为有效）。
final hasPremiumAccessProvider = Provider<bool>(
  (ref) =>
      ref.watch(membershipSnapshotProvider).valueOrNull?.hasPremiumAccess ??
      false,
);
