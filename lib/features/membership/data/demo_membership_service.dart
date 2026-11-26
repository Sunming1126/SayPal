import 'dart:async';

import 'package:app_membership/app_membership.dart';

/// 离线演示会员服务：未配置账号服务时使用。
/// 不连接 App Store，也不发起网络请求，权益状态恒为 unavailable。
class DemoMembershipService implements MembershipService {
  static const MembershipSnapshot _snapshot = MembershipSnapshot.unavailable();

  @override
  MembershipSnapshot get current => _snapshot;

  @override
  Stream<MembershipSnapshot> get states =>
      Stream<MembershipSnapshot>.value(_snapshot);

  @override
  Stream<MembershipPurchaseEvent> get purchaseEvents =>
      const Stream<MembershipPurchaseEvent>.empty();

  @override
  Future<void> initialize() async {}

  @override
  Future<MembershipSnapshot> refresh() async => _snapshot;

  @override
  Future<List<MembershipProduct>> loadProducts() async => const <MembershipProduct>[];

  @override
  Future<void> purchase(MembershipPlan plan) async {
    throw const MembershipFailure('store_unavailable');
  }

  @override
  Future<void> restorePurchases() async {
    throw const MembershipFailure('store_unavailable');
  }

  @override
  Future<void> signedOut() async {}

  @override
  Future<void> dispose() async {}
}
