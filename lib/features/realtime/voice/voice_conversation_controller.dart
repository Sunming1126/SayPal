import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'conversation_context.dart';
import 'buffered_pcm_recorder.dart';
import 'voice_transport.dart';

enum VoicePhase { offline, connecting, ready, recording, waiting, playing }

enum VoiceConnectionStage { idle, bootstrap, joining, starting, ready }

enum VoiceCapturePhase { idle, recording, paused, submitting }

enum PendingTurnKind { none, text, voice }

const Object _keepAliveUnchanged = Object();
const Object _thinkingStartedAtUnchanged = Object();

class VoiceMessage {
  const VoiceMessage({
    required this.id,
    required this.text,
    required this.child,
    this.translation = '',
    this.correction = '',
    this.audio,
  });

  final String id;
  final String text;
  final String translation;
  final String correction;
  final bool child;
  final Uint8List? audio;

  VoiceMessage copy({
    String? text,
    String? translation,
    String? correction,
    Uint8List? audio,
  }) => VoiceMessage(
    id: id,
    text: text ?? this.text,
    child: child,
    translation: translation ?? this.translation,
    correction: correction ?? this.correction,
    audio: audio ?? this.audio,
  );
}

class VoiceChatState {
  const VoiceChatState({
    this.phase = VoicePhase.offline,
    this.messages = const <VoiceMessage>[],
    this.continuous = false,
    this.partial = '',
    this.error = '',
    this.notice = '',
    this.spokenTurns = 0,
    this.progressLabel = '',
    this.completedObjectives = 0,
    this.isAwaitingFirstReply = false,
    this.isMuted = false,
    this.isTabVisible = true,
    this.isMicrophonePublishing = false,
    this.connectionStage = VoiceConnectionStage.idle,
    this.isReconnecting = false,
    this.keepAliveDeadline,
    this.connectionAttempt = 0,
    this.capturePhase = VoiceCapturePhase.idle,
    this.pendingTurnId = '',
    this.pendingTurnKind = PendingTurnKind.none,
    this.botReady = false,
    this.thinkingStartedAt,
  });

  final VoicePhase phase;
  final List<VoiceMessage> messages;
  final bool continuous;
  final String partial;
  final String error;
  final String notice;
  final int spokenTurns;
  final String progressLabel;
  final int completedObjectives;
  final bool isAwaitingFirstReply;

  /// Mutes AI audio playback only: recording, recognition and text replies
  /// keep working, audio is still stored on messages but never auto-played.
  final bool isMuted;
  final bool isTabVisible;
  final bool isMicrophonePublishing;
  final VoiceConnectionStage connectionStage;
  final bool isReconnecting;
  final DateTime? keepAliveDeadline;
  final int connectionAttempt;
  final VoiceCapturePhase capturePhase;
  final String pendingTurnId;
  final PendingTurnKind pendingTurnKind;
  final bool botReady;
  final DateTime? thinkingStartedAt;

  bool get canStartTurn => capturePhase == VoiceCapturePhase.idle &&
      !isAwaitingFirstReply &&
      phase != VoicePhase.waiting &&
      phase != VoicePhase.playing;

