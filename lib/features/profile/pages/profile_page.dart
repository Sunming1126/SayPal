import 'package:app_auth/app_auth.dart';
import 'package:app_membership/app_membership.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/adventure_widgets.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../auth/providers/auth_providers.dart';
import '../../membership/membership_gate.dart';
import '../../membership/providers/membership_providers.dart';
import '../../membership/widgets/membership_summary_card.dart';
import '../models/child_profile.dart';
import '../models/profile_overview.dart';
import '../providers/profile_providers.dart';

/// 我的：儿童学习信息在前，账号、会员与注销统一收进家长专区。
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  bool _parentExpanded = false;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<ChildProfile> profile = ref.watch(childProfileProvider);
    final AsyncValue<ProfileOverview> overview =
        ref.watch(profileOverviewProvider);
    final bool signedIn = ref.watch(signedInProvider);
    final AuthSession? session = ref.watch(authSessionProvider).valueOrNull;
    final MembershipSnapshot membership =
        ref.watch(membershipSnapshotProvider).valueOrNull ??
            const MembershipSnapshot.guest();

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFF),
      body: SafeArea(
        bottom: false,
        child: profile.when(
          loading: () => const LoadingView(),
          error: (Object error, StackTrace stack) => ErrorStateView(
            title: '暂时无法打开个人资料',
            message: '请稍后再试一次。',
            onRetry: () => ref.invalidate(childProfileProvider),
          ),
          data: (ChildProfile data) => ListView(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 118),
            children: <Widget>[
              _ProfileHeader(
                profile: data,
                onEdit: () => _editProfile(context, ref, data),
              ),
              const SizedBox(height: 20),
              MembershipSummaryCard(
                snapshot: membership,
                signedIn: signedIn,
                onTap: () => openPremiumGate(context, ref),
              ),
              const SizedBox(height: 16),
              _ProfileDataStrip(overview: overview),
              const SizedBox(height: 16),
              _ProfileMenu(
                onVocabulary: () => context.push('/vocabulary'),
                onHistory: () => context.push('/profile/statistics'),
                onMembership: () => openPremiumGate(context, ref),
              ),
              const SizedBox(height: 16),
              _ParentZone(
                expanded: _parentExpanded,
                onExpansionChanged: (bool expanded) =>
                    setState(() => _parentExpanded = expanded),
                signedIn: signedIn,
                session: session,
                onLogin: () => context.push('/auth'),
                onLogout: () => _confirmLogout(context, ref),
                onDelete: () => _confirmDeleteAccount(context, ref),
              ),
              const SizedBox(height: 14),
              const _LocalDataNote(),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editProfile(
    BuildContext context,
    WidgetRef ref,
    ChildProfile current,
  ) async {
    final ChildProfile? updated = await showDialog<ChildProfile>(
      context: context,
      builder: (BuildContext dialogContext) =>
          _ProfileEditDialog(current: current),
    );
    if (updated != null) {
      await ref.read(childProfileProvider.notifier).updateProfile(updated);
    }
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出当前账号吗？本机学习数据会保留在这台手机上。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('退出登录'),
          ),
        ],
      ),
    );
    if (confirmed == true) await ref.read(authServiceProvider).logout();
  }

  Future<void> _confirmDeleteAccount(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('注销账号'),
        content: const Text(
          '注销后会删除服务器上的账号信息与会员权益，且无法恢复。\n\n'
          '本机上的学习数据仍会保留在这台手机上。\n\n确定要继续吗？',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('确认注销'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authServiceProvider).deleteAccount();
    }
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profile, required this.onEdit});

  final ChildProfile profile;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final String initial = profile.name.trim().isEmpty
        ? 'S'
        : profile.name.trim().characters.first.toUpperCase();
    return Row(
      children: <Widget>[
        Container(
          width: 62,
          height: 62,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[Color(0xFFDCE8FF), Color(0xFFE9E3FF)],
            ),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: AppColors.softShadow,
          ),
          child: Text(
            initial,
            style: const TextStyle(
              color: AppColors.primaryDark,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                profile.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'SayPal 学习者',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        Semantics(
          button: true,
          label: '编辑个人资料',
          child: GlassIconButton(
            key: const ValueKey<String>('profile-settings-button'),
            size: 46,
            iconSize: 23,
            useOwnLayer: true,
            onPressed: onEdit,
            icon: const Icon(Icons.settings_outlined),
          ),
        ),
      ],
    );
  }
}

class _ProfileDataStrip extends StatelessWidget {
  const _ProfileDataStrip({required this.overview});

