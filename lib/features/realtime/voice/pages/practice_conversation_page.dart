import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../../scenario/data/roleplay_suggestion_repository.dart';
import '../../../scenario/providers/practice_providers.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/adventure_widgets.dart';
import '../conversation_context.dart';
import '../voice_conversation_controller.dart';
import '../voice_conversation_providers.dart';
import '../widgets/voice_feedback_widgets.dart';

class PracticeConversationPage extends ConsumerStatefulWidget {
  const PracticeConversationPage({
    required this.context,
    required this.welcome,
    required this.objectives,
    required this.finishedLabel,
    this.nextRoute,
    this.onCompleted,
    super.key,
  });

  final ConversationContext context;
  final String welcome;
  final List<String> objectives;
  final String finishedLabel;
  final String? nextRoute;
  final Future<void> Function()? onCompleted;

  @override
  ConsumerState<PracticeConversationPage> createState() =>
      _PracticeConversationPageState();
}

class _PracticeConversationPageState
    extends ConsumerState<PracticeConversationPage>
    with WidgetsBindingObserver {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final Set<String> _translated = <String>{};
  final GlobalKey<_RoleplayComposerState> _roleplayComposer =
      GlobalKey<_RoleplayComposerState>();
  RoleplaySuggestion? _suggestion;
  bool _suggestionBusy = false;
  bool _suggestionTranslated = false;
  String _suggestionError = '';
  bool _allowPop = false;

  bool get _isRoleplay => widget.context.kind == ConversationKind.roleplay ||
      widget.context.kind == ConversationKind.customRoleplay;
  Timer? _preparingTimer;
  bool _showPreparing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _connectSilently();
    });
  }

  void _connectSilently() {
    if (!mounted) return;
    setState(() => _showPreparing = false);
    _preparingTimer?.cancel();
    _preparingTimer = Timer(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      final VoiceChatState state =
          ref.read(voiceConversationProvider(widget.context));
      if (state.phase == VoicePhase.connecting) {
        setState(() => _showPreparing = true);
      }
    });
    unawaited(
      ref.read(voiceConversationProvider(widget.context).notifier).connect(),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      unawaited(
        ref.read(voiceConversationProvider(widget.context).notifier).pause(),
      );
    } else if (state == AppLifecycleState.resumed &&
        ref.read(voiceConversationProvider(widget.context)).phase ==
            VoicePhase.offline) {
      _connectSilently();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _preparingTimer?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final VoiceChatState state =
        ref.watch(voiceConversationProvider(widget.context));
    final VoiceConversationController controller =
        ref.read(voiceConversationProvider(widget.context).notifier);
    ref.listen(
      voiceConversationProvider(widget.context).select(
        (VoiceChatState value) =>
            (value.messages.length, value.isAwaitingFirstReply),
      ),
      (_, __) => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          if (MediaQuery.disableAnimationsOf(context)) {
            _scroll.jumpTo(_scroll.position.maxScrollExtent);
            return;
          }
          unawaited(
            _scroll.animateTo(
              _scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
            ),
          );
        }
      }),
    );
    ref.listen(
      voiceConversationProvider(widget.context).select(
        (VoiceChatState value) => value.phase,
      ),
      (_, VoicePhase next) {
        if (next != VoicePhase.connecting && _showPreparing) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _showPreparing = false);
          });
        }
      },
    );
    final bool ready = state.phase == VoicePhase.ready;
    final bool recording = state.phase == VoicePhase.recording;
    final bool offline = state.phase == VoicePhase.offline;
    final List<VoiceMessage> messages = <VoiceMessage>[
      VoiceMessage(
        id: 'welcome-${widget.context.title}',
        text: widget.welcome,
        child: false,
      ),
      ...state.messages,
    ];

    if (_isRoleplay) {
      return _buildRoleplay(
        state: state, controller: controller,
        messages: messages, ready: ready, recording: recording,
        canStart: state.canStartTurn,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.context.title),
        actions: <Widget>[
          TextButton.icon(
            onPressed: () => _finish(controller, state),
            icon: const Icon(Icons.flag_outlined),
            label: const Text('结束'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _Goals(
              objectives: widget.objectives,
              completed: state.completedObjectives,
              label: state.progressLabel,
            ),
            if (_showPreparing && state.phase == VoicePhase.connecting)
              const VoiceNoticePill(message: '正在准备对话…'),
            if (state.error.isNotEmpty)
              ChildFriendlyErrorCard(
                message: state.error.contains('麦克风')
                    ? '麦克风还没有打开，请允许后再试一次'
                    : '小蓝暂时没准备好，点这里再试一次',
                onRetry: () => unawaited(_reconnect(controller)),
              ),
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.all(16),
                itemCount:
                    messages.length + (state.isAwaitingFirstReply ? 1 : 0),
                itemBuilder: (BuildContext context, int index) {
                  if (index == messages.length) {
                    return const XiaolanThinkingBubble(
                      key: ValueKey<String>('practice-xiaolan-thinking'),
                    );
                  }
                  return _MessageBubble(
                    message: messages[index],
                    ready: ready,
                    translated: _translated.contains(messages[index].id),
                    onReplay: () => controller.replay(messages[index]),
                    onTranslation: () => setState(() {
                      _translated.contains(messages[index].id)
                          ? _translated.remove(messages[index].id)
                          : _translated.add(messages[index].id);
                    }),
                  );
                },
              ),
            ),
            if (state.partial.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text('正在识别：${state.partial}',
                    maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
              child: Column(
                children: <Widget>[
                  if (!offline)
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: ready
                                ? () => controller.startRecording()
                                : recording
                                    ? controller.endRecording
                                    : null,
                            icon: Icon(recording
                                ? Icons.stop_circle_outlined
                                : Icons.mic),
                            label: Text(recording ? '说完了，发送' : '点击说话'),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: TextField(
                          controller: _input,
                          enabled: ready,
                          maxLength: 300,
                          decoration: const InputDecoration(
                            counterText: '',
                            hintText: '也可以输入英语',
                          ),
                          onSubmitted: ready ? (_) => _send(controller) : null,
                        ),
                      ),
                      IconButton(
                        onPressed: ready ? () => _send(controller) : null,
                        icon: const Icon(Icons.send_rounded),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleplay({
    required VoiceChatState state,
    required VoiceConversationController controller,
    required List<VoiceMessage> messages,
    required bool ready,
    required bool recording,
    required bool canStart,
  }) {
    final Set<String> favorites =
        ref.watch(roleplayFavoritesProvider).valueOrNull ?? const <String>{};
    final bool custom = widget.context.kind == ConversationKind.customRoleplay;
    final bool favorite = favorites.contains(widget.context.catalogId);
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) unawaited(_confirmExit(controller, state));
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: const Color(0xFFF6F8FC),
        body: SafeArea(
          child: Column(
            children: <Widget>[
              _RoleplayHeader(
                title: widget.context.title,
                muted: state.isMuted,
                onBack: () => unawaited(_confirmExit(controller, state)),
                onMute: () => unawaited(controller.toggleMute()),
                onFinish: () => unawaited(_finish(controller, state)),
              ),
              if (state.error.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ChildFriendlyErrorCard(
                    message: friendlyVoiceError(state.error),
                    onRetry: () => unawaited(_reconnect(controller)),
                  ),
                ),
              if (state.error.isEmpty && state.notice.isNotEmpty)
                VoiceNoticePill(message: state.notice),
              Expanded(
                child: ListView.builder(
                  controller: _scroll,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
                  itemCount:
                      messages.length + (state.isAwaitingFirstReply ? 1 : 0),
                  itemBuilder: (BuildContext context, int index) {
                    if (index == messages.length) {
                      return _RoleplayThinkingBubble(
                        onCancel: controller.cancelPendingTurn,
                      );
                    }
                    final VoiceMessage message = messages[index];
                    return _RoleplayMessageBubble(
                      message: message,
                      canReplay: ready && !state.isMuted,
                      translated: _translated.contains(message.id),
                      onReplay: () => controller.replay(message),
                      onTranslation: () => setState(() {
                        controller.requestTranslation(message);
                        _translated.contains(message.id)
                            ? _translated.remove(message.id)
                            : _translated.add(message.id);
                      }),
                    );
                  },
                ),
              ),
              if (state.partial.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Text(
                    '正在识别：${state.partial}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              if (_suggestion != null ||
                  _suggestionBusy ||
                  _suggestionError.isNotEmpty)
                _SuggestionCard(
                  suggestion: _suggestion,
                  busy: _suggestionBusy,
                  error: _suggestionError,
                  translated: _suggestionTranslated,
                  canPlay: ready && !state.isMuted,
                  onTranslate: () => setState(
                    () => _suggestionTranslated = !_suggestionTranslated,
                  ),
                  onPlay: () {
                    final audio = _suggestion?.audio;
                    if (audio != null) unawaited(controller.playAudio(audio));
                  },
                  onRefresh: () => unawaited(_generateSuggestion()),
                  onUse: () {
                    final String? text = _suggestion?.text;
                    if (text == null) return;
                    _input.text = text;
                    _roleplayComposer.currentState?.showTextInput();
                  },
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    _GlassPill(
                      key: const ValueKey<String>('roleplay-goals-button'),
                      icon: Icons.flag_outlined,
                      label:
                          '目标 ${state.completedObjectives}/${widget.objectives.length}',
                      onTap: () => _showGoals(state),
                    ),
                    const SizedBox(width: 10),
                    _GlassPill(
                      key: const ValueKey<String>('roleplay-favorite-button'),
                      icon: custom || favorite
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      label: custom
                          ? '已保存'
                          : favorite
                              ? '已收藏'
                              : '收藏',
                      onTap: custom || widget.context.catalogId == null
                          ? null
                          : () => ref
                              .read(roleplayFavoritesProvider.notifier)
                              .toggle(widget.context.catalogId!),
                    ),
                  ],
                ),
              ),
              _RoleplayComposer(
                key: _roleplayComposer,
                ready: canStart,
                recording: recording,
                microphonePublishing: state.isMicrophonePublishing,
                statusHint: '点击说话',
                input: _input,
                onInputIntent: controller.warmUp,
                maxTextLength: 300,
                onHint: ready && !_suggestionBusy
                    ? () => unawaited(_generateSuggestion())
                    : null,
                onMicTap: recording
                    ? () => unawaited(controller.endRecording())
                    : canStart
                        ? () => unawaited(controller.startRecording())
                        : null,
                onSendText: (String text) => controller.sendText(text),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _generateSuggestion() async {
    setState(() {
      _suggestionBusy = true;
      _suggestionError = '';
      _suggestionTranslated = false;
    });
    try {
      final RoleplaySuggestion suggestion =
          await ref.read(roleplaySuggestionRepositoryProvider).generate(
                context: widget.context,
                messages: ref
                    .read(voiceConversationProvider(widget.context))
                    .messages,
              );
      if (mounted) setState(() => _suggestion = suggestion);
    } catch (_) {
      if (mounted) {
        setState(() => _suggestionError = '暂时无法生成提示，请稍后重试。');
      }
    } finally {
      if (mounted) setState(() => _suggestionBusy = false);
    }
  }

  Future<void> _showGoals(VoiceChatState state) => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (BuildContext context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(widget.context.title,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text('${widget.context.learnerRole} · ${widget.context.aiRole}',
                    style: const TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                Text(widget.context.situation),
                const SizedBox(height: 18),
                ...List<Widget>.generate(
                  widget.objectives.length,
                  (int index) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      index < state.completedObjectives
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: index < state.completedObjectives
                          ? AppColors.success
                          : AppColors.textSecondary,
                    ),
                    title: Text(widget.objectives[index]),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Future<void> _confirmExit(
    VoiceConversationController controller,
    VoiceChatState state,
  ) async {
    final bool active = state.botReady || state.messages.isNotEmpty;
    if (active) {
      final bool? leave = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialog) => AlertDialog(
          title: const Text('结束这次练习？'),
          content: const Text('已完成的练习记录会保留。'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('继续练习'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: const Text('结束并返回'),
            ),
          ],
        ),
      );
      if (leave != true || !mounted) return;
    }
    await controller.pause();
    await _leavePage();
  }

  Future<void> _leavePage() async {
    if (!mounted) return;
    setState(() => _allowPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.of(context).pop();
  }

  void _send(VoiceConversationController controller) {
    controller.sendText(_input.text);
    _input.clear();
  }

  Future<void> _reconnect(VoiceConversationController controller) async {
    await controller.pause();
    _connectSilently();
  }

  Future<void> _finish(
    VoiceConversationController controller,
    VoiceChatState state,
  ) async {
    await controller.pause();
    if (!mounted) return;
    final bool? next = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialog) => AlertDialog(
        title: Text(widget.finishedLabel),
        content: Text(
          '这次你开口或发送了 ${state.spokenTurns} 次。\n'
          '完成目标：${state.completedObjectives}/${widget.objectives.length}\n'
          '继续保持开口练习吧！',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('完成'),
          ),
          if (widget.nextRoute != null)
            FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: const Text('进入下一步'),
            ),
        ],
      ),
    );
    if (!mounted) return;
    if (state.completedObjectives >= widget.objectives.length &&
        widget.onCompleted != null) {
      await widget.onCompleted!();
      if (!mounted) return;
    }
    if (next == true && widget.nextRoute != null) {
      context.pushReplacement(widget.nextRoute!);
    } else {
      if (_isRoleplay) {
        await _leavePage();
      } else {
        Navigator.of(context).pop();
      }
    }
  }
}

class _RoleplayHeader extends StatelessWidget {
  const _RoleplayHeader({
    required this.title,
    required this.muted,
    required this.onBack,
    required this.onMute,
    required this.onFinish,
  });
  final String title;
  final bool muted;
  final VoidCallback onBack;
  final VoidCallback onMute;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 2, 14, 6),
        child: SizedBox(
          height: 54,
          child: Row(
            children: <Widget>[
              GlassIconButton(
                key: const ValueKey<String>('roleplay-back-button'),
                size: 46,
                iconSize: 23,
                useOwnLayer: true,
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Container(
                      key: const ValueKey<String>('roleplay-avatar-placeholder'),
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(color: AppColors.outline),
                        boxShadow: AppColors.softShadow,
                      ),
                      child: const Icon(Icons.person_outline_rounded,
                          size: 21, color: AppColors.textSecondary),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        title,
                        key: const ValueKey<String>('roleplay-scene-title'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              GlassIconButton(
                key: const ValueKey<String>('roleplay-mute-button'),
                size: 46,
                iconSize: 23,
                useOwnLayer: true,
                onPressed: onMute,
                icon: Icon(muted
                    ? Icons.volume_off_rounded
                    : Icons.volume_up_rounded),
              ),
              const SizedBox(width: 6),
              GlassIconButton(
                key: const ValueKey<String>('roleplay-finish-button'),
                size: 46,
                iconSize: 23,
                useOwnLayer: true,
                onPressed: onFinish,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
      );
}

class _RoleplayMessageBubble extends StatelessWidget {
  const _RoleplayMessageBubble({
    required this.message,
    required this.canReplay,
    required this.translated,
    required this.onReplay,
    required this.onTranslation,
  });
  final VoiceMessage message;
  final bool canReplay;
  final bool translated;
  final VoidCallback onReplay;
  final VoidCallback onTranslation;

  @override
  Widget build(BuildContext context) => Align(
        alignment: message.child ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          key: ValueKey<String>('practice-message-${message.id}'),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width *
                (message.child ? .78 : .76),
          ),
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: message.child ? Colors.white : const Color(0xFFEAF2FF),
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
              Text(
                message.text,
                style: const TextStyle(
                  fontSize: 19,
                  height: 1.35,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (translated && message.translation.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(message.translation,
                      style: const TextStyle(color: AppColors.textSecondary)),
                ),
              if (!message.child)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      IconButton.filled(
                        key: ValueKey<String>(
                            'practice-translation-${message.id}'),
                        tooltip: translated ? '收起翻译' : '翻译',
                        onPressed: onTranslation,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.primary,
                          minimumSize: const Size(40, 40),
                        ),
                        icon: const Icon(Icons.translate_rounded, size: 20),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        key: ValueKey<String>('practice-replay-${message.id}'),
                        tooltip: '再听一次',
                        onPressed:
                            message.audio != null && canReplay ? onReplay : null,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.textPrimary,
                          minimumSize: const Size(40, 40),
                        ),
                        icon: const Icon(Icons.volume_up_rounded, size: 20),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
}

class _RoleplayThinkingBubble extends StatelessWidget {
  const _RoleplayThinkingBubble({required this.onCancel});
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          key: const ValueKey<String>('practice-roleplay-thinking'),
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF2FF),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 10),
              const Text('正在回复…'),
              TextButton(onPressed: onCancel, child: const Text('取消')),
            ],
          ),
        ),
      );
}

class _GlassPill extends StatelessWidget {
  const _GlassPill({
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white.withValues(alpha: .72),
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white),
              boxShadow: AppColors.softShadow,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(icon, size: 19, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(label,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ),
      );
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    required this.suggestion,
    required this.busy,
    required this.error,
    required this.translated,
    required this.canPlay,
    required this.onTranslate,
    required this.onPlay,
    required this.onRefresh,
    required this.onUse,
  });
  final RoleplaySuggestion? suggestion;
  final bool busy;
  final String error;
  final bool translated;
  final bool canPlay;
  final VoidCallback onTranslate;
  final VoidCallback onPlay;
  final VoidCallback onRefresh;
  final VoidCallback onUse;

  @override
  Widget build(BuildContext context) => Container(
        key: const ValueKey<String>('roleplay-suggestion-card'),
        margin: const EdgeInsets.fromLTRB(18, 4, 18, 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: <Color>[Color(0xFFE9F3FF), Color(0xFFF0ECFF)],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white),
        ),
        child: busy
            ? const Row(
                children: <Widget>[
                  SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 10),
                  Text('正在根据当前对话生成提示…'),
                ],
              )
            : error.isNotEmpty
                ? Row(
                    children: <Widget>[
                      Expanded(child: Text(error)),
                      TextButton(onPressed: onRefresh, child: const Text('重试')),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text('试着这样说',
                          style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w900)),
                      const SizedBox(height: 7),
                      Text(suggestion?.text ?? '',
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w700)),
                      if (translated)
                        Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Text(suggestion?.translation ?? '',
                              style: const TextStyle(
                                  color: AppColors.textSecondary)),
                        ),
                      const SizedBox(height: 7),
                      Wrap(
                        spacing: 4,
                        children: <Widget>[
                          IconButton(
                            key: const ValueKey<String>('suggestion-translate'),
                            onPressed: onTranslate,
                            icon: const Icon(Icons.translate_rounded),
                          ),
                          IconButton(
                            key: const ValueKey<String>('suggestion-play'),
                            onPressed: canPlay && suggestion?.audio != null
                                ? onPlay
                                : null,
                            icon: const Icon(Icons.volume_up_rounded),
                          ),
                          IconButton(
                            key: const ValueKey<String>('suggestion-refresh'),
                            onPressed: onRefresh,
                            icon: const Icon(Icons.refresh_rounded),
                          ),
                          FilledButton.tonal(
                            key: const ValueKey<String>('suggestion-use'),
                            onPressed: onUse,
                            child: const Text('使用这句'),
                          ),
                        ],
                      ),
                    ],
                  ),
      );
}