  VoiceChatState copy({
    VoicePhase? phase,
    List<VoiceMessage>? messages,
    bool? continuous,
    String? partial,
    String? error,
    String? notice,
    int? spokenTurns,
    String? progressLabel,
    int? completedObjectives,
    bool? isAwaitingFirstReply,
    bool? isMuted,
    bool? isTabVisible,
    bool? isMicrophonePublishing,
    VoiceConnectionStage? connectionStage,
    bool? isReconnecting,
    Object? keepAliveDeadline = _keepAliveUnchanged,
    int? connectionAttempt,
    VoiceCapturePhase? capturePhase,
    String? pendingTurnId,
    PendingTurnKind? pendingTurnKind,
    bool? botReady,
    Object? thinkingStartedAt = _thinkingStartedAtUnchanged,
  }) => VoiceChatState(
    phase: phase ?? this.phase,
    messages: messages ?? this.messages,
    continuous: continuous ?? this.continuous,
    partial: partial ?? this.partial,
    error: error ?? this.error,
    notice: notice ?? this.notice,
    spokenTurns: spokenTurns ?? this.spokenTurns,
    progressLabel: progressLabel ?? this.progressLabel,
    completedObjectives: completedObjectives ?? this.completedObjectives,
    isAwaitingFirstReply: isAwaitingFirstReply ?? this.isAwaitingFirstReply,
    isMuted: isMuted ?? this.isMuted,
    isTabVisible: isTabVisible ?? this.isTabVisible,
    isMicrophonePublishing:
        isMicrophonePublishing ?? this.isMicrophonePublishing,
    connectionStage: connectionStage ?? this.connectionStage,
    isReconnecting: isReconnecting ?? this.isReconnecting,
    keepAliveDeadline: identical(keepAliveDeadline, _keepAliveUnchanged)
        ? this.keepAliveDeadline
        : keepAliveDeadline as DateTime?,
    connectionAttempt: connectionAttempt ?? this.connectionAttempt,
    capturePhase: capturePhase ?? this.capturePhase,
    pendingTurnId: pendingTurnId ?? this.pendingTurnId,
    pendingTurnKind: pendingTurnKind ?? this.pendingTurnKind,
    botReady: botReady ?? this.botReady,
    thinkingStartedAt: identical(thinkingStartedAt, _thinkingStartedAtUnchanged)
        ? this.thinkingStartedAt
        : thinkingStartedAt as DateTime?,
  );
}

typedef VoicePracticeSink =
    Future<void> Function(ConversationContext context, int seconds, int turns);

/// Feature-neutral voice workflow. The transport owns microphone/socket/playback;
/// screens only render state and declare their constrained [ConversationContext].
class VoiceConversationController extends StateNotifier<VoiceChatState> {
  VoiceConversationController(
    this.factory, {
    this.context = const ConversationContext.freeChat(),
    this.savePractice,
    PcmRecorderFactory? recorderFactory,
    this.idleTimeout = const Duration(seconds: 45),
  }) : _recorderFactory = recorderFactory ?? BufferedPcmRecorder.new,
       super(const VoiceChatState());

  final VoiceTransport Function() factory;
  final ConversationContext context;
  final VoicePracticeSink? savePractice;
  final Duration idleTimeout;
  final PcmRecorderFactory _recorderFactory;
  final _practiceClock = Stopwatch();
  final List<Uint8List> _audioQueue = <Uint8List>[];
  VoiceTransport? _transport;
  StreamSubscription<Map<String, dynamic>>? _subscription;
  Timer? _deadline;
  Timer? _idleReleaseTimer;
  Future<void>? _connectFuture;
  PcmRecorder? _recorder;
  Future<Object?>? _voiceUploadFuture;
  int _captureGeneration = 0;
  int _epoch = 0;

  /// Playback-only generation: bumped by [toggleMute] to abandon the audio
  /// drain loop without killing the live session (which is what bumping
  /// [_epoch] would do — it detaches the socket event listener).
  int _playbackGen = 0;
  int _spokenTurns = 0;
  bool _voiceTurnPending = false;
  bool _serverDone = false;
  bool _playing = false;
  bool _hasAudio = false;

  void _watchdog(int seconds) {
    _cancelIdleRelease();
    _deadline?.cancel();
    final int epoch = _epoch;
    _deadline = Timer(Duration(seconds: seconds), () {
      if (!mounted || epoch != _epoch) return;
      _error(const VoiceFailure('服务响应超时，请重新连接。'));
      unawaited(pause());
    });
  }

  Future<void> connect() {
    if (_transport != null && state.botReady) {
      return _connectFuture ?? Future<void>.value();
    }
    if (_connectFuture != null) return _connectFuture!;
    return _connectFuture ??= _connectWithRetries().whenComplete(() {
      _connectFuture = null;
    });
  }

