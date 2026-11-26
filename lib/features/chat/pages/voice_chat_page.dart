import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/adventure_widgets.dart'
    show ChildFriendlyErrorCard;
import '../../realtime/voice/widgets/voice_feedback_widgets.dart';
import '../../vocabulary/models/vocab_models.dart';
import '../models/chat_session.dart';
import '../providers/chat_session_providers.dart';
import '../voice/voice_chat_controller.dart';
import '../voice/voice_chat_providers.dart';

/// 页面不主动进入 RTC；首次语音或文字操作才按需准备连接。
class VoiceChatPage extends ConsumerStatefulWidget {
  const VoiceChatPage({super.key});

  @override
  ConsumerState<VoiceChatPage> createState() => _VoiceChatPageState();
}

class _VoiceChatPageState extends ConsumerState<VoiceChatPage>
    with WidgetsBindingObserver {
  static const VoiceMessage _welcomeMessage = VoiceMessage(
    id: 'local-welcome',
    text: 'Hi! What would you like to talk about?',
    translation: '嗨！你今天想聊点什么？',
    child: false,
  );
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final Set<String> _translatedMessageIds = <String>{};
  late String _currentSessionId;
  late DateTime _sessionCreatedAt;

  @override
  void initState() {
    super.initState();
    _beginLocalSession();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      unawaited(ref.read(voiceChatProvider.notifier).pause());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final VoiceChatState state = ref.watch(voiceChatProvider);
    final VoiceChatController controller = ref.read(voiceChatProvider.notifier);
    ref.listen(
      voiceChatProvider.select(
        (VoiceChatState value) =>
            (value.messages.length, value.isAwaitingFirstReply),
      ),
      (_, __) => _scrollToLatest(),
    );
    ref.listen(
      voiceChatProvider.select((VoiceChatState value) => value.messages),
      (_, List<VoiceMessage> messages) {
        if (messages.isNotEmpty) unawaited(_saveSession(messages));
      },
    );
    final bool ready = state.botReady && state.phase == VoicePhase.ready;
    final bool recording = state.capturePhase == VoiceCapturePhase.recording ||
        state.capturePhase == VoiceCapturePhase.paused;
    final bool canStart = recording || state.canStartTurn;
    final bool failed = state.error.isNotEmpty;
    final bool keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final List<VoiceMessage> messages = <VoiceMessage>[
      _welcomeMessage,
      ...state.messages,
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFF),
      body: Column(
        children: <Widget>[
          _ChatHeader(
            onHistory: _showSessionPanel,
            muted: state.isMuted,
            onMute: () =>
                ref.read(voiceChatProvider.notifier).toggleMute(),
          ),
          if (failed)
            ChildFriendlyErrorCard(
              message: friendlyVoiceError(state.error),
              onRetry: () => unawaited(_reconnect(controller)),
            ),
          if (!failed && state.notice.isNotEmpty)
            VoiceNoticePill(message: state.notice),
          Expanded(
            child: ListView(
              controller: _scroll,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              children: <Widget>[
                for (final VoiceMessage message in messages)
                  _AnimatedMessageBubble(
                    key: ValueKey<String>('animated-${message.id}'),
                    message: message,
                    ready: ready,
                    canReplay: ready && !state.isMuted,
                    translated: _translatedMessageIds.contains(message.id),
                    onWordTap: _lookup,
                    onReplay: () => controller.replay(message),
                    onTranslation: () => setState(() {
                      controller.requestTranslation(message);
                      if (!_translatedMessageIds.add(message.id)) {
                        _translatedMessageIds.remove(message.id);
                      }
                    }),
                  ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder:
                      (Widget child, Animation<double> animation) =>
                          FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, .08),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: state.isAwaitingFirstReply
                      ? XiaolanThinkingBubble(
                          key: const ValueKey<String>('ai-thinking'),
                          onCancel: controller.cancelPendingTurn,
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          if (state.partial.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.sunSoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '我听到：${state.partial}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          _ChatComposer(
            ready: canStart,
            recording: recording,
            microphonePublishing: state.isMicrophonePublishing,
            statusHint: '点击说英语',
            input: _input,
            maxTextLength: 1000,
            onInputIntent: controller.warmUp,
            onMicTap: recording
                    ? () => unawaited(controller.endRecording())
                : canStart
                    ? () => unawaited(_startRecording(controller))
                    : null,
            onSendText: (String text) => _send(controller),
          ),
          // MainShell deliberately overlays its liquid-glass dock over page
          // content. This breathing room keeps the composer above that dock
          // while the page background remains visible behind it.
          SizedBox(height: keyboardOpen ? 0 : 78),
        ],
      ),
    );
  }

  void _beginLocalSession() {
    final DateTime now = DateTime.now();
    _sessionCreatedAt = now;
    _currentSessionId = 'chat-${now.microsecondsSinceEpoch}';
  }

  Future<void> _showSessionPanel() => showGeneralDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierLabel: '关闭会话记录',
        barrierColor: Colors.black.withValues(alpha: .34),
        transitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (
          BuildContext dialogContext,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
        ) => Consumer(
          builder: (BuildContext context, WidgetRef ref, Widget? child) =>
              Align(
            alignment: Alignment.centerLeft,
            child: Material(
              color: Colors.transparent,
              child: SizedBox(
                width: MediaQuery.sizeOf(dialogContext).width * .8,
                height: double.infinity,
                child: _ChatSessionPanel(
                  sessions: ref.watch(chatSessionHistoryProvider),
                  currentSessionId: _currentSessionId,
                  onNewConversation: _newConversation,
                  onSelect: _openSession,
                ),
              ),
            ),
          ),
        ),
        transitionBuilder: (
          BuildContext context,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
          Widget child,
        ) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(-1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: child,
        ),
      );

  Future<void> _saveSession(List<VoiceMessage> messages) async {
    final List<ChatSessionMessage> stored = messages
        .map(ChatSessionMessage.fromVoiceMessage)
        .toList(growable: false);
    final VoiceMessage firstUser = messages.firstWhere(
      (VoiceMessage message) => message.child,
      orElse: () => messages.first,
    );
    final String normalized = firstUser.text.trim().replaceAll('\n', ' ');
    final String title = normalized.length > 18
        ? '${normalized.substring(0, 18)}…'
        : normalized;
    await ref.read(chatSessionHistoryProvider.notifier).save(
          ChatSession(
            id: _currentSessionId,
            title: title.isEmpty ? '日常交流' : title,
            createdAt: _sessionCreatedAt,
            updatedAt: DateTime.now(),
            messages: stored,
          ),
        );
  }

  Future<void> _newConversation() async {
    _translatedMessageIds.clear();
    _beginLocalSession();
    await ref.read(voiceChatProvider.notifier).startConversation();
    if (mounted) setState(() {});
  }

  Future<void> _openSession(ChatSession session) async {
    _currentSessionId = session.id;
    _sessionCreatedAt = session.createdAt;
    _translatedMessageIds
      ..clear()
      ..addAll(
        session.messages
            .where((ChatSessionMessage message) =>
                message.translation.isNotEmpty)
            .map((ChatSessionMessage message) => message.id),
      );
    await ref.read(voiceChatProvider.notifier).startConversation(
          messages: session.messages
              .map((ChatSessionMessage message) => message.toVoiceMessage())
              .toList(growable: false),
        );
    if (mounted) setState(() {});
  }

  Future<void> _reconnect(VoiceChatController controller) async {
    await controller.pause();
    await controller.connect();
  }

  Future<void> _startRecording(VoiceChatController controller) async {
    await controller.startRecording();
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      if (MediaQuery.disableAnimationsOf(context)) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
        return;
      }
      unawaited(_scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      ));
    });
  }

  void _send(VoiceChatController controller) {
    if (!ref.read(voiceChatProvider).canStartTurn) return;
    unawaited(controller.sendText(_input.text));
    _input.clear();
  }

  Future<void> _lookup(String raw) async {
    final String word = raw.replaceAll(RegExp("[^a-zA-Z'-]"), '').toLowerCase();
    if (word.isEmpty) return;
    final result = ref.read(voiceWordLookupProvider).lookup(word);
    final repository = ref.read(voiceVocabularyProvider);
    bool saved = await repository.isSaved(word);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter update) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(word, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 12),
                Text(
                  result?.meaningZh ?? '本地词典暂未收录，可以在对话中询问这个词的意思。',
                ),
                if (result != null)
                  FilledButton(
                    onPressed: saved
                        ? null
                        : () async {
                            try {
                              await repository.saveWord(VocabWord(
                                word: word,
                                meaningZh: result.meaningZh,
                                phonetic: result.phonetic,
                                exampleEn: result.exampleEn,
                                exampleZh: result.exampleZh,
                                addedAt: DateTime.now(),
                                source: '聊一聊',
                              ));
                              if (context.mounted) {
                                update(() => saved = true);
                              }
                            } catch (_) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('保存失败，请重试。'),
                                  ),
                                );
                              }
                            }
                          },
                    child: Text(saved ? '已加入生词本' : '加入生词本'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedMessageBubble extends StatefulWidget {
  const _AnimatedMessageBubble({
    required this.message,
    required this.ready,
    required this.canReplay,
    required this.translated,
    required this.onWordTap,
    required this.onReplay,
    required this.onTranslation,
    super.key,
  });

  final VoiceMessage message;

  /// Session ready: gates word-tap lookups.
  final bool ready;

  /// Replay needs the session ready AND sound not muted.
  final bool canReplay;
  final bool translated;
  final ValueChanged<String> onWordTap;
  final VoidCallback onReplay;
  final VoidCallback onTranslation;

  @override
  State<_AnimatedMessageBubble> createState() => _AnimatedMessageBubbleState();
}

class _AnimatedMessageBubbleState extends State<_AnimatedMessageBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final VoiceMessage message = widget.message;
    final double bubbleMaxWidth = MediaQuery.sizeOf(context).width *
        (message.child ? .78 : .76);
    final Widget bubble = Align(
      alignment: message.child ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisAlignment:
            message.child ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Flexible(
            child: Container(
              key: ValueKey<String>('chat-message-${message.id}'),
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(15),
              constraints: BoxConstraints(maxWidth: bubbleMaxWidth),
              decoration: BoxDecoration(
                color: message.child
                    ? AppColors.surface
                    : const Color(0xFFEAF2FF),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(22),
                  topRight: const Radius.circular(22),
                  bottomLeft: Radius.circular(message.child ? 22 : 7),
                  bottomRight: Radius.circular(message.child ? 7 : 22),
                ),
                border: Border.all(color: AppColors.outline),
                boxShadow: AppColors.softShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Wrap(
                    children: <Widget>[
                      for (final String word
                          in message.text.split(RegExp(r'\s+')))
                        InkWell(
                          onTap: widget.ready && !message.child
                              ? () => widget.onWordTap(word)
                              : null,
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 2,
                              vertical: 3,
                            ),
                            child: Text(
                              word,
                              style: const TextStyle(
                                fontSize: 19,
                                height: 1.35,
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (widget.translated && message.translation.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        message.translation,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  if (message.correction.isNotEmpty)
                    Theme(
                      data: Theme.of(context).copyWith(
                        dividerColor: Colors.transparent,
                      ),
                      child: ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: EdgeInsets.zero,
                        title: const Text(
                          '这样说更自然',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        children: <Widget>[
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              message.correction,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (!message.child)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          IconButton.filled(
                            key: ValueKey<String>(
                              'translation-${message.id}',
                            ),
                            tooltip: widget.translated ? '收起翻译' : '翻译',
                            onPressed: widget.onTranslation,
                            style: IconButton.styleFrom(
                              backgroundColor: AppColors.surface,
                              foregroundColor: AppColors.primary,
                              minimumSize: const Size(40, 40),
                              padding: const EdgeInsets.all(9),
                              elevation: 1,
                            ),
                            icon: const Icon(
                              Icons.translate_rounded,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            key: ValueKey<String>('replay-${message.id}'),
                            tooltip: '再听一次',
                            onPressed:
                                message.audio != null && widget.canReplay
                                    ? widget.onReplay
                                    : null,
                            style: IconButton.styleFrom(
                              backgroundColor: AppColors.surface,
                              foregroundColor: AppColors.textPrimary,
                              disabledBackgroundColor:
                                  AppColors.surface.withValues(alpha: .72),
                              disabledForegroundColor:
                                  AppColors.textSecondary.withValues(alpha: .5),
                              minimumSize: const Size(40, 40),
                              padding: const EdgeInsets.all(9),
                              elevation: 1,
                            ),
                            icon: const Icon(
                              Icons.volume_up_rounded,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
    if (MediaQuery.disableAnimationsOf(context)) return bubble;
    return FadeTransition(
      opacity: _controller,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, .08),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeOut),
        ),
        child: bubble,
      ),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({
    required this.onHistory,
    required this.muted,
    required this.onMute,
  });

  final VoidCallback onHistory;
  final bool muted;
  final VoidCallback onMute;

  @override
  Widget build(BuildContext context) => SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Row(
            children: <Widget>[
              Semantics(
                button: true,
                label: '历史会话',
                key: const ValueKey<String>('chat-history-button'),
                child: GlassIconButton(
                  size: 48,
                  iconSize: 26,
                  useOwnLayer: true,
                  glowColor: AppColors.primarySoft,
                  onPressed: onHistory,
                  icon: const Icon(Icons.segment_rounded),
                ),
              ),
              const Expanded(
                child: _TeacherIdentity(),
              ),
              Semantics(
                button: true,
                label: muted ? '取消全局静音' : '全局静音',
                key: const ValueKey<String>('chat-mute-button'),
                child: GlassIconButton(
                  size: 48,
                  iconSize: 26,
                  useOwnLayer: true,
                  glowColor: AppColors.primarySoft,
                  onPressed: onMute,
                  icon: Icon(
                    muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class _TeacherIdentity extends StatelessWidget {
  const _TeacherIdentity();

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            key: const ValueKey<String>('alex-avatar-placeholder'),
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surface,
              border: Border.all(color: AppColors.outline),
              boxShadow: AppColors.softShadow,
            ),
            child: const Icon(
              Icons.person_outline_rounded,
              size: 22,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 9),
          const Text(
            'Alex老师',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      );
}

enum _ChatComposerMode { voice, text }

/// Free-chat-only composer matching the three-control layout of the approved
/// mockup. Practice screens continue using their existing compact composer.
class _ChatComposer extends StatefulWidget {
  const _ChatComposer({
    required this.ready,
    required this.recording,
    required this.microphonePublishing,
    required this.statusHint,
    required this.onMicTap,
    required this.onSendText,
    required this.input,
    required this.maxTextLength,
    this.onInputIntent,
  });

  final bool ready;
  final bool recording;
  final bool microphonePublishing;
  final String statusHint;
  final VoidCallback? onMicTap;
  final ValueChanged<String> onSendText;
  final TextEditingController input;
  final int maxTextLength;
  final VoidCallback? onInputIntent;

  @override
  State<_ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<_ChatComposer> {
  _ChatComposerMode _mode = _ChatComposerMode.voice;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.input.addListener(_refresh);
  }

  @override
  void didUpdateWidget(_ChatComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.input != widget.input) {
      oldWidget.input.removeListener(_refresh);
      widget.input.addListener(_refresh);
    }
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _openKeyboard() {
    widget.onInputIntent?.call();
    setState(() => _mode = _ChatComposerMode.text);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  void _send() {
    final String text = widget.input.text.trim();
    if (!widget.ready || text.isEmpty) return;
    widget.onSendText(text);
  }

  @override
  void dispose() {
    widget.input.removeListener(_refresh);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
        child: AnimatedSwitcher(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 200),
          child: _mode == _ChatComposerMode.text
              ? _buildTextMode()
              : _buildVoiceMode(),
        ),
      );

  Widget _buildVoiceMode() {
    final bool enabled = widget.onMicTap != null;
    return Container(
      key: const ValueKey<String>('chat-voice-composer'),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: AppColors.softShadow,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          _ComposerRoundAction(
            buttonKey: const ValueKey<String>('voice-switch-text-button'),
            icon: Icons.keyboard_alt_outlined,
            label: '键盘',
            onPressed: widget.recording ? null : _openKeyboard,
          ),
          Semantics(
            button: true,
            label: widget.recording ? '结束并发送' : '点击说英语',
            child: InkWell(
              key: const ValueKey<String>('voice-mic-button'),
              onTap: widget.onMicTap,
              customBorder: const CircleBorder(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 74,
                    height: 74,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: !enabled
                          ? AppColors.surfaceMuted
                          : widget.recording
                              ? AppColors.coral
                              : AppColors.primary,
                      boxShadow: AppColors.softShadow,
                    ),
                    child: Icon(
                      widget.recording
                          ? Icons.stop_rounded
                          : Icons.mic_rounded,
                      size: 34,
                      color: enabled
                          ? Colors.white
                          : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.recording
                        ? widget.microphonePublishing
                            ? '说完了，点这里发送'
                            : '点击发送'
                        : enabled
                            ? '点击说英语'
                            : widget.statusHint,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          _ComposerRoundAction(
            buttonKey: const ValueKey<String>('chat-hint-button'),
            icon: Icons.lightbulb_outline_rounded,
            label: '提示',
            onPressed: widget.ready
                ? () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('AI 提示将在下一步接入。')),
                    )
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildTextMode() => Container(
        key: const ValueKey<String>('chat-text-composer'),
        padding: const EdgeInsets.fromLTRB(8, 6, 6, 6),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: AppColors.outline),
          boxShadow: AppColors.softShadow,
        ),
        child: Row(
          children: <Widget>[
            IconButton(
              key: const ValueKey<String>('voice-switch-mic-button'),
              tooltip: '切换到语音输入',
              onPressed: () {
                _focusNode.unfocus();
                setState(() => _mode = _ChatComposerMode.voice);
              },
              icon: const Icon(Icons.mic_none_rounded),
            ),
            Expanded(
              child: TextField(
                controller: widget.input,
                focusNode: _focusNode,
                enabled: widget.ready,
                onTap: widget.onInputIntent,
                maxLength: widget.maxTextLength,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: const InputDecoration(
                  hintText: '输入英语或中文',
                  counterText: '',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                ),
              ),
            ),
            IconButton.filled(
              key: const ValueKey<String>('voice-send-button'),
              tooltip: '发送',
              onPressed: widget.ready && widget.input.text.trim().isNotEmpty
                  ? _send
                  : null,
              icon: const Icon(Icons.arrow_upward_rounded),
            ),
          ],
        ),
      );
}

class _ComposerRoundAction extends StatelessWidget {
  const _ComposerRoundAction({
    required this.buttonKey,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final Key buttonKey;
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          IconButton.filledTonal(
            key: buttonKey,
            onPressed: onPressed,
            icon: Icon(icon),
            style: IconButton.styleFrom(
              minimumSize: const Size(52, 52),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
}

class _ChatSessionPanel extends StatelessWidget {
  const _ChatSessionPanel({
    required this.sessions,
    required this.currentSessionId,
    required this.onNewConversation,
    required this.onSelect,
  });

  final AsyncValue<List<ChatSession>> sessions;
  final String currentSessionId;
  final Future<void> Function() onNewConversation;
  final Future<void> Function(ChatSession session) onSelect;

  @override
  Widget build(BuildContext context) => Material(
        key: const ValueKey<String>('chat-session-drawer'),
        color: const Color(0xFFF9FAFF),
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(right: Radius.circular(30)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 14, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Expanded(
                      child: Text(
                        '会话记录',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '关闭',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  key: const ValueKey<String>('chat-new-session-button'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    onNewConversation();
                  },
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('新建会话'),
                ),
                const SizedBox(height: 22),
                const Text(
                  '历史会话',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: sessions.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    error: (_, __) => const Center(
                      child: Text('历史会话暂时无法读取'),
                    ),
                    data: (List<ChatSession> items) => items.isEmpty
                        ? const _EmptyChatHistory()
                        : ListView.separated(
                            itemCount: items.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 6),
                            itemBuilder: (BuildContext context, int index) {
                              final ChatSession session = items[index];
                              final bool selected =
                                  session.id == currentSessionId;
                              return ListTile(
                                key: ValueKey<String>(
                                  'chat-session-${session.id}',
                                ),
                                selected: selected,
                                selectedTileColor: AppColors.primarySoft,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                leading: Icon(
                                  selected
                                      ? Icons.chat_bubble_rounded
                                      : Icons.chat_bubble_outline_rounded,
                                  color: selected
                                      ? AppColors.primary
                                      : AppColors.textSecondary,
                                ),
                                title: Text(
                                  session.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                subtitle: Text(
                                  '${session.messages.length} 条消息 · ${_dateLabel(session.updatedAt)}',
                                  maxLines: 1,
                                ),
                                onTap: selected
                                    ? () => Navigator.of(context).pop()
                                    : () {
                                        Navigator.of(context).pop();
                                        onSelect(session);
                                      },
                              );
                            },
                          ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Text(
                    '文字记录仅保存在本机，不保存录音。',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  static String _dateLabel(DateTime value) {
    final DateTime now = DateTime.now();
    if (value.year == now.year &&
        value.month == now.month &&
        value.day == now.day) {
      return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    }
    return '${value.month}月${value.day}日';
  }
}

class _EmptyChatHistory extends StatelessWidget {
  const _EmptyChatHistory();

  @override
  Widget build(BuildContext context) => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.forum_outlined,
              size: 42,
              color: AppColors.textSecondary,
            ),
            SizedBox(height: 12),
            Text(
              '还没有历史会话',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 4),
            Text(
              '开始聊天后会自动保存在这里',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
}
