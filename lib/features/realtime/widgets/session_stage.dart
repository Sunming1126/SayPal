import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../domain/realtime_models.dart';
import '../domain/realtime_session_state.dart';

/// 会话舞台：字幕气泡、AI 说话动效、示范回答与自由输入。
/// 聊一聊 / 学一学 / 角色扮演三个 feature 共用；是否显示输入框
/// 由仓库能力决定（真实语音链路只收音，不收文字）。
class SessionStage extends StatelessWidget {
  const SessionStage({
    required this.state,
    required this.onSubmitReply,
    required this.onEndSession,
    this.onWordTap,
    this.header,
    this.inputPlaceholder = '也可以自己说一句哦',
    this.supportsTextInput = true,
    this.showTranslations = true,
    super.key,
  });

  final RealtimeSessionState state;
  final ValueChanged<String> onSubmitReply;
  final VoidCallback onEndSession;

  /// 点击字幕中的单词（演示词典查词）。
  final void Function(String word)? onWordTap;

  /// 顶部自定义内容（如情景任务进度、课程步骤提示）。
  final Widget? header;

  final String inputPlaceholder;

  /// 演示实现支持文字回答；真实语音链路只收音，不收文字。
  final bool supportsTextInput;

  /// 是否显示 AI 台词的中文提示（翻译开关）。
  final bool showTranslations;

  @override
  Widget build(BuildContext context) {
    final bool demo = AppConfig.instance.isDemoMode;
    return Column(
      children: [
        if (demo) ...[
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: ServiceNotConfiguredBanner(),
          ),
          const SizedBox(height: 8),
        ],
        if (header != null) header!,
        Expanded(child: _buildBody()),
        _buildComposer(context),
      ],
    );
  }

  Widget _buildBody() {
    if (state.isFailed) {
      switch (state.failureReason) {
        case RealtimeFailureReason.micPermissionDenied:
          return const MicPermissionDeniedView();
        case RealtimeFailureReason.serviceNotConfigured:
          return ErrorStateView(
            title: '服务还没有准备好',
            message: state.failureZhText,
          );
        case RealtimeFailureReason.networkError:
        case RealtimeFailureReason.unknown:
        case null:
          return ErrorStateView(
            title: '会话出了点问题',
            message: state.failureZhText,
          );
      }
    }
    if (state.phase == RealtimeSessionPhase.preparing ||
        state.phase == RealtimeSessionPhase.connecting) {
      return const LoadingView(message: '正在准备小老师…');
    }
    return _TranscriptListView(
      state: state,
      onWordTap: onWordTap,
      showTranslations: showTranslations,
    );
  }

  Widget _buildComposer(BuildContext context) {
    if (!state.isActive || state.isFailed) {
      return const SizedBox.shrink();
    }
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (state.aiSpeaking)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  '🔊 小老师正在说话…',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (state.suggestions.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final String suggestion in state.suggestions)
                    _SuggestionChip(
                      label: suggestion,
                      onTap: () => onSubmitReply(suggestion),
                    ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                if (supportsTextInput) ...[
                  Expanded(
                    child: _FreeTextInput(
                      hint: inputPlaceholder,
                      onSubmit: onSubmitReply,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: onEndSession,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.outline),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(24)),
                      ),
                    ),
                    icon: const Icon(Icons.stop_circle_outlined, size: 22),
                    label: const Text('结束'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryDark,
            ),
          ),
        ),
      ),
    );
  }
}

class _FreeTextInput extends StatefulWidget {
  const _FreeTextInput({required this.hint, required this.onSubmit});

  final String hint;
  final ValueChanged<String> onSubmit;

  @override
  State<_FreeTextInput> createState() => _FreeTextInputState();
}

class _FreeTextInputState extends State<_FreeTextInput> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final String text = _controller.text.trim();
    if (text.isEmpty) {
      return;
    }
    widget.onSubmit(text);
    _controller.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      textInputAction: TextInputAction.send,
      onSubmitted: (_) => _submit(),
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        hintText: widget.hint,
        hintStyle: const TextStyle(color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: AppColors.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: AppColors.outline),
        ),
        suffixIcon: IconButton(
          icon: const Icon(Icons.send, color: AppColors.primary, size: 22),
          onPressed: _submit,
        ),
      ),
    );
  }
}

class _TranscriptListView extends StatelessWidget {
  const _TranscriptListView({
    required this.state,
    this.onWordTap,
    this.showTranslations = true,
  });

  final RealtimeSessionState state;
  final void Function(String word)? onWordTap;
  final bool showTranslations;

  @override
  Widget build(BuildContext context) {
    if (state.transcripts.isEmpty) {
      return const EmptyStateView(
        emoji: '👋',
        title: '马上开始啦',
        message: '小老师正在向你打招呼…',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: state.transcripts.length,
      itemBuilder: (BuildContext context, int index) {
        return _Bubble(
          entry: state.transcripts[index],
          onWordTap: onWordTap,
          showTranslation: showTranslations,
        );
      },
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.entry,
    this.onWordTap,
    this.showTranslation = true,
  });

  final TranscriptEntry entry;
  final void Function(String word)? onWordTap;
  final bool showTranslation;

  bool get _isAi => entry.speaker == TranscriptSpeaker.ai;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: _isAi ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: _isAi ? AppColors.bubbleAi : AppColors.bubbleChild,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(_isAi ? 4 : 18),
            bottomRight: Radius.circular(_isAi ? 18 : 4),
          ),
          border: _isAi ? Border.all(color: AppColors.outline) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TappableText(
              text: entry.text,
              color: _isAi ? AppColors.textPrimary : Colors.white,
              onWordTap: onWordTap,
            ),
            if (entry.zhHint != null && showTranslation) ...[
              const SizedBox(height: 6),
              Text(
                entry.zhHint!,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: _isAi ? AppColors.textSecondary : Colors.white70,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 可点词的英文文本：把连续字母切成"词"，点击回调查词。
class _TappableText extends StatelessWidget {
  const _TappableText(
      {required this.text, required this.color, this.onWordTap});

  final String text;
  final Color color;
  final void Function(String word)? onWordTap;

  @override
  Widget build(BuildContext context) {
    if (onWordTap == null) {
      return Text(
        text,
        style: TextStyle(fontSize: 17, height: 1.5, color: color),
      );
    }
    final List<InlineSpan> spans = <InlineSpan>[];
    final RegExp wordPattern = RegExp(r"[A-Za-z']+");
    int cursor = 0;
    for (final RegExpMatch match in wordPattern.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(
          TextSpan(
            text: text.substring(cursor, match.start),
            style: TextStyle(fontSize: 17, height: 1.5, color: color),
          ),
        );
      }
      final String word = match.group(0)!;
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: GestureDetector(
            onTap: () => onWordTap!(word),
            child: Text(
              word,
              style: TextStyle(
                fontSize: 17,
                height: 1.5,
                color: color,
                decoration: TextDecoration.underline,
                decorationColor: color.withValues(alpha: 0.35),
                decorationStyle: TextDecorationStyle.dotted,
              ),
            ),
          ),
        ),
      );
      cursor = match.end;
    }
    if (cursor < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(cursor),
          style: TextStyle(fontSize: 17, height: 1.5, color: color),
        ),
      );
    }
    return RichText(
      text: TextSpan(children: spans),
    );
  }
}
