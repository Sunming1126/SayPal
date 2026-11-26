import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:record/record.dart';
import 'package:volc_engine_rtc/volc_engine_rtc.dart';
import 'package:volc_engine_rtc/codegen/pack/keytype.dart' as rtc_types;

import '../../../core/config/service_endpoint.dart';
import 'conversation_context.dart';
import 'voice_transport.dart';
import 'volc_external_audio.dart';
import 'websocket_voice_transport.dart';

class RtcSessionCredentials {
  const RtcSessionCredentials({
    required this.sessionId,
    required this.appId,
    required this.roomId,
    required this.userId,
    required this.botUserId,
    required this.token,
  });

  final String sessionId;
  final String appId;
  final String roomId;
  final String userId;
  final String botUserId;
  final String token;

  factory RtcSessionCredentials.fromJson(Map<String, dynamic> json) {
    String field(String name) =>
        json[name] is String ? json[name] as String : '';
    final result = RtcSessionCredentials(
      sessionId: field('sessionId'),
      appId: field('appId'),
      roomId: field('roomId'),
      userId: field('userId'),
      botUserId: field('botUserId'),
      token: field('token'),
    );
    if ([
      result.sessionId,
      result.appId,
      result.roomId,
      result.userId,
      result.botUserId,
      result.token,
    ].any((value) => value.isEmpty)) {
      throw const FormatException('Incomplete RTC bootstrap response');
    }
    return result;
  }
}

class RtcSubtitleItem {
  const RtcSubtitleItem({
    required this.userId,
    required this.text,
    required this.roundId,
    required this.sequence,
    required this.definite,
    required this.paragraph,
  });

  final String userId;
  final String text;
  final int roundId;
  final int sequence;
  final bool definite;
  final bool paragraph;
}

List<RtcSubtitleItem> decodeRtcSubtitle(Uint8List bytes) {
  try {
    Uint8List payload = bytes;
    final magic = bytes.length >= 4
        ? ascii.decode(bytes.sublist(0, 4), allowInvalid: true)
        : '';
    if (bytes.length >= 8 && (magic == 'subv' || magic == 'conv')) {
      final expected = ByteData.sublistView(bytes, 4, 8).getUint32(0);
      if (expected != bytes.length - 8) return const [];
      payload = Uint8List.sublistView(bytes, 8);
    } else if (bytes.length >= 2 && bytes[0] == 0x1f && bytes[1] == 0x8b) {
      payload = Uint8List.fromList(gzip.decode(bytes));
    }
    final decoded = jsonDecode(utf8.decode(payload));
    if (decoded is! Map || decoded['type'] != 'subtitle') return const [];
    final data = decoded['data'];
    if (data is! List) return const [];
    return <RtcSubtitleItem>[
      for (final raw in data)
        if (raw is Map &&
            raw['text'] is String &&
            (raw['text'] as String).trim().isNotEmpty)
          RtcSubtitleItem(
            userId: raw['userId'] is String ? raw['userId'] as String : '',
            text: (raw['text'] as String).trim(),
            roundId:
                raw['roundId'] is num ? (raw['roundId'] as num).toInt() : -1,
            sequence:
                raw['sequence'] is num ? (raw['sequence'] as num).toInt() : -1,
            definite: raw['definite'] == true,
            paragraph: raw['paragraph'] == true,
          ),
    ];
  } catch (_) {
    return const [];
  }
}

/// Encodes the documented RTC conversational-AI control envelope used by the
/// official Volcengine demo: 4-byte type + big-endian length + UTF-8 JSON.
Uint8List encodeRtcControl({
  required String command,
  String? message,
  int interruptMode = 1,
}) {
  final value = utf8.encode(jsonEncode({
    'Command': command,
    'InterruptMode': interruptMode,
    if (message != null) 'Message': message,
  }));
  final length = ByteData(4)..setUint32(0, value.length, Endian.big);
  return Uint8List.fromList(<int>[
    ...ascii.encode('ctrl'),
    ...length.buffer.asUint8List(),
    ...value,
  ]);
}