enum _RoleplayComposerMode { voice, text }

class _RoleplayComposer extends StatefulWidget {
  const _RoleplayComposer({
    required this.ready,
    required this.recording,
    required this.microphonePublishing,
    required this.statusHint,
    required this.onMicTap,
    required this.onSendText,
    required this.onHint,
    required this.input,
    required this.maxTextLength,
    this.onInputIntent,
    super.key,
  });
  final bool ready;
  final bool recording;
  final bool microphonePublishing;
  final String statusHint;
  final VoidCallback? onMicTap;
  final ValueChanged<String> onSendText;
  final VoidCallback? onHint;
  final TextEditingController input;
  final int maxTextLength;
  final VoidCallback? onInputIntent;

  @override
  State<_RoleplayComposer> createState() => _RoleplayComposerState();
}

class _RoleplayComposerState extends State<_RoleplayComposer> {
  _RoleplayComposerMode _mode = _RoleplayComposerMode.voice;
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.input.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void showTextInput() {
    setState(() => _mode = _RoleplayComposerMode.text);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    widget.input.removeListener(_refresh);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
        child: _mode == _RoleplayComposerMode.text
            ? _textComposer()
            : _voiceComposer(),
      );

  Widget _voiceComposer() => Container(
        key: const ValueKey<String>('roleplay-voice-composer'),
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: AppColors.softShadow,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            _ComposerAction(
              key: const ValueKey<String>('voice-switch-text-button'),
              icon: Icons.keyboard_alt_outlined,
              label: '键盘',
              onPressed: widget.recording ? null : showTextInput,
            ),
            InkWell(
              key: const ValueKey<String>('voice-mic-button'),
              onTap: widget.onMicTap,
              customBorder: const CircleBorder(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 74,
                    height: 74,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.onMicTap == null
                          ? AppColors.surfaceMuted
                          : widget.recording
                              ? AppColors.coral
                              : AppColors.primary,
                      boxShadow: AppColors.softShadow,
                    ),
                    child: Icon(
                      widget.recording ? Icons.stop_rounded : Icons.mic_rounded,
                      size: 34,
                      color: widget.onMicTap == null
                          ? AppColors.textSecondary
                          : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    widget.recording
                        ? widget.microphonePublishing
                            ? '说完点这里发送'
                            : '点击发送'
                        : widget.ready
                            ? '点击说英语'
                            : widget.statusHint,
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            _ComposerAction(
              key: const ValueKey<String>('roleplay-hint-button'),
              icon: Icons.lightbulb_outline_rounded,
              label: '提示',
              onPressed: widget.onHint,
            ),
          ],
        ),
      );