  final AsyncValue<ProfileOverview> overview;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 17),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.outline),
          boxShadow: AppColors.softShadow,
        ),
        child: overview.when(
          loading: () => const SizedBox(
            height: 48,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (_, __) => const SizedBox(
            height: 48,
            child: Center(child: Text('数据暂时无法读取')),
          ),
          data: (ProfileOverview data) => Row(
            children: <Widget>[
              _DataMetric(value: data.conversationCount, label: '对话'),
              _DataMetric(value: data.roleplayCount, label: '情景练习'),
              _DataMetric(value: data.favoriteCount, label: '收藏'),
              _DataMetric(value: data.vocabularyCount, label: '生词'),
            ],
          ),
        ),
      );
}

class _DataMetric extends StatelessWidget {
  const _DataMetric({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: <Widget>[
            Text(
              '$value',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      );
}

class _ProfileMenu extends StatelessWidget {
  const _ProfileMenu({
    required this.onVocabulary,
    required this.onHistory,
    required this.onMembership,
  });

  final VoidCallback onVocabulary;
  final VoidCallback onHistory;
  final VoidCallback onMembership;

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.outline),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: <Widget>[
            _MenuTile(
              icon: Icons.book_outlined,
              title: '生词本',
              subtitle: '查看保存的单词与例句',
              onTap: onVocabulary,
            ),
            const Divider(height: 1, indent: 58),
            _MenuTile(
              icon: Icons.history_rounded,
              title: '练习历史',
              subtitle: '查看本机学习记录',
              onTap: onHistory,
            ),
            const Divider(height: 1, indent: 58),
            _MenuTile(
              icon: Icons.workspace_premium_outlined,
              title: '会员管理',
              subtitle: '查看权益与订阅状态',
              onTap: onMembership,
            ),
          ],
        ),
      );
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        onTap: onTap,
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 21, color: AppColors.primaryDark),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
      );
}

// ignore: unused_element
class _PassportCard extends StatelessWidget {
  const _PassportCard({required this.profile, required this.onEdit});

  final ChildProfile profile;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: AppColors.warmOutline),
          boxShadow: AppColors.softShadow,
        ),
        child: Row(
          children: <Widget>[
            AnimalAvatar(avatarId: profile.avatarId, size: 76),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'SAYPAL LEARNER',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 11,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    profile.name,
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${profile.gradeLabel} · 勇敢开口中',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            IconButton.filledTonal(
              tooltip: '编辑资料',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_rounded),
            ),
          ],
        ),
      );
}

// ignore: unused_element
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              subtitle,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
        ],
      );
}

// ignore: unused_element
class _GrowthCard extends StatelessWidget {
  const _GrowthCard({
    required this.overview,
    required this.onRetry,
    required this.onTap,
  });

  final AsyncValue<ProfileOverview> overview;
  final VoidCallback onRetry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => overview.when(
        loading: () => Container(
          height: 118,
          alignment: Alignment.center,
          decoration: _cardDecoration(AppColors.primarySoft),
          child: const CircularProgressIndicator(strokeWidth: 3),
        ),
        error: (_, __) => Container(
          padding: const EdgeInsets.all(16),
          decoration: _cardDecoration(AppColors.coralSoft),
          child: Row(
            children: <Widget>[
              const Expanded(child: Text('成长记录暂时没有打开')),
              TextButton(onPressed: onRetry, child: const Text('再试一次')),
            ],
          ),
        ),
        data: (ProfileOverview data) {
          final bool empty = data.totalMinutes == 0 && data.speakingCount == 0;
          return PressScaleCard(
            onTap: onTap,
            borderRadius: 24,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: _cardDecoration(AppColors.primarySoft),
              child: empty
                  ? const Row(
                      children: <Widget>[
                        Icon(
                          Icons.route_rounded,
                          size: 36,
                          color: AppColors.primary,
                        ),
                        SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                '还没有练习记录',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '去聊一聊或角色扮演，第一步就会出现在这里',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: <Widget>[
                        Expanded(
                          child: _Metric(
                            icon: Icons.schedule_rounded,
                            value: '${data.totalMinutes}',
                            unit: '分钟',
                            label: '学习时长',
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 58,
                          color: AppColors.primary.withValues(alpha: .18),
                        ),
                        Expanded(
                          child: _Metric(
                            icon: Icons.record_voice_over_rounded,
                            value: '${data.speakingCount}',
                            unit: '次',
                            label: '开口练习',
                          ),
                        ),
                      ],
                    ),
            ),
          );
        },
      );
}

BoxDecoration _cardDecoration(Color color) => BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: AppColors.warmOutline),
    );