  /// Starts the billable connection only after the child expresses input
  /// intent. It is deliberately silent in the UI.
  void warmUp() {
    if (!mounted || !state.isTabVisible || state.botReady) return;
    unawaited(connect());
  }

  Future<void> _connectWithRetries() async {
    final int epoch = ++_epoch;
    const delays = <Duration>[
      Duration.zero,
      Duration(milliseconds: 800),
      Duration(seconds: 2),
    ];
    Object? lastError;
    for (var attempt = 0; attempt < delays.length; attempt++) {
      if (!mounted || epoch != _epoch) return;
      if (delays[attempt] != Duration.zero) {
        await Future<void>.delayed(delays[attempt]);
      }
      if (!mounted || epoch != _epoch) return;
      state = state.copy(
        phase:
            state.capturePhase == VoiceCapturePhase.recording ||
                state.capturePhase == VoiceCapturePhase.paused
            ? VoicePhase.recording
            : state.isAwaitingFirstReply
            ? VoicePhase.waiting
            : VoicePhase.connecting,
        error: '',
        notice: '',
        botReady: false,
        connectionStage: VoiceConnectionStage.bootstrap,
        isReconnecting: attempt > 0,
        connectionAttempt: attempt + 1,
      );
      final VoiceTransport transport = factory();
      _transport = transport;
      final subscription = transport.events.listen((event) {
        if (mounted && epoch == _epoch) unawaited(_event(event, epoch));
      });
      _subscription = subscription;
      try {
        await transport.connect(context: context);
        if (!mounted || epoch != _epoch) {
          await transport.close();
          return;
        }
        await transport.setSessionActive(state.isTabVisible);
        return;
      } catch (error) {
        lastError = error;
        await subscription.cancel();
        if (identical(_subscription, subscription)) _subscription = null;
        try {
          await transport.close();
        } catch (_) {}
        if (identical(_transport, transport)) _transport = null;
        final retryable = error is! VoiceFailure || error.retryable;
        if (!retryable || attempt == delays.length - 1) break;
      }
    }
    if (!mounted || epoch != _epoch) return;
    state = state.copy(
      phase: VoicePhase.offline,
      connectionStage: VoiceConnectionStage.idle,
      isReconnecting: false,
      error: lastError is VoiceFailure
          ? lastError.message
          : '小蓝暂时没准备好，请稍后再试一次。',
      isAwaitingFirstReply: false,
      capturePhase: VoiceCapturePhase.idle,
      pendingTurnId: '',
      pendingTurnKind: PendingTurnKind.none,
      thinkingStartedAt: null,
    );
    await _discardLocalRecording();
  }

  void _error(Object error) {
    if (!mounted) return;
    state = state.copy(
      error: error is VoiceFailure ? error.message : '连接或音频操作失败，请重试。',
      continuous: false,
      isAwaitingFirstReply: false,
      pendingTurnId: '',
      pendingTurnKind: PendingTurnKind.none,
      thinkingStartedAt: null,
    );
  }

