import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

const String kXiaolanAsset =
    'assets/images/mascot/xiaolan-roleplay-sticker.png';

const Map<String, String> kAvatarAssets = <String, String>{
  'tiger': 'assets/images/avatars/tiger.png',
  'panda': 'assets/images/avatars/panda.png',
  'fox': 'assets/images/avatars/fox.png',
  'rabbit': 'assets/images/avatars/rabbit.png',
  'koala': 'assets/images/avatars/koala.png',
  'lion': 'assets/images/avatars/lion.png',
};

class AdventureHero extends StatelessWidget {
  const AdventureHero({
    required this.title,
    required this.subtitle,
    this.eyebrow,
    this.compact = false,
    this.trailing,
    super.key,
  });

  final String title;
  final String subtitle;
  final String? eyebrow;
  final bool compact;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final double top = MediaQuery.paddingOf(context).top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, top + 14, 16, compact ? 18 : 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF4C7DFF), Color(0xFF3262E8)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (eyebrow != null) ...<Widget>[
                  Text(
                    eyebrow!,
                    style: const TextStyle(
                      color: Color(0xFFDDE7FF),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                ],
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: compact ? 25 : 29,
                    height: 1.15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFFEAF0FF),
                    fontSize: 14,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          trailing ?? const XiaolanAvatar(size: 78),
        ],
      ),
    );
  }
}

/// 内容型主页面使用的紧凑页头，让首屏更快进入学习或练习内容。
class CompactAdventureHeader extends StatelessWidget {
  const CompactAdventureHeader({
    required this.title,
    required this.subtitle,
    this.trailing,
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final double top = MediaQuery.paddingOf(context).top;
    final double textScale = MediaQuery.textScalerOf(context).scale(1);
    final bool hideSubtitle = textScale > 1.3;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(18, top + 8, 14, 10),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF4C7DFF), Color(0xFF3262E8)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (!hideSubtitle) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFEAF0FF),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...<Widget>[
            const SizedBox(width: 10),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class CompactHeaderAction extends StatelessWidget {
  const CompactHeaderAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final bool iconOnly = MediaQuery.sizeOf(context).width < 350 ||
        MediaQuery.textScalerOf(context).scale(1) > 1.25;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: iconOnly ? 12 : 13),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(icon, color: AppColors.primaryDark, size: 21),
                if (!iconOnly) ...<Widget>[
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class XiaolanAvatar extends StatelessWidget {
  const XiaolanAvatar({this.size = 52, this.isSpeaking = false, super.key});

  final double size;
  final bool isSpeaking;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * .08),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: isSpeaking ? AppColors.sun : Colors.white,
          width: isSpeaking ? 4 : 2,
        ),
        boxShadow: AppColors.softShadow,
      ),
      child: ClipOval(
        child: Image.asset(kXiaolanAsset, fit: BoxFit.cover),
      ),
    );
  }
}

class AnimalAvatar extends StatelessWidget {
  const AnimalAvatar({required this.avatarId, this.size = 72, super.key});

  final String avatarId;
  final double size;

  @override
  Widget build(BuildContext context) {
    final String asset = kAvatarAssets[avatarId] ?? kAvatarAssets['tiger']!;
    return ClipOval(
      child: Image.asset(asset, width: size, height: size, fit: BoxFit.cover),
    );
  }
}

class PressScaleCard extends StatefulWidget {
  const PressScaleCard({
    required this.child,
    required this.onTap,
    this.borderRadius = 26,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double borderRadius;

  @override
  State<PressScaleCard> createState() => _PressScaleCardState();
}

class _PressScaleCardState extends State<PressScaleCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown:
          widget.onTap == null ? null : (_) => setState(() => _pressed = true),
      onTapUp:
          widget.onTap == null ? null : (_) => setState(() => _pressed = false),
      onTapCancel:
          widget.onTap == null ? null : () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: !reduceMotion && _pressed ? .97 : 1,
        duration: Duration(milliseconds: reduceMotion ? 0 : 120),
        curve: Curves.easeOut,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          child: widget.child,
        ),
      ),
    );
  }
}

class ChildFriendlyErrorCard extends StatelessWidget {
  const ChildFriendlyErrorCard({
    required this.onRetry,
    this.message = '小蓝暂时没准备好，点这里再试一次',
    super.key,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.coralSoft,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.coral.withValues(alpha: .35)),
        ),
        child: Row(
          children: <Widget>[
            const Icon(Icons.cloud_off_rounded, color: AppColors.coral),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            TextButton(onPressed: onRetry, child: const Text('再试一次')),
          ],
        ),
      );
}

class SafeBottomSpace extends StatelessWidget {
  const SafeBottomSpace({this.minimum = 20, super.key});

  final double minimum;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: minimum + MediaQuery.paddingOf(context).bottom,
      );
}
