import 'package:app_membership/app_membership.dart';
import 'package:flutter/material.dart';

/// 「我的」页中的会员状态摘要卡，点击进入会员详情页。
class MembershipSummaryCard extends StatelessWidget {
  const MembershipSummaryCard({
    required this.snapshot,
    required this.signedIn,
    required this.onTap,
    super.key,
  });

  final MembershipSnapshot snapshot;
  final bool signedIn;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (String title, String subtitle) = _summary(snapshot, signedIn);
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF17213F), Color(0xFF3B3E78)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF50568F)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.workspace_premium_outlined,
                  color: Colors.white,
                  size: 23,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: .74),
                          ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }

  (String, String) _summary(MembershipSnapshot value, bool isSignedIn) {
    if (!isSignedIn || value.state == MembershipState.guest) {
      return ('SayPal 会员', '登录后即享 3 天完整体验');
    }
    return switch (value.state) {
      MembershipState.trial => ('会员体验中', _remaining(value.expiresAt)),
      MembershipState.active ||
      MembershipState.gracePeriod => (
        'SayPal 会员 · ${_planLabel(value.plan)}',
        value.plan == MembershipPlan.lifetime
            ? '永久解锁 · 无需续费'
            : value.state == MembershipState.gracePeriod
                ? '账单宽限期内，权益仍然有效'
                : value.willAutoRenew
                    ? '订阅有效 · 自动续费'
                    : '订阅有效至当前周期结束',
      ),
      MembershipState.expired => ('体验已结束', '升级后恢复全部内容与功能'),
      MembershipState.unavailable => ('会员详情', '查看权益与购买方案'),
      MembershipState.guest => throw StateError('handled above'),
    };
  }
}

String _planLabel(MembershipPlan? plan) => switch (plan) {
      MembershipPlan.monthly => '月度会员',
      MembershipPlan.annual => '年度会员',
      MembershipPlan.lifetime => '终身会员',
      null => '会员',
    };

String _remaining(DateTime? expiresAt) {
  if (expiresAt == null) return '正在同步到期时间';
  final Duration remaining = expiresAt.difference(DateTime.now().toUtc());
  if (remaining <= Duration.zero) return '体验已结束';
  if (remaining.inHours < 24) {
    final int hours = (remaining.inMinutes / Duration.minutesPerHour).ceil();
    return '剩余 $hours 小时';
  }
  final int days = (remaining.inMinutes / Duration.minutesPerDay).ceil();
  return '剩余 $days 天';
}