  Future<void> _event(Map<String, dynamic> event, int epoch) async {
    try {
      switch (event['type']) {
        case 'connection_stage':
          state = state.copy(
            connectionStage: switch (event['stage']) {
              'join' => VoiceConnectionStage.joining,
              'rtc-start' => VoiceConnectionStage.starting,
              _ => VoiceConnectionStage.bootstrap,
            },
          );
        case 'ready':
          _deadline?.cancel();
          state = state.copy(
            phase:
                state.capturePhase == VoiceCapturePhase.recording ||
                    state.capturePhase == VoiceCapturePhase.paused
                ? VoicePhase.recording
                : state.isAwaitingFirstReply
                ? VoicePhase.waiting
                : VoicePhase.ready,
            connectionStage: VoiceConnectionStage.ready,
            isReconnecting: false,
            botReady: true,
          );
          if (context.needsConfiguration) {
            unawaited(
              _transport?.send(<String, dynamic>{
                    'type': 'configure',
                    'context': context.toJson(),
                  }) ??
                  Future<void>.value(),
            );
          }
          _scheduleIdleRelease();
        case 'configured':
          state = state.copy(
            progressLabel: event['label'] as String? ?? '已准备好',
          );
        case 'tutor_progress':
        case 'practice_progress':
          state = state.copy(
            progressLabel: event['label'] as String? ?? '继续加油',
            completedObjectives:
                event['completed'] as int? ?? state.completedObjectives,
          );
        case 'partial':
          state = state.copy(partial: event['text'] as String? ?? '');
        case 'no_speech':
          _deadline?.cancel();
          _voiceTurnPending = false;
          state = state.copy(
            phase: VoicePhase.ready,
            partial: '',
            error: '',
            notice: '没有听清，可以再说一次。',
            isAwaitingFirstReply: false,
            isMicrophonePublishing: false,
            capturePhase: VoiceCapturePhase.idle,
            pendingTurnId: '',
            pendingTurnKind: PendingTurnKind.none,
            thinkingStartedAt: null,
          );
          _scheduleIdleRelease();
        case 'reconnecting':
          await _transport?.cancelRecording();
          _voiceTurnPending = false;
          state = state.copy(
            phase: VoicePhase.connecting,
            partial: '',
            isAwaitingFirstReply: false,
            isMicrophonePublishing: false,
            isReconnecting: true,
            botReady: false,
          );
        case 'reconnected':
          state = state.copy(
            phase: VoicePhase.ready,
            error: '',
            notice: '',
            isReconnecting: false,
            connectionStage: VoiceConnectionStage.ready,
            botReady: true,
          );
        case 'transcript':
          _cancelIdleRelease();
          if (_voiceTurnPending) {
            _spokenTurns++;
            _voiceTurnPending = false;
            state = state.copy(spokenTurns: _spokenTurns);
          }
          final String transcript = event['text'] as String;
          final bool alreadyShown = state.messages.any(
            (VoiceMessage message) =>
                message.child &&
                message.text == transcript &&
                message.id == state.pendingTurnId,
          );
          if (!alreadyShown) {
            _append(
              VoiceMessage(
                id: event['id'] as String,
                text: transcript,
                child: true,
              ),
            );
          }
          state = state.copy(partial: '');
        case 'reply':
          _cancelIdleRelease();
          state = state.copy(
            isAwaitingFirstReply: false,
            pendingTurnId: '',
            pendingTurnKind: PendingTurnKind.none,
            thinkingStartedAt: null,
          );
          state = state.copy(
            messages: <VoiceMessage>[
              for (final VoiceMessage message in state.messages)
                message.id == event['userId']
                    ? message.copy(
                        correction: event['correction'] as String? ?? '',
                      )
                    : message,
            ],
          );
          _append(
            VoiceMessage(
              id: event['id'] as String,
              text: event['reply'] as String,
              translation: event['translation'] as String? ?? '',
              child: false,
            ),
          );
        case 'reply_segment':
          _cancelIdleRelease();
          state = state.copy(
            isAwaitingFirstReply: false,
            pendingTurnId: '',
            pendingTurnKind: PendingTurnKind.none,
            thinkingStartedAt: null,
          );
          _append(
            VoiceMessage(
              id: event['id'] as String,
              text: event['text'] as String,
              child: false,
            ),
          );
        case 'reply_meta':
          final Map<String, String> translations = <String, String>{};
          if (event['items'] is List) {
            for (final Object? item in event['items'] as List<Object?>) {
              if (item is Map && item['id'] is String) {
                translations[item['id'] as String] =
                    item['translation'] as String? ?? '';
              }
            }
          }
          state = state.copy(
            messages: <VoiceMessage>[
              for (final VoiceMessage message in state.messages)
                translations.containsKey(message.id)
                    ? message.copy(translation: translations[message.id])
                    : message.id == event['userId']
                    ? message.copy(
                        correction: event['correction'] as String? ?? '',
                      )
                    : message,
            ],
          );
        case 'reply_translation':
          final String id = event['id'] as String? ?? '';
          final String translation = event['translation'] as String? ?? '';
          state = state.copy(
            messages: <VoiceMessage>[
              for (final VoiceMessage message in state.messages)
                message.id == id
                    ? message.copy(translation: translation)
                    : message,
            ],
          );
        case 'translation_error':
          state = state.copy(notice: '翻译暂时没有准备好，请稍后再试。');
        case 'audio':
          _cancelIdleRelease();
          final Uint8List bytes = base64Decode(event['data'] as String);
          _hasAudio = true;
          state = state.copy(
            messages: <VoiceMessage>[
              for (final VoiceMessage message in state.messages)
                if (message.id == event['id'])
                  message.copy(audio: bytes)
                else
                  message,
            ],
          );
          _enqueueAudio(bytes, epoch);
        case 'done':
          _deadline?.cancel();
          _serverDone = true;
          state = state.copy(
            isAwaitingFirstReply: false,
            pendingTurnId: '',
            pendingTurnKind: PendingTurnKind.none,
            thinkingStartedAt: null,
          );
          await _next(epoch);
        case 'error':
          final message = event['message'] as String? ?? '服务暂不可用。';
          if (message.contains('播放生成失败')) {
            state = state.copy(notice: '有一段语音暂时不能播放，可以继续对话。');
            break;
          }
          state = state.copy(
            error: message,
            continuous: false,
            isAwaitingFirstReply: false,
            pendingTurnId: '',
            pendingTurnKind: PendingTurnKind.none,
            thinkingStartedAt: null,
          );
        case 'disconnected':
          final String message = state.error.isEmpty
              ? '连接已结束，重连后会开启新的练习。'
              : state.error;
          await pause();
          if (!mounted || _epoch != epoch + 1) return;
          state = state.copy(
            error: message,
            notice: '',
            isAwaitingFirstReply: false,
            isReconnecting: false,
          );
      }
    } catch (error) {
      if (mounted && epoch == _epoch) _error(error);
    }
  }

