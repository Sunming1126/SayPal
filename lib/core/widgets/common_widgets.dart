import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 高对比不透明内容卡片：课程正文、图表与长文本统一使用，
/// 液态玻璃不用于内容层。
class ContentCard extends StatelessWidget {
  const ContentCard({
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.color = AppColors.surface,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// 单一主操作的大按钮。
class PrimaryActionButton extends StatelessWidget {
  const PrimaryActionButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.enabled = true,
    this.color = AppColors.primary,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool enabled;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: FilledButton.icon(
        onPressed: enabled ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: AppColors.textOnPrimary,
          disabledBackgroundColor: AppColors.outline,
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(28)),
          ),
        ),
        icon: icon != null ? Icon(icon, size: 24) : null,
        label: Text(label),
      ),
    );
  }
}

/// 离线演示标识：凡是演示数据/演示对话必须可见此标记，避免伪称已接通真实服务。
class DemoBadge extends StatelessWidget {
  const DemoBadge({this.label = '离线演示', super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.warning),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.warning,
        ),
      ),
    );
  }
}

/// 加载态。
class LoadingView extends StatelessWidget {
  const LoadingView({this.message = '正在加载…', super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

/// 空态。
class EmptyStateView extends StatelessWidget {
  const EmptyStateView({
    required this.emoji,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String emoji;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 56)),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 20),
              PrimaryActionButton(label: actionLabel!, onPressed: onAction),
            ],
          ],
        ),
      ),
    );
  }
}

/// 失败态（含重试）。
class ErrorStateView extends StatelessWidget {
  const ErrorStateView({
    required this.title,
    required this.message,
    this.onRetry,
    super.key,
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 56, color: AppColors.danger),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              PrimaryActionButton(label: '再试一次', icon: Icons.refresh, onPressed: onRetry),
            ],
          ],
        ),
      ),
    );
  }
}

/// 真实服务未配置提示条：只说明状态，不泄露任何配置内容。
class ServiceNotConfiguredBanner extends StatelessWidget {
  const ServiceNotConfiguredBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.6)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: AppColors.warning, size: 22),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              '暂未连接实时语音服务，当前为离线演示内容，不能真实对话哦。',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 麦克风权限被拒绝态。
class MicPermissionDeniedView extends StatelessWidget {
  const MicPermissionDeniedView({this.onOpenSettings, super.key});

  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return EmptyStateView(
      emoji: '🎙️',
      title: '还没有麦克风权限',
      message: '口语练习需要使用麦克风。请让家长在手机设置里允许 SayPal 使用麦克风。',
      actionLabel: onOpenSettings != null ? '去设置' : null,
      onAction: onOpenSettings,
    );
  }
}

/// 分区标题。
class SectionHeader extends StatelessWidget {
  const SectionHeader({required this.title, this.trailing, super.key});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
