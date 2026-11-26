enum MembershipState { guest, trial, active, gracePeriod, expired, unavailable }

enum MembershipPlan { monthly, annual, lifetime }

class MembershipProductIds {
  const MembershipProductIds({
    required this.monthly,
    required this.annual,
    required this.lifetime,
  });

  final String monthly;
  final String annual;
  final String lifetime;

  Set<String> get all => {monthly, annual, lifetime};

  String idFor(MembershipPlan plan) => switch (plan) {
    MembershipPlan.monthly => monthly,
    MembershipPlan.annual => annual,
    MembershipPlan.lifetime => lifetime,
  };

  MembershipPlan? planFor(String productId) => switch (productId) {
    final value when value == monthly => MembershipPlan.monthly,
    final value when value == annual => MembershipPlan.annual,
    final value when value == lifetime => MembershipPlan.lifetime,
    _ => null,
  };
}

class MembershipSnapshot {
  const MembershipSnapshot({
    required this.state,
    required this.verifiedAt,
    this.plan,
    this.expiresAt,
    this.willAutoRenew = false,
  });

  const MembershipSnapshot.guest()
    : state = MembershipState.guest,
      verifiedAt = null,
      plan = null,
      expiresAt = null,
      willAutoRenew = false;

  const MembershipSnapshot.unavailable()
    : state = MembershipState.unavailable,
      verifiedAt = null,
      plan = null,
      expiresAt = null,
      willAutoRenew = false;

  final MembershipState state;
  final MembershipPlan? plan;
  final DateTime? expiresAt;
  final bool willAutoRenew;
  final DateTime? verifiedAt;

  bool get hasPremiumAccess =>
      state == MembershipState.trial ||
      state == MembershipState.active ||
      state == MembershipState.gracePeriod;

  bool isOfflineUsableAt(DateTime now) {
    if (state == MembershipState.expired) return true;
    if (!hasPremiumAccess || verifiedAt == null) {
      return false;
    }
    if (plan != MembershipPlan.lifetime) {
      if (expiresAt == null || !expiresAt!.isAfter(now)) return false;
    }
    final maximumAge = state == MembershipState.trial
        ? const Duration(hours: 24)
        : const Duration(days: 7);
    return verifiedAt!.add(maximumAge).isAfter(now);
  }

  Map<String, Object?> toJson() => {
    'state': state.name,
    'plan': plan?.name,
    'expiresAt': expiresAt?.toUtc().toIso8601String(),
    'willAutoRenew': willAutoRenew,
    'verifiedAt': verifiedAt?.toUtc().toIso8601String(),
  };

  factory MembershipSnapshot.fromJson(Map<String, dynamic> json) {
    final stateName = json['state'] as String?;
    final planName = json['plan'] as String?;
    return MembershipSnapshot(
      state: MembershipState.values.firstWhere(
        (value) => value.name == stateName,
        orElse: () => MembershipState.unavailable,
      ),
      plan: planName == null
          ? null
          : MembershipPlan.values.cast<MembershipPlan?>().firstWhere(
              (value) => value?.name == planName,
              orElse: () => null,
            ),
      expiresAt: _date(json['expiresAt']),
      willAutoRenew: json['willAutoRenew'] == true,
      verifiedAt: _date(json['verifiedAt']),
    );
  }

  static DateTime? _date(Object? value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value)?.toUtc();
  }
}

class MembershipProduct {
  const MembershipProduct({
    required this.plan,
    required this.productId,
    required this.title,
    required this.description,
    required this.displayPrice,
    required this.rawPrice,
    required this.currencyCode,
    this.storeType = MembershipProductStoreType.unknown,
    this.periodUnit,
    this.periodValue,
  });

  final MembershipPlan plan;
  final String productId;
  final String title;
  final String description;
  final String displayPrice;
  final double rawPrice;
  final String currencyCode;
  final MembershipProductStoreType storeType;
  final MembershipPeriodUnit? periodUnit;
  final int? periodValue;
}

enum MembershipProductStoreType {
  autoRenewable,
  nonConsumable,
  nonRenewing,
  consumable,
  unknown,
}

enum MembershipPeriodUnit { day, week, month, year }

enum MembershipPurchaseStage {
  pending,
  purchased,
  restoreStarted,
  restored,
  restoreNotFound,
  verificationDeferred,
  cancelled,
  failed,
}

class MembershipPurchaseEvent {
  const MembershipPurchaseEvent({
    required this.stage,
    this.plan,
    this.code,
    this.message,
  });

  final MembershipPurchaseStage stage;
  final MembershipPlan? plan;
  final String? code;
  final String? message;
}

class MembershipFailure implements Exception {
  const MembershipFailure(this.code, [this.details]);

  final String code;
  final String? details;

  @override
  String toString() => details == null
      ? 'MembershipFailure($code)'
      : 'MembershipFailure($code, $details)';
}