  void _append(VoiceMessage message) {
    final List<VoiceMessage> messages = <VoiceMessage>[
      ...state.messages,
      message,
    ];
    state = state.copy(
      messages: List<VoiceMessage>.unmodifiable(
        messages.length > 40
            ? messages.sublist(messages.length - 40)
            : messages,
      ),
    );
  }

  Future<void> startRecording({bool continuous = false}) async {
    if (!state.canStartTurn || _recorder != null) return;
    _cancelIdleRelease();
    _serverDone = false;
    _hasAudio = false;
    _voiceTurnPending = true;
    _practiceClock.start();
    final PcmRecorder recorder = _recorderFactory();
    _recorder = recorder;
    final int captureGeneration = ++_captureGeneration;
    warmUp();
    final int epoch = _epoch;
    try {
      await recorder.start(
        onLimit: () {
          if (mounted && epoch == _epoch) {
            unawaited(_stopAtRecordingLimit(epoch));
          }
        },
      );
    } catch (error) {
      await recorder.dispose();
      if (identical(_recorder, recorder)) _recorder = null;
      _error(error);
      return;
    }
    if (!mounted || epoch != _epoch || captureGeneration != _captureGeneration) {
      await recorder.dispose();
      return;
    }
    _voiceUploadFuture = _uploadRecordingWhenReady(recorder.frames, epoch, captureGeneration);
    state = state.copy(
      phase: VoicePhase.recording,
      continuous: continuous,
      partial: '',
      error: '',
      notice: '',
      isMicrophonePublishing: true,
      capturePhase: VoiceCapturePhase.recording,
    );
  }

  Future<Object?> _uploadRecordingWhenReady(
    Stream<Uint8List> frames, int epoch, int generation,
  ) async {
    try {
      await connect();
      final transport = _transport;
      if (!mounted || epoch != _epoch || generation != _captureGeneration ||
          transport == null || !state.botReady) {
        return const VoiceFailure('语音连接未准备好，请重试。');
      }
      await transport.uploadBufferedAudio(frames);
      return null;
    } catch (error) {
      return error;
    }
  }

