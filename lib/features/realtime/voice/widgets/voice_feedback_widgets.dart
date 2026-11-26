import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

class VoiceLiveTranscript extends StatelessWidget {
  const VoiceLiveTranscript({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.sunSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 52),
        child: SingleChildScrollView(
          reverse: true,
          child: Text('我听到：$text'),
        ),
      ),
    );
  }
}

class VoiceTranscribingLabel extends StatelessWidget {
  const VoiceTranscribingLabel({
    this.color = AppColors.textSecondary,
    super.key,
  });

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text('识别中…', style: TextStyle(fontSize: 12, color: color));
  }
}

/// Converts service diagnostics into short, user-facing recovery copy.
/// The controller retains the original message for tests and diagnostics;
/// screens should use this text so infrastructure terms never reach children.
String friendlyVoiceError(String raw) {
  if (raw.contains('访问凭证') || raw.contains('无法连接语音服务器') ||
      raw.contains('语音服务尚未就绪')) {
    return raw;
  }
  if (raw.contains('麦克风')) return '麦克风还没有打开，请允许后再试一次。';
  if (raw.contains('45000292') || raw.contains('识别额度已用完')) {
    return '语音服务的额度已用完，请让家长处理后再试。';
  }
  if (raw.contains('没有听清')) {
    return '没有听清，请说短一点再试一次。';
  }
  if (raw.contains('asr_rejected') || raw.contains('识别服务拒绝')) {
    return '语音服务的配置需要检查，请让家长稍后再试。';
  }
  if (raw.contains('识别等待超时')) {
    return '语音服务响应太慢了，请稍后再试一次。';
  }
  if (raw.contains('语音识别') || raw.contains('asr_')) {
    return '语音服务刚刚出了点问题，请稍后再试一次。';
  }
  if (raw.contains('连接已满')) return '现在练习的人有点多，请稍后再试一次。';
  if (raw.contains('练习内容无效')) return '这个场景还没准备好，请返回重新选择。';
  if (raw.contains('AI') || raw.contains('播放生成失败')) {
    return 'AI 回复暂时失败，请再说一次。';
  }
  if (raw.contains('超时')) return '响应时间有点久，请点这里重新准备。';
  return '对话暂时没准备好，点这里再试一次。';
}

class XiaolanThinkingBubble extends StatefulWidget {
  const XiaolanThinkingBubble({
    this.onCancel,
    this.cancelDelay = const Duration(seconds: 8),
    super.key,
  });

  final VoidCallback? onCancel;
  final Duration cancelDelay;

  @override
  State<XiaolanThinkingBubble> createState() => _XiaolanThinkingBubbleState();
}

class _XiaolanThinkingBubbleState extends State<XiaolanThinkingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );
  Timer? _cancelTimer;
  bool _showCancel = false;

  @override
  void initState() {
    super.initState();
    _cancelTimer = Timer(widget.cancelDelay, () {
      if (mounted) setState(() => _showCancel = true);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _controller.value = .5;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _cancelTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
        label: '小蓝正在回复',
        liveRegion: true,
        child: Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                key: const ValueKey<String>('thinking-dots-bubble'),
                width: 72,
                height: 46,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0xFFDCEAFF),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(22),
                    bottomLeft: Radius.circular(9),
                    bottomRight: Radius.circular(22),
                  ),
                ),
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (_, __) => Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List<Widget>.generate(3, (int index) {
                      final bool reduced =
                          MediaQuery.disableAnimationsOf(context);
                      final double strength = reduced
                          ? <double>[.45, .7, 1][index]
                          : _dot(_controller.value, index);
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3.5),
                        child: Transform.scale(
                          scale: reduced ? 1 : 1 + .15 * strength,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF35445F)
                                  .withValues(alpha: .38 + .62 * strength),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
              if (_showCancel && widget.onCancel != null)
                TextButton(
                  key: const ValueKey<String>('thinking-cancel-button'),
                  onPressed: widget.onCancel,
                  child: const Text('取消等待'),
                ),
            ],
          ),
        ),
      ));

  double _dot(double value, int index) {
    final double shifted = (value - index * .18) % 1;
    return shifted < .55 ? (1 - (shifted * 2 - 1).abs()).clamp(0, 1) : 0;
  }
}

class VoiceNoticePill extends StatelessWidget {
  const VoiceNoticePill({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
        key: const ValueKey<String>('voice-notice-pill'),
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.sunSoft,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.warmOutline),
        ),
        child: Row(
          children: <Widget>[
            const Icon(
              Icons.info_outline_rounded,
              size: 20,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
}