abstract interface class RtcAudioBridge {
  Stream<Map<String, dynamic>> get events;
  Future<void> join(RtcSessionCredentials credentials);
  Future<void> setPublishing(bool publishing);
  Future<void> startExternalPublishing();
  Future<void> pushPcmFrame(Uint8List pcm);
  Future<void> stopExternalPublishing();
  Future<void> sendControl({required String userId, required Uint8List data});
  Future<void> setRemoteMuted(bool muted);
  Future<void> close();
}

class VolcRtcAudioBridge implements RtcAudioBridge {
  final _events = StreamController<Map<String, dynamic>>.broadcast();
  final _permissionProbe = AudioRecorder();
  final _remoteStreams = <String>{};
  RTCEngine? _engine;
  RTCRoom? _room;
  Completer<void>? _joinCompleter;
  bool _captureStarted = false;
  bool _externalPublishing = false;
  bool _muted = false;
  bool _closed = false;

  @override
  Stream<Map<String, dynamic>> get events => _events.stream;

  @override
  Future<void> join(RtcSessionCredentials credentials) async {
    final engineHandler = IRTCEngineEventHandler();
    engineHandler.onError = (ErrorCode code) {
      if (!_closed && kDebugMode) debugPrint('SayPal RTC SDK error: $code');
    };
    engineHandler.onConnectionStateChanged = (state, _) {
      if (_closed) return;
      final type = switch (state) {
        3 || 5 => 'rtc_reconnecting',
        2 || 4 => 'rtc_reconnected',
        6 => 'rtc_failed',
        _ => null,
      };
      if (type != null) _events.add({'type': type});
    };
    final roomHandler = IRTCRoomEventHandler();
    void markBotReady(String userId) {
      if (!_closed && userId == credentials.botUserId) {
        _events.add({'type': 'bot_ready'});
      }
    }
    roomHandler.onUserJoined = (UserInfo userInfo) {
      markBotReady(userInfo.userId);
    };
    roomHandler.onUserLeave = (userId, _) {
      if (!_closed && userId == credentials.botUserId) {
        _events.add({'type': 'rtc_failed'});
      }
    };
    roomHandler.onRoomStateChangedWithReason = (_, _, state, reason) {
      if (_closed || state != rtc_types.RoomState.left) return;
      if (kDebugMode) debugPrint('SayPal RTC left room: $reason');
      _events.add({'type': 'rtc_failed'});
    };
    roomHandler.onRoomStateChanged = (_, __, state, ___) {
      final pending = _joinCompleter;
      if (pending != null && !pending.isCompleted) {
        if (state == 0) {
          pending.complete();
        } else {
          pending.completeError(const VoiceFailure('小蓝暂时没准备好，请重试。'));
        }
      } else if (state == 0 && !_closed) {
        _events.add({'type': 'rtc_reconnected'});
      }
    };
    roomHandler.onRoomBinaryMessageReceived = (_, __, message) {
      for (final item in decodeRtcSubtitle(message)) {
        if (!_closed) {
          _events.add({
            'type': 'subtitle',
            'userId': item.userId,
            'text': item.text,
            'roundId': item.roundId,
            'sequence': item.sequence,
            'definite': item.definite,
            'paragraph': item.paragraph,
          });
        }
      }
    };
    roomHandler.onUserPublishStreamAudio = (streamId, _, isPublish) {
      if (isPublish) {
        _remoteStreams.add(streamId);
        unawaited(_engine?.setRemoteAudioPlaybackVolume(
          streamId: streamId,
          volume: _muted ? 0 : 100,
        ));
      } else {
        _remoteStreams.remove(streamId);
      }
    };

    _engine = await RTCEngine.createRTCEngine(
      RTCVideoContext(appId: credentials.appId, eventHandler: engineHandler),
    );
    _room = await _engine!.createRTCRoom(credentials.roomId);
    if (_room == null) throw const VoiceFailure('小蓝暂时没准备好，请重试。');
    await _room!.setRTCRoomEventHandler(roomHandler);
    _joinCompleter = Completer<void>();
    final result = await _room!.joinRoom(
      token: credentials.token,
      userInfo: UserInfo(userId: credentials.userId, extraInfo: ''),
      roomConfig: RoomConfig(
        profile: RoomProfile.low_latency,
        streamId: '',
        isPublishAudio: false,
        isPublishVideo: false,
        isAutoSubscribeAudio: true,
        isAutoSubscribeVideo: false,
      ),
      userVisibility: true,
    );
    if (result != null && result < 0) {
      throw const VoiceFailure('小蓝暂时没准备好，请重试。');
    }
    await _joinCompleter!.future.timeout(const Duration(seconds: 12));
  }