  Future<void> endRecording() async {
    if (state.capturePhase != VoiceCapturePhase.recording &&
        state.capturePhase != VoiceCapturePhase.paused) {
      return;
    }
    final int epoch = _epoch;
    final upload = _voiceUploadFuture;
    try {
      await _recorder?.stop();
      await _recorder?.dispose();
      if (!mounted || epoch != _epoch) return;
      _recorder = null;
    } catch (error) {
      if (mounted && epoch == _epoch) {
        await pause();
        if (mounted && _epoch == epoch + 1) _error(error);
      }
      return;
    }
    final String turnId = 'voice-${DateTime.now().microsecondsSinceEpoch}';
    state = state.copy(
      phase: VoicePhase.waiting,
      isAwaitingFirstReply: true,
      isMicrophonePublishing: false,
      capturePhase: VoiceCapturePhase.submitting,
      pendingTurnId: turnId,
      pendingTurnKind: PendingTurnKind.voice,
      thinkingStartedAt: DateTime.now(),
    );
    try {
      final uploadError = await upload;
      if (!mounted || epoch != _epoch || state.pendingTurnId != turnId) return;
      _voiceUploadFuture = null;
      if (uploadError != null) throw uploadError;
      final transport = _transport;
      if (transport == null || !state.botReady) {
        throw const VoiceFailure('语音连接未准备好，请重试。');
      }
      _watchdog(90);
      await transport.commitBufferedAudio();
      if (mounted && epoch == _epoch) {
        state = state.copy(capturePhase: VoiceCapturePhase.idle);
      }
    } catch (error) {
      if (mounted && epoch == _epoch) {
        await pause();
        _error(error);
      }
    }
  }

  Future<void> _stopAtRecordingLimit(int epoch) async {
    if (!mounted || epoch != _epoch || state.phase != VoicePhase.recording) {
      return;
    }
    try {
      await _recorder?.stop();
    } catch (error) {
      if (mounted && epoch == _epoch) {
        await pause();
        if (mounted && _epoch == epoch + 1) _error(error);
      }
      return;
    }
    if (!mounted || epoch != _epoch) return;
    state = state.copy(
      isMicrophonePublishing: false,
      capturePhase: VoiceCapturePhase.paused,
      error: '',
      notice: '已暂停收音，点击发送刚才说的内容。',
    );
  }

  Future<void> sendText(String text) async {
    final String value = text.trim();
    if (value.isEmpty || !state.canStartTurn) return;
    _cancelIdleRelease();
    _serverDone = false;
    _hasAudio = false;
    _practiceClock.start();
    _spokenTurns++;
    final String turnId = 'typed-${DateTime.now().microsecondsSinceEpoch}';
    _append(VoiceMessage(id: turnId, text: value, child: true));
    state = state.copy(
      phase: VoicePhase.waiting,
      error: '',
      notice: '',
      continuous: false,
      spokenTurns: _spokenTurns,
      isAwaitingFirstReply: true,
      pendingTurnId: turnId,
      pendingTurnKind: PendingTurnKind.text,
      thinkingStartedAt: DateTime.now(),
    );
    try {
      await connect();
      // A failed preflight or a cancelled turn clears the pending ID. Keep
      // that state instead of masking the connection error with a send error.
      if (!mounted || state.pendingTurnId != turnId) return;
      final transport = _transport;
      if (transport == null || !state.botReady) {
        throw const VoiceFailure('小蓝暂时没准备好，请稍后再试一次。');
      }
      _watchdog(90);
      await transport.send(<String, dynamic>{'type': 'text', 'text': value});
    } catch (error) {
      if (!mounted || state.pendingTurnId != turnId) return;
      _deadline?.cancel();
      state = state.copy(phase: VoicePhase.ready, isAwaitingFirstReply: false);
      _error(error);
    }
  }

  void requestTranslation(VoiceMessage message) {
    if (message.child || message.translation.isNotEmpty) return;
    unawaited(_requestTranslation(message));
  }