class _Metric extends StatelessWidget {
  const _Metric({
    required this.icon,
    required this.value,
    required this.unit,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String unit;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
        children: <Widget>[
          Icon(icon, color: AppColors.primary),
          const SizedBox(height: 6),
          RichText(
            text: TextSpan(
              style: const TextStyle(color: AppColors.textPrimary),
              children: <InlineSpan>[
                TextSpan(
                  text: value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                TextSpan(text: ' $unit'),
              ],
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      );
}

// ignore: unused_element
class _TreasureGrid extends StatelessWidget {
  const _TreasureGrid({
    required this.overview,
    required this.onVocabulary,
    required this.onStatistics,
  });

  final ProfileOverview? overview;
  final VoidCallback onVocabulary;
  final VoidCallback onStatistics;

  @override
  Widget build(BuildContext context) => Row(
        children: <Widget>[
          Expanded(
            child: _TreasureCard(
              title: '我的生词本',
              detail: overview == null
                  ? '看看收藏'
                  : overview!.vocabularyCount == 0
                      ? '还没有收藏'
                      : '收藏了 ${overview!.vocabularyCount} 个词',
              icon: Icons.menu_book_rounded,
              color: AppColors.sunSoft,
              iconColor: AppColors.warning,
              onTap: onVocabulary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _TreasureCard(
              title: '学习统计',
              detail: '查看七日旅程',
              icon: Icons.insights_rounded,
              color: AppColors.mint,
              iconColor: AppColors.mintStrong,
              onTap: onStatistics,
            ),
          ),
        ],
      );
}

class _TreasureCard extends StatelessWidget {
  const _TreasureCard({
    required this.title,
    required this.detail,
    required this.icon,
    required this.color,
    required this.iconColor,
    required this.onTap,
  });

  final String title;
  final String detail;
  final IconData icon;
  final Color color;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final double textScale = MediaQuery.textScalerOf(context).scale(1);
    final double height = 148 + ((textScale - 1) * 60).clamp(0, 42);
    return PressScaleCard(
      onTap: onTap,
      borderRadius: 22,
      child: Container(
        height: height,
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration(color),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .75),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: iconColor),
            ),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              detail,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ParentZone extends StatelessWidget {
  const _ParentZone({
    required this.expanded,
    required this.onExpansionChanged,
    required this.signedIn,
    required this.session,
    required this.onLogin,
    required this.onLogout,
    required this.onDelete,
  });

  final bool expanded;
  final ValueChanged<bool> onExpansionChanged;
  final bool signedIn;
  final AuthSession? session;
  final VoidCallback onLogin;
  final VoidCallback onLogout;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Material(
        color: const Color(0xFFF1F2F5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: AppColors.outline),
        ),
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          key: const ValueKey<String>('parent-zone'),
          initiallyExpanded: false,
          onExpansionChanged: onExpansionChanged,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          leading: const Icon(Icons.manage_accounts_outlined),
          title: const Text(
            '账号设置',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          subtitle: Text(expanded ? '管理登录与账号安全' : '登录、退出与账号安全'),
          children: <Widget>[
            if (!signedIn)
              ListTile(
                onTap: onLogin,
                leading: const Icon(Icons.login_rounded),
                title: const Text('登录 / 注册'),
                subtitle: const Text('登录后可购买会员并同步权益'),
                trailing: const Icon(Icons.chevron_right_rounded),
              )
            else
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primarySoft,
                  child: Text(
                    session?.displayName.isNotEmpty == true
                        ? session!.displayName.characters.first
                        : 'S',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                title: Text(session?.displayName ?? ''),
                subtitle: Text(session?.accountLabel ?? ''),
                trailing: IconButton(
                  tooltip: '退出登录',
                  onPressed: onLogout,
                  icon: const Icon(Icons.logout_rounded),
                ),
              ),
            if (signedIn)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('注销账号'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.danger,
                  ),
                ),
              ),
          ],
        ),
      );
}

class _LocalDataNote extends StatelessWidget {
  const _LocalDataNote();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.warmOutline),
        ),
        child: const Row(
          children: <Widget>[
            Icon(Icons.phone_iphone_rounded, color: AppColors.textSecondary),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                '学习档案和练习记录保存在这台手机上。',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      );
}

class _ProfileEditDialog extends StatefulWidget {
  const _ProfileEditDialog({required this.current});

  final ChildProfile current;

  @override
  State<_ProfileEditDialog> createState() => _ProfileEditDialogState();
}

class _ProfileEditDialogState extends State<_ProfileEditDialog> {
  late final TextEditingController _nameController =
      TextEditingController(text: widget.current.name);

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('我的资料'),
        content: SizedBox(
          width: 340,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                TextField(
                  controller: _nameController,
                  maxLength: 12,
                  decoration: const InputDecoration(labelText: '昵称'),
                ),
                const Text(
                  '头像暂时使用昵称首字母，后续可在这里上传照片。',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(
              ChildProfile(
                name: _nameController.text.trim().isEmpty
                    ? widget.current.name
                    : _nameController.text.trim(),
                grade: widget.current.grade,
                avatarId: widget.current.avatarId,
              ),
            ),
            child: const Text('保存'),
          ),
        ],
      );
}