  @override
  Future<void> startExternalPublishing() async {
    if (_closed || _room == null || _engine == null) {
      throw const VoiceFailure('连接已断开，请重试。');
    }
    final sourceResult = await _engine!
        .setAudioSourceType(rtc_types.AudioSourceType.AUDIO_SOURCE_TYPE_EXTERNAL);
    if (sourceResult != null && sourceResult < 0) {
      throw const VoiceFailure('麦克风暂时无法使用，请重试。');
    }
    final publishResult = await _room!.publishStreamAudio(true);
    if (publishResult != null && publishResult < 0) {
      throw const VoiceFailure('语音暂时无法发送，请重试。');
    }
    _externalPublishing = true;
  }

  @override
  Future<void> pushPcmFrame(Uint8List pcm) async {
    if (!_externalPublishing || pcm.length != 320) {
      throw const VoiceFailure('语音暂时无法发送，请重试。');
    }
    final result = await pushVolcExternalPcmFrame(pcm);
    if (result != null && result < 0) {
      throw const VoiceFailure('语音暂时无法发送，请重试。');
    }
  }

  @override
  Future<void> stopExternalPublishing() async {
    if (!_externalPublishing) return;
    _externalPublishing = false;
    try {
      await _room?.publishStreamAudio(false);
    } catch (_) {}
  }

  @override
  Future<void> setPublishing(bool publishing) async {
    if (_closed || _room == null || _engine == null) {
      throw const VoiceFailure('连接已断开，请重试。');
    }
    if (publishing) {
      if (!await _permissionProbe.hasPermission()) {
        throw const VoiceFailure('麦克风权限未允许，请在系统设置中开启。');
      }
      if (!_captureStarted) {
        final result = await _engine!.startAudioCapture();
        if (result != null && result < 0) {
          throw const VoiceFailure('麦克风暂时无法使用，请重试。');
        }
        _captureStarted = true;
      }
    }
    final result = await _room!.publishStreamAudio(publishing);
    if (result != null && result < 0) {
      throw const VoiceFailure('麦克风暂时无法使用，请重试。');
    }
  }

  @override
  Future<void> setRemoteMuted(bool muted) async {
    _muted = muted;
    for (final streamId in _remoteStreams) {
      await _engine?.setRemoteAudioPlaybackVolume(
        streamId: streamId,
        volume: muted ? 0 : 100,
      );
    }
  }

  @override
  Future<void> sendControl({
    required String userId,
    required Uint8List data,
  }) async {
    if (_closed || _room == null) {
      throw const VoiceFailure('连接已断开，请重试。');
    }
    final result = await _room!.sendUserBinaryMessage(
      userId: userId,
      buffer: data,
      config: MessageConfig.reliable_ordered,
    );
    if (result != null && result < 0) {
      throw const VoiceFailure('语音暂时无法发送，请重试。');
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    try {
      await _room?.publishStreamAudio(false);
    } catch (_) {}
    try {
      await _engine?.stopAudioCapture();
    } catch (_) {}
    try {
      await _room?.leaveRoom();
    } catch (_) {}
    try {
      _room?.destroy();
    } catch (_) {}
    try {
      _engine?.destroy();
    } catch (_) {}
    try {
      await _permissionProbe.dispose();
    } catch (_) {}
    await _events.close();
  }
}

/// RTC handles streaming microphone audio, AI subtitles and remote playback.
/// The HTTP backend handles session credentials and subtitle translation.
class RtcVoiceTransport implements VoiceTransport {
  RtcVoiceTransport(
    this.baseUrl, {
    this.token = '',
    RtcAudioBridge? bridge,
    http.Client? client,
    this.voiceFinalizeTimeout = const Duration(seconds: 2),
  })  : _bridge = bridge ?? VolcRtcAudioBridge(),
        _messageAudio = WebsocketVoiceTransport(baseUrl),
        _client = client ?? http.Client();