  Future<void> _requestTranslation(VoiceMessage message) async {
    try {
      await connect();
      if (!mounted || !state.messages.any((item) => item.id == message.id)) return;
      final transport = _transport;
      if (transport == null || !state.botReady) {
        throw const VoiceFailure('翻译连接尚未就绪。');
      }
      await transport.send({
        'type': 'translate',
        'id': message.id,
        'text': message.text,
      });
    } catch (_) {
      if (mounted) state = state.copy(notice: '翻译暂时没有准备好，请稍后再试。');
    }
  }

  Future<void> cancelPendingTurn() async {
    if (!state.isAwaitingFirstReply) return;
    _deadline?.cancel();
    try {
      await _transport?.cancelPendingTurn();
    } catch (_) {}
    if (!mounted) return;
    state = state.copy(
      phase: state.botReady ? VoicePhase.ready : VoicePhase.connecting,
      isAwaitingFirstReply: false,
      capturePhase: VoiceCapturePhase.idle,
      pendingTurnId: '',
      pendingTurnKind: PendingTurnKind.none,
      thinkingStartedAt: null,
      notice: '已取消等待，可以重新输入。',
    );
    if (state.botReady) _scheduleIdleRelease();
  }

  void _enqueueAudio(Uint8List bytes, int epoch) {
    if (state.isMuted) return; // audio is already stored on the message
    _audioQueue.add(bytes);
    if (_playing) return;
    _playing = true;
    state = state.copy(phase: VoicePhase.playing);
    unawaited(_drainAudioQueue(epoch, _playbackGen));
  }

  Future<void> _drainAudioQueue(int epoch, int gen) async {
    while (mounted &&
        epoch == _epoch &&
        gen == _playbackGen &&
        _audioQueue.isNotEmpty) {
      final Uint8List bytes = _audioQueue.removeAt(0);
      try {
        await _transport!.play(bytes);
      } catch (error) {
        if (mounted && epoch == _epoch && gen == _playbackGen) {
          state = state.copy(notice: '音频播放失败，可以稍后重播或继续对话。');
        }
      }
    }
    // A stale drain (paused or muted mid-playback) must not touch the phase;
    // whoever invalidated it owns the transition.
    if (!mounted || epoch != _epoch || gen != _playbackGen) return;
    _playing = false;
    await _next(epoch);
  }

  Future<void> _next(int epoch) async {
    if (!mounted || epoch != _epoch || !_serverDone || _playing) return;
    state = state.copy(phase: VoicePhase.ready);
    // Note: mute never mutes the microphone; if continuous mode is ever
    // re-exposed in the UI, mute+continuous would keep recording silently.
    if (state.continuous && _hasAudio && state.error.isEmpty) {
      await startRecording(continuous: true);
    } else {
      _scheduleIdleRelease();
    }
  }

  Future<void> replay(VoiceMessage message) async {
    if (state.isMuted) return;
    if (state.phase != VoicePhase.ready || message.audio == null) return;
    _cancelIdleRelease();
    state = state.copy(continuous: false);
    _serverDone = true;
    _enqueueAudio(message.audio!, _epoch);
  }

  Future<void> playAudio(Uint8List audio) async {
    if (state.isMuted || state.phase != VoicePhase.ready || audio.isEmpty) {
      return;
    }
    _cancelIdleRelease();
    state = state.copy(continuous: false);
    _serverDone = true;
    _enqueueAudio(audio, _epoch);
  }

  /// Starts a fresh local conversation while optionally restoring text history.
  /// A billable remote room is opened only by the next voice/text action.
  /// Restored messages intentionally contain no audio bytes.
  Future<void> startConversation({
    List<VoiceMessage> messages = const <VoiceMessage>[],
  }) async {
    final bool muted = state.isMuted;
    final bool visible = state.isTabVisible;
    await pause();
    if (!mounted) return;
    state = VoiceChatState(
      messages: List<VoiceMessage>.unmodifiable(messages),
      isMuted: muted,
      isTabVisible: visible,
    );
  }