  Widget _textComposer() => Container(
        key: const ValueKey<String>('roleplay-text-composer'),
        padding: const EdgeInsets.fromLTRB(8, 6, 6, 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: AppColors.outline),
          boxShadow: AppColors.softShadow,
        ),
        child: Row(
          children: <Widget>[
            IconButton(
              key: const ValueKey<String>('roleplay-switch-mic-button'),
              onPressed: () {
                _focus.unfocus();
                setState(() => _mode = _RoleplayComposerMode.voice);
              },
              icon: const Icon(Icons.mic_none_rounded),
            ),
            Expanded(
              child: TextField(
                key: const ValueKey<String>('roleplay-text-field'),
                controller: widget.input,
                focusNode: _focus,
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
              onPressed: widget.ready && widget.input.text.trim().isNotEmpty
                  ? _send
                  : null,
              icon: const Icon(Icons.arrow_upward_rounded),
            ),
          ],
        ),
      );

  void _send() {
    final String text = widget.input.text.trim();
    if (widget.ready && text.isNotEmpty) widget.onSendText(text);
  }
}

class _ComposerAction extends StatelessWidget {
  const _ComposerAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    super.key,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          IconButton.filledTonal(
            onPressed: onPressed,
            icon: Icon(icon),
            style: IconButton.styleFrom(minimumSize: const Size(52, 52)),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700)),
        ],
      );
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.ready,
    required this.translated,
    required this.onReplay,
    required this.onTranslation,
  });
  final VoiceMessage message;
  final bool ready, translated;
  final VoidCallback onReplay, onTranslation;

  @override
  Widget build(BuildContext context) => Align(
        alignment: message.child ? Alignment.centerRight : Alignment.centerLeft,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            if (!message.child) ...<Widget>[
              const XiaolanAvatar(size: 36),
              const SizedBox(width: 8),
            ],
            Flexible(
                child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(15),
              constraints: const BoxConstraints(maxWidth: 520),
              decoration: BoxDecoration(
                color: message.child ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE0E5F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    message.text,
                    style: TextStyle(
                      fontSize: 18,
                      height: 1.35,
                      color:
                          message.child ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  if (translated && message.translation.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(message.translation,
                          style:
                              const TextStyle(color: AppColors.textSecondary)),
                    ),
                  if (!message.child)
                    Wrap(
                      spacing: 4,
                      children: <Widget>[
                        if (message.audio != null)
                          TextButton.icon(
                            onPressed: ready ? onReplay : null,
                            icon:
                                const Icon(Icons.volume_up_outlined, size: 18),
                            label: const Text('再听一次'),
                          ),
                        if (message.translation.isNotEmpty)
                          TextButton.icon(
                            onPressed: onTranslation,
                            icon: const Icon(Icons.translate, size: 18),
                            label: Text(translated ? '收起翻译' : '翻译'),
                          ),
                      ],
                    ),
                ],
              ),
            )),
          ],
        ),
      );
}

class _Goals extends StatelessWidget {
  const _Goals(
      {required this.objectives, required this.completed, required this.label});
  final List<String> objectives;
  final int completed;
  final String label;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE0E5F0)),
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(children: <Widget>[
                const Text('本次小目标',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                const Spacer(),
                Text('$completed/${objectives.length}',
                    style: const TextStyle(
                        color: AppColors.primary, fontWeight: FontWeight.w800)),
              ]),
              if (label.isNotEmpty)
                Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(label,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 12))),
              const SizedBox(height: 6),
              ...List<Widget>.generate(
                objectives.length,
                (int index) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(children: <Widget>[
                    Icon(
                        index < completed
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: index < completed
                            ? AppColors.success
                            : AppColors.outline,
                        size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                        child: Text(objectives[index],
                            style: const TextStyle(fontSize: 13))),
                  ]),
                ),
              ),
            ]),
      );
}