  final String baseUrl;
  final String token;
  final RtcAudioBridge _bridge;
  // Reuse its local MP3 player for saved speech. No socket is opened here.
  final VoiceTransport _messageAudio;
  final http.Client _client;
  final Duration voiceFinalizeTimeout;
  final _events = StreamController<Map<String, dynamic>>.broadcast();
  StreamSubscription<Map<String, dynamic>>? _bridgeSub;
  RtcSessionCredentials? _credentials;
  bool _rtcActive = false;
  bool _closed = false;
  bool _sessionActive = true;
  bool _playbackMuted = false;
  bool _manualTurnOpen = false;
  Future<void> _captureOperations = Future<void>.value();
  Timer? _recordingLimit;
  final _committed = <String>{};
  final _translationJobs = <String, Future<String?>>{};
  final _translations = <String, String>{};
  final Map<String, String> _voiceDraft = <String, String>{};
  ConversationContext _context = const ConversationContext.freeChat();
  int _completedObjectives = 0;
  bool _awaitingReply = false;
  String _latestVoiceText = '';
  Completer<void>? _voiceTextChanged;
  Completer<void>? _botReady;
  Future<void>? _opening;
  Stopwatch? _firstSubtitleClock;
  bool _sawBotSubtitle = false;
  int _turnGeneration = 0;
  String _pendingBufferedText = '';

  /// Internal diagnostics: which RTC stage failed last
  /// (`bootstrap`, `join`, `rtc-start`). Never surfaced to children.
  String? lastFailureStage;

  @override
  Stream<Map<String, dynamic>> get events => _events.stream;

  @override
  Future<void> connect({required ConversationContext context}) async {
    _context = context;
    _bridgeSub = _bridge.events.listen(_onBridgeEvent);
    _botReady = Completer<void>();
    final opening = _opening = _open(context);
    try {
      await opening;
    } catch (_) {
      if (!_closed) await close();
      rethrow;
    } finally {
      _opening = null;
    }
  }

  Future<void> _open(ConversationContext context) async {
    var stage = 'bootstrap';
    try {
      _events.add({'type': 'connection_stage', 'stage': stage});
      _credentials = await _bootstrap(context);
      if (_closed) return;
      stage = 'join';
      _events.add({'type': 'connection_stage', 'stage': stage});
      await _bridge.join(_credentials!);
      if (_closed) return;
      stage = 'rtc-start';
      _events.add({'type': 'connection_stage', 'stage': stage});
      await _post(
        'rtc/session/${_credentials!.sessionId}/start',
        const {},
        timeout: const Duration(seconds: 10),
      );
      if (_closed) return;
      _rtcActive = true;
      stage = 'bot-ready';
      _events.add({'type': 'connection_stage', 'stage': stage});
      await _botReady!.future.timeout(const Duration(seconds: 10));
      if (_closed) return;
      _events.add({'type': 'ready'});
      if (context.needsConfiguration) {
        _events.add({'type': 'configured', 'label': '练习已准备好'});
      }
    } catch (error) {
      lastFailureStage = stage;
      debugPrint('SayPal RTC failed at $stage (${error.runtimeType})');
      _rtcActive = false;
      if (error is VoiceFailure) rethrow;
      if (error is SocketException) {
        throw const VoiceFailure('无法连接语音服务器，请检查网络后重试。');
      }
      if (error is TimeoutException) {
        throw const VoiceFailure('语音连接超时，请重试。');
      }
      throw const VoiceFailure('小蓝暂时没准备好，请稍后再试一次。');
    }
  }

  Future<RtcSessionCredentials> _bootstrap(ConversationContext context) async {
    final payload = context.toJson();
    if (context.kind == ConversationKind.roleplay) {
      // The restored catalog includes scenes the deployed server does not
      // know by ID. Use its existing validation for bounded custom scenes.
      payload['kind'] = ConversationKind.customRoleplay.name;
    }
    final response = await _post(
        'rtc/session/bootstrap',
        {'context': payload},
        timeout: const Duration(seconds: 8));
    return RtcSessionCredentials.fromJson(response);
  }