  /// Mutes AI audio playback. Recording, recognition and text replies are
  /// unaffected; audio already received stays attached to its message.
  /// Skipped audio is never back-filled after unmuting.
  Future<void> toggleMute() async {
    if (!mounted) return;
    final bool muted = !state.isMuted;
    state = state.copy(isMuted: muted);
    try {
      await _transport?.setPlaybackMuted(muted);
    } catch (_) {}
    if (!muted) return;
    _playbackGen++;
    _audioQueue.clear();
    if (_playing) {
      _playing = false;
      try {
        await _transport?.stopPlayback();
      } catch (_) {}
    }
    if (mounted && state.phase == VoicePhase.playing) {
      state = state.copy(
        phase: _serverDone ? VoicePhase.ready : VoicePhase.waiting,
      );
    }
  }

  /// Hides the free-chat tab and releases its RTC room immediately.
  /// [grace] remains source-compatible with older callers but is ignored.
  Future<void> deactivate({Duration grace = Duration.zero}) async {
    if (!mounted || !state.isTabVisible) return;
    state = state.copy(
      isTabVisible: false,
      keepAliveDeadline: null,
      isMicrophonePublishing: false,
    );
    await pause();
  }

  /// Shows the free-chat tab without entering a billable RTC room.
  Future<void> activate() async {
    if (!mounted) return;
    state = state.copy(isTabVisible: true, keepAliveDeadline: null);
  }

  void _cancelIdleRelease() {
    _idleReleaseTimer?.cancel();
    _idleReleaseTimer = null;
  }

  void _scheduleIdleRelease() {
    _cancelIdleRelease();
    if (!mounted ||
        !state.isTabVisible ||
        _transport == null ||
        state.phase != VoicePhase.ready) {
      return;
    }
    _idleReleaseTimer = Timer(idleTimeout, () {
      if (mounted && state.phase == VoicePhase.ready) unawaited(pause());
    });
  }

  Future<void> pause() async {
    _deadline?.cancel();
    _cancelIdleRelease();
    final bool wasRecording = state.capturePhase != VoiceCapturePhase.idle;
    final bool hadPendingTurn = state.isAwaitingFirstReply;
    _epoch++;
    final VoiceTransport? transport = _transport;
    _transport = null;
    final StreamSubscription<Map<String, dynamic>>? subscription =
        _subscription;
    _subscription = null;
    _playing = false;
    _audioQueue.clear();
    _practiceClock.stop();
    final int seconds = _practiceClock.elapsed.inSeconds;
    final int turns = _spokenTurns;
    _practiceClock.reset();
    _spokenTurns = 0;
    _voiceTurnPending = false;
    await _discardLocalRecording();
    if (mounted) {
      state = state.copy(
        phase: VoicePhase.offline,
        continuous: false,
        partial: '',
        isAwaitingFirstReply: false,
        isMicrophonePublishing: false,
        connectionStage: VoiceConnectionStage.idle,
        isReconnecting: false,
        botReady: false,
        capturePhase: VoiceCapturePhase.idle,
        pendingTurnId: '',
        pendingTurnKind: PendingTurnKind.none,
        thinkingStartedAt: null,
        keepAliveDeadline: null,
      );
    }
    await subscription?.cancel();
    if (wasRecording) {
      try {
        await transport?.cancelRecording();
      } catch (_) {}
    }
    if (hadPendingTurn || wasRecording) {
      try {
        await transport?.cancelPendingTurn();
      } catch (_) {}
    }
    try {
      await transport?.close();
    } catch (_) {}
    if (turns > 0 && savePractice != null) {
      try {
        await savePractice!(context, seconds, turns);
      } catch (_) {
        if (mounted) state = state.copy(error: '本次练习记录保存失败。');
      }
    }
  }

  Future<void> _discardLocalRecording() async {
    final recorder = _recorder;
    _recorder = null;
    _captureGeneration++;
    _voiceUploadFuture = null;
    if (recorder == null) return;
    try {
      await recorder.dispose();
    } catch (_) {}
  }

  @override
  void dispose() {
    _cancelIdleRelease();
    unawaited(pause());
    super.dispose();
  }
}