  Future<Map<String, dynamic>> _post(
    String endpoint,
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 22),
  }) async {
    final uri = resolveServiceEndpoint(baseUrl, endpoint);
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        (uri.scheme == 'http' &&
            !['localhost', '127.0.0.1', '::1'].contains(uri.host))) {
      throw const VoiceFailure('请配置有效的后端地址。', retryable: false);
    }
    final response = await _client
        .post(
          uri,
          headers: {
            HttpHeaders.contentTypeHeader: 'application/json',
            if (token.isNotEmpty)
              HttpHeaders.authorizationHeader: 'Bearer $token',
          },
          body: jsonEncode(body),
        )
        .timeout(timeout);
    final status = response.statusCode;
    if (status < 200 || status >= 300) {
      if (kDebugMode) {
        debugPrint('SayPal RTC: ${uri.path} returned HTTP $status');
      }
      if (status == 401 || status == 403) {
        throw VoiceFailure(
          token.isEmpty ? '语音服务需要访问凭证。' : '语音服务的访问凭证无效或已过期。',
          retryable: false,
        );
      }
      if (status == 503 && endpoint == 'rtc/session/bootstrap') {
        throw const VoiceFailure('语音服务尚未就绪，请稍后重试。');
      }
      throw VoiceFailure(
        '小蓝暂时没准备好，请稍后再试一次。',
        retryable: status >= 500 || status == 408 || status == 429,
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) throw const FormatException();
    return decoded;
  }

  void _onBridgeEvent(Map<String, dynamic> event) {
    if (_closed) return;
    if (event['type'] == 'bot_ready') {
      final pending = _botReady;
      if (pending != null && !pending.isCompleted) pending.complete();
      return;
    }
    if (!_rtcActive) return;
    if (event['type'] == 'rtc_reconnecting') {
      _events.add({'type': 'reconnecting'});
      return;
    }
    if (event['type'] == 'rtc_reconnected') {
      _events.add({'type': 'reconnected'});
      return;
    }
    if (event['type'] == 'rtc_failed') {
      _events.add({'type': 'disconnected'});
      return;
    }
    if (event['type'] != 'subtitle') return;
    final userId = event['userId'] as String? ?? '';
    final text = event['text'] as String? ?? '';
    final definite = event['definite'] == true;
    final paragraph = event['paragraph'] == true;
    final round = event['roundId'] as int? ?? -1;
    final sequence = event['sequence'] as int? ?? -1;
    final key = '$userId:$round:$sequence:$text';
    if (userId == _credentials?.userId) {
      if (!_manualTurnOpen) return;
      _latestVoiceText = text;
      if (definite && paragraph && text.trim().isNotEmpty) {
        _voiceDraft['$round:$sequence'] = text.trim();
      }
      _events.add({'type': 'partial', 'text': _draftText});
      final changed = _voiceTextChanged;
      if (changed != null && !changed.isCompleted) changed.complete();
      return;
    }
    if (userId != _credentials?.botUserId || _manualTurnOpen || !_awaitingReply) {
      return;
    }
    final clock = _firstSubtitleClock;
    if (clock != null && !_sawBotSubtitle && text.isNotEmpty) {
      _sawBotSubtitle = true;
      debugPrint('SayPal RTC reply: first_subtitle +${clock.elapsedMilliseconds}ms');
    }
    if (!definite) return;
    if (text.isNotEmpty && _committed.add(key)) {
      if (clock != null) {
        debugPrint('SayPal RTC reply: first_definite +${clock.elapsedMilliseconds}ms');
        _firstSubtitleClock = null;
      }
      final id = 'rtc-ai-$round-$sequence';
      _events.add({
        'type': 'reply_segment',
        'id': id,
        'userId': 'rtc-child-$round',
        'text': text,
      });
      if (_translationJobs.length < 3) {
        unawaited(_translateReply(id, text, reportError: false));
      }
    }
    if (!paragraph) return;
    _awaitingReply = false;
    if ((_context.kind == ConversationKind.roleplay ||
            _context.kind == ConversationKind.customRoleplay) &&
        _completedObjectives < _context.objectives.length) {
      _events.add({
        'type': 'practice_progress',
        'completed': ++_completedObjectives,
        'label': '完成一个表达尝试，继续加油！',
      });
    }
    _events.add({'type': 'done'});
  }

  @override
  Future<void> send(Map<String, dynamic> command) async {
    final type = command['type'];
    if (type == 'configure') return; // Already sent with RTC bootstrap.
    if (type == 'text') {
      await _sendRtcText(command['text'] as String? ?? '');
      return;
    }
    if (type == 'translate') {
      await _translateReply(
        command['id'] as String? ?? '',
        command['text'] as String? ?? '',
      );
      return;
    }
    throw const VoiceFailure('当前操作暂不可用。');
  }

  Future<void> _sendRtcText(String raw) async {
    final text = raw.trim();
    final credentials = _credentials;
    if (!_rtcActive || text.isEmpty || credentials == null) {
      throw const VoiceFailure('文字消息暂时无法发送，请稍后再试。');
    }
    final id = 'rtc-typed-${DateTime.now().microsecondsSinceEpoch}';
    _events.add({'type': 'transcript', 'id': id, 'text': text});
    _awaitingReply = true;
    try {
      await _bridge.sendControl(
        userId: credentials.botUserId,
        data: encodeRtcControl(
          command: 'ExternalTextToLLM',
          message: text,
        ),
      );
    } catch (_) {
      _awaitingReply = false;
      _events.add({'type': 'error', 'message': '文字消息暂时无法发送，请稍后再试。'});
      _events.add({'type': 'done'});
      rethrow;
    }
  }

  @override
  Future<void> uploadBufferedAudio(Stream<Uint8List> pcm) async {
    final credentials = _credentials;
    if (!_rtcActive || credentials == null) {
      throw const VoiceFailure('连接已断开，请重试。');
    }
    final generation = ++_turnGeneration;
    _pendingBufferedText = '';
    _voiceDraft.clear();
    _latestVoiceText = '';
    _manualTurnOpen = true;
    await _bridge.setRemoteMuted(true);
    try {
      await _bridge.startExternalPublishing();
      const int frameBytes = 320;
      final stopwatch = Stopwatch()..start();
      var frameIndex = 0;
      var carry = Uint8List(0);
      Future<void> push(Uint8List frame) async {
        await _bridge.pushPcmFrame(frame);
        frameIndex++;
        final target = Duration(milliseconds: frameIndex * 10);
        final remaining = target - stopwatch.elapsed;
        if (remaining > Duration.zero) await Future<void>.delayed(remaining);
      }
      await for (final chunk in pcm) {
        if (_closed || generation != _turnGeneration) return;
        final combined = Uint8List(carry.length + chunk.length)
          ..setRange(0, carry.length, carry)
          ..setRange(carry.length, carry.length + chunk.length, chunk);
        var offset = 0;
        while (combined.length - offset >= frameBytes) {
          await push(Uint8List.sublistView(
              combined, offset, offset + frameBytes));
          offset += frameBytes;
        }
        carry = Uint8List.fromList(combined.sublist(offset));
      }
      if (carry.isNotEmpty && generation == _turnGeneration) {
        final padded = Uint8List(frameBytes)..setRange(0, carry.length, carry);
        await push(padded);
      }
      await _bridge.stopExternalPublishing();
      final asrClock = kDebugMode ? (Stopwatch()..start()) : null;
      await _awaitFinalVoiceText();
      if (asrClock != null) {
        debugPrint('SayPal RTC capture: asr_tail ${asrClock.elapsedMilliseconds}ms');
      }
      if (_closed || generation != _turnGeneration) return;
      _pendingBufferedText = _draftText.trim();
    } finally {
      await _bridge.stopExternalPublishing();
    }
  }

  @override
  Future<void> commitBufferedAudio() async {
    final credentials = _credentials;
    final text = _pendingBufferedText.trim();
    if (!_rtcActive || credentials == null) {
      throw const VoiceFailure('连接已断开，请重试。');
    }
    if (text.isEmpty) {
      await _interruptPrematureReply();
      _manualTurnOpen = false;
      await _restoreRemoteAudio();
      _events.add({'type': 'no_speech'});
      return;
    }
    _manualTurnOpen = false;
    _awaitingReply = true;
    try {
      _events.add({
        'type': 'transcript',
        'id': 'rtc-child-${DateTime.now().microsecondsSinceEpoch}',
        'text': text,
      });
      _events.add({'type': 'partial', 'text': ''});
      _firstSubtitleClock = kDebugMode ? (Stopwatch()..start()) : null;
      _sawBotSubtitle = false;
      await _bridge.sendControl(
        userId: credentials.botUserId,
        data: encodeRtcControl(
          command: 'ExternalTextToLLM',
          message: text,
        ),
      );
    } finally {
      await _bridge.stopExternalPublishing();
      _manualTurnOpen = false;
      await _restoreRemoteAudio();
      _voiceDraft.clear();
      _latestVoiceText = '';
      _pendingBufferedText = '';
    }
  }

  @override
  Future<void> cancelPendingTurn() async {
    _turnGeneration++;
    _firstSubtitleClock = null;
    _awaitingReply = false;
    await _bridge.stopExternalPublishing();
    await _interruptPrematureReply();
    _manualTurnOpen = false;
    _voiceDraft.clear();
    _latestVoiceText = '';
    _pendingBufferedText = '';
    _events.add({'type': 'partial', 'text': ''});
    await _restoreRemoteAudio();
  }

  Future<void> _translateReply(String id, String raw, {bool reportError = true}) async {
    final text = raw.trim();
    if (id.isEmpty || text.isEmpty) return;
    final translation = _translations[id] ?? await _translationJobs.putIfAbsent(id, () async {
      try {
        final result = await _post('translate', {'text': text}, timeout: const Duration(seconds: 12));
        final value = result['translation'];
        if (value is! String || value.trim().isEmpty) return null;
        if (_translations.length >= 40) _translations.remove(_translations.keys.first);
        return _translations[id] = value.trim();
      } catch (_) {
        return null;
      } finally {
        _translationJobs.remove(id);
      }
    });
    if (_closed) return;
    if (translation != null) {
      _events.add({'type': 'reply_translation', 'id': id, 'translation': translation});
    } else if (reportError) {
      _events.add({'type': 'translation_error', 'id': id});
    }
  }

  @override
  Future<void> record(
      {required bool automaticEnd, required void Function() onEnd}) async {
    if (!_rtcActive) throw const VoiceFailure('连接已断开，请重试。');
    _voiceDraft.clear();
    _latestVoiceText = '';
    _manualTurnOpen = true;
    _recordingLimit = Timer(const Duration(seconds: 60), onEnd);
    try {
      // Even if the deployed server still uses VAD auto-submit, the child
      // never hears an answer before explicitly ending the turn.
      await _bridge.setRemoteMuted(true);
      await _setPublishingInOrder(true);
    } catch (_) {
      _manualTurnOpen = false;
      await _restoreRemoteAudio();
      _recordingLimit?.cancel();
      rethrow;
    }
  }

  @override
  Future<void> endRecording() async {
    _recordingLimit?.cancel();
    await _setPublishingInOrder(false);
    await _awaitFinalVoiceText();
    final text = _draftText.trim();
    if (text.isEmpty) {
      await _interruptPrematureReply();
      _manualTurnOpen = false;
      await _restoreRemoteAudio();
      _events.add({'type': 'no_speech'});
      return;
    }
    _events.add({
      'type': 'transcript',
      'id': 'rtc-child-${DateTime.now().microsecondsSinceEpoch}',
      'text': text,
    });
    _events.add({'type': 'partial', 'text': ''});
    _manualTurnOpen = false;
    _awaitingReply = true;
    try {
      await _bridge.sendControl(
        userId: _credentials!.botUserId,
        data: encodeRtcControl(
          command: 'ExternalTextToLLM',
          message: text,
        ),
      );
    } finally {
      _manualTurnOpen = false;
      await _restoreRemoteAudio();
      _voiceDraft.clear();
      _latestVoiceText = '';
    }
  }

  String get _draftText {
    if (_voiceDraft.isEmpty) return _latestVoiceText;
    final completed = _voiceDraft.values.join(' ');
    final trailing = _latestVoiceText.trim();
    if (trailing.isEmpty || completed.endsWith(trailing)) return completed;
    return '$completed $trailing';
  }

  Future<void> _awaitFinalVoiceText() async {
    // A final subtitle may arrive shortly after unpublishing. Wait for one
    // update, but cap the tail so a missing ASR result never freezes the UI.
    if (_voiceDraft.isNotEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      return;
    }
    _voiceTextChanged = Completer<void>();
    try {
      await _voiceTextChanged!.future.timeout(voiceFinalizeTimeout);
      await Future<void>.delayed(const Duration(milliseconds: 220));
    } on TimeoutException {
      // Use the best available final/partial transcript below.
    } finally {
      _voiceTextChanged = null;
    }
  }

  @override
  Future<void> stopRecording() async {
    _recordingLimit?.cancel();
    await _setPublishingInOrder(false);
  }

  Future<void> _setPublishingInOrder(bool publishing) {
    final operation = _captureOperations.then<void>((_) async {
      if (_closed) {
        if (publishing) throw const VoiceFailure('连接已断开，请重试。');
        return;
      }
      if (!_rtcActive) {
        if (publishing) throw const VoiceFailure('连接已断开，请重试。');
        return;
      }
      await _bridge.setPublishing(publishing);
    });
    // Keep the queue usable after an individual native operation fails while
    // still returning that failure to the caller that owns the operation.
    _captureOperations = operation.then<void>((_) {}, onError: (_) {});
    return operation;
  }

  @override
  Future<void> cancelRecording() async {
    await stopRecording();
    if (_manualTurnOpen) await _interruptPrematureReply();
    _manualTurnOpen = false;
    await _restoreRemoteAudio();
    _voiceDraft.clear();
    _latestVoiceText = '';
    _events.add({'type': 'partial', 'text': ''});
  }

  Future<void> _interruptPrematureReply() async {
    final credentials = _credentials;
    if (!_rtcActive || credentials == null) return;
    try {
      await _bridge.sendControl(
        userId: credentials.botUserId,
        data: encodeRtcControl(command: 'Interrupt'),
      );
    } catch (_) {}
  }

  Future<void> _restoreRemoteAudio() async {
    if (_rtcActive) {
      await _bridge.setRemoteMuted(_playbackMuted || !_sessionActive);
    }
  }

  @override
  Future<void> play(Uint8List bytes) => _messageAudio.play(bytes);

  @override
  Future<void> stopPlayback() async {
    await _messageAudio.stopPlayback();
    if (_rtcActive) await _bridge.setRemoteMuted(true);
  }

  @override
  Future<void> setPlaybackMuted(bool muted) async {
    _playbackMuted = muted;
    await _messageAudio.setPlaybackMuted(muted);
    if (_rtcActive) await _bridge.setRemoteMuted(muted || !_sessionActive || _manualTurnOpen);
  }

  @override
  Future<void> setSessionActive(bool active) async {
    _sessionActive = active;
    if (!active) await cancelRecording();
    if (_rtcActive) {
      await _bridge.setRemoteMuted(!active || _playbackMuted);
    }
    if (!active) await _messageAudio.stopPlayback();
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _recordingLimit?.cancel();
    final botReady = _botReady;
    if (botReady != null && !botReady.isCompleted) botReady.complete();
    try {
      await _opening;
    } catch (_) {}
    try {
      await _captureOperations;
    } catch (_) {}
    await _bridgeSub?.cancel();
    final sessionId = _credentials?.sessionId;
    // Do not keep the child subscribed to RTC while waiting for a slow
    // StopVoiceChat HTTP round trip. Both sides begin teardown immediately;
    // each operation remains best-effort and idempotent.
    await Future.wait<void>(<Future<void>>[
      if (sessionId != null)
        (() async {
          try {
            await _post(
              'rtc/session/$sessionId/stop',
              const {},
              timeout: const Duration(seconds: 8),
            );
          } catch (_) {}
        })(),
      (() async {
        try {
          await _bridge.close();
        } catch (_) {}
      })(),
      (() async {
        try {
          await _messageAudio.close();
        } catch (_) {}
      })(),
    ]);
    _client.close();
    await _events.close();
  }
}

typedef VoidCallback = void Function();
