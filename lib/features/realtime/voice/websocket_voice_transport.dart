import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';

import '../../../core/config/service_endpoint.dart';
import 'conversation_context.dart';
import 'voice_transport.dart';

class WebsocketVoiceTransport implements VoiceTransport {
  WebsocketVoiceTransport(this.baseUrl, {this.token = ''});
  final String baseUrl;
  final String token;
  final _events = StreamController<Map<String, dynamic>>.broadcast();
  AudioRecorder? _nativeRecorder;
  AudioPlayer? _nativePlayer;
  AudioRecorder get _recorder => _nativeRecorder ??= AudioRecorder();
  AudioPlayer get _player => _nativePlayer ??= AudioPlayer();
  WebSocket? _socket;
  StreamSubscription<dynamic>? _socketSub;
  StreamSubscription<Uint8List>? _micSub;
  Timer? _limit;
  bool _closed = false;
  int _generation = 0;
  Completer<void>? _playback;
  Completer<void>? _readiness;
  final BytesBuilder _pendingPcm = BytesBuilder(copy: false);
  int _uploadGeneration = 0;
  bool _playbackMuted = false;
  bool _recordingTurn = false;

  @override
  Stream<Map<String, dynamic>> get events => _events.stream;

  @override
  Future<void> connect({required ConversationContext context}) async {
    final uri = Uri.tryParse(baseUrl);
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const VoiceFailure('请配置有效的后端地址。');
    }
    if (uri.scheme == 'http' &&
        !['localhost', '127.0.0.1', '::1'].contains(uri.host)) {
      throw const VoiceFailure('非本机服务必须使用 HTTPS。');
    }
    final socketUri = resolveServiceEndpoint(
      baseUrl,
      'chat/voice',
      scheme: uri.scheme == 'https' ? 'wss' : 'ws',
    );
    if (socketUri == null) {
      throw const VoiceFailure('请配置有效的后端地址。');
    }
    final opening = WebSocket.connect(
      socketUri.toString(),
      headers: token.isEmpty ? null : {'Authorization': 'Bearer $token'},
    );
    final WebSocket socket;
    try {
      socket = await opening.timeout(const Duration(seconds: 12));
    } on TimeoutException {
      // The upgrade may still finish after the timeout. Release that socket.
      unawaited(opening.then<void>((lateSocket) async {
        await lateSocket.close();
      }).catchError((Object _) {}));
      throw const VoiceFailure('连接语音服务超时，请重试。');
    } on WebSocketException catch (error) {
      if (error.httpStatusCode == 401 || error.httpStatusCode == 403) {
        throw const VoiceFailure('语音访问凭证缺失或无效。', retryable: false);
      }
      throw const VoiceFailure('暂时无法连接语音服务器。');
    }
    if (_closed) {
      await socket.close();
      return;
    }
    _socket = socket;
    socket.pingInterval = const Duration(seconds: 20);
    final ready = Completer<void>();
    _readiness = ready;
    bool disconnected = false;
    bool accepted = false;
    final readiness = ready.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () {
        disconnected = true;
        throw const VoiceFailure('语音服务尚未就绪，请重试。');
      },
    );
    void onDisconnect() {
      if (_closed || disconnected) return;
      disconnected = true;
      if (!ready.isCompleted) {
        ready.completeError(const VoiceFailure('语音服务尚未就绪，请重试。'));
      } else if (accepted) {
        _events.add({'type': 'disconnected'});
      }
    }
    _socketSub = socket.listen((dynamic raw) {
      if (_closed || disconnected) return;
      try {
        if (raw is! String || raw.length > 5000000) {
          throw const FormatException();
        }
        final event = jsonDecode(raw) as Map<String, dynamic>;
        if (!ready.isCompleted && event['type'] == 'error') {
          ready.completeError(VoiceFailure(
            event['message'] as String? ?? '语音服务尚未就绪，请重试。',
          ));
          return;
        }
        if (!ready.isCompleted && event['type'] == 'ready') {
          accepted = true;
          _events.add(event);
          ready.complete();
        } else if (accepted) {
          _events.add(event);
        }
      } catch (_) {
        if (accepted) {
          _events.add({'type': 'error', 'message': '收到无法识别的服务消息。'});
        } else if (!ready.isCompleted) {
          ready.completeError(const VoiceFailure('收到无法识别的服务消息。'));
        }
      }
    }, onError: (Object _) => onDisconnect(), onDone: onDisconnect);
    await readiness;
  }

  @override
  Future<void> send(Map<String, dynamic> command) async {
    if (_socket?.readyState != WebSocket.open) {
      throw const VoiceFailure('连接已断开，请重连。');
    }
    final context = command['context'];
    if (command['type'] == 'configure' &&
        context is Map<String, dynamic> &&
        context['kind'] == 'roleplay') {
      // Some restored catalog IDs are absent on the existing server. Send the
      // same bounded scene fields it accepts for custom practice.
      _socket!.add(jsonEncode({
        ...command,
        'context': {...context, 'kind': 'customRoleplay'},
      }));
      return;
    }
    _socket!.add(jsonEncode(command));
  }

  @override
  Future<void> uploadBufferedAudio(Stream<Uint8List> pcm) async {
    final generation = ++_uploadGeneration;
    _pendingPcm.clear();
    await for (final chunk in pcm) {
      if (_closed || generation != _uploadGeneration) return;
      _pendingPcm.add(chunk);
    }
  }

  @override
  Future<void> commitBufferedAudio() async {
    final pcm = _pendingPcm.takeBytes();
    if (pcm.isEmpty) {
      _events.add({'type': 'no_speech'});
      return;
    }
    await send({'type': 'start'});
    const int chunkSize = 3200;
    for (var offset = 0; offset < pcm.length; offset += chunkSize) {
      if (_socket?.readyState != WebSocket.open) {
        throw const VoiceFailure('连接已断开，请重连。');
      }
      _socket!.add(Uint8List.sublistView(
          pcm, offset, (offset + chunkSize).clamp(0, pcm.length)));
    }
    await send({'type': 'end'});
  }

  @override
  Future<void> cancelPendingTurn() async {
    // The legacy protocol has no per-turn interrupt. Closing is the only way
    // to guarantee that already buffered audio cannot be answered later.
    await cancelRecording();
  }

  @override
  Future<void> record(
      {required bool automaticEnd, required void Function() onEnd}) async {
    final generation = ++_generation;
    await _player.stop();
    if (!await _recorder.hasPermission()) {
      throw const VoiceFailure('麦克风权限未允许，请在系统设置中开启。');
    }
    if (_closed || generation != _generation) return;
    final stream = await _recorder.startStream(const RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: 16000,
      numChannels: 1,
      echoCancel: true,
      noiseSuppress: true,
    ));
    if (_closed || generation != _generation) {
      try {
        await _recorder.stop();
      } catch (_) {}
      return;
    }
    try {
      await send({'type': 'start'});
      _recordingTurn = true;
    } catch (_) {
      // Never leave a recorder running without a listener or a server turn.
      try {
        await _recorder.stop();
      } catch (_) {}
      rethrow;
    }
    var heardSpeech = false;
    var silenceSamples = 0;
    var totalSamples = 0;
    var ended = false;
    void finish() {
      if (!ended) {
        ended = true;
        onEnd();
      }
    }

    _limit = Timer(const Duration(seconds: 25), finish);
    _micSub = stream.listen((bytes) {
      if (_closed || ended || generation != _generation) return;
      try {
        _socket?.add(bytes);
      } catch (_) {
        // Socket died mid-recording (dart:io throws on add-after-close).
        if (!_closed) _events.add({'type': 'disconnected'});
        finish();
        return;
      }
      if (!automaticEnd) return;
      final data = ByteData.sublistView(bytes);
      var sum = 0.0;
      final count = bytes.length ~/ 2;
      if (count == 0) return;
      for (var i = 0; i < count; i++) {
        final value = data.getInt16(i * 2, Endian.little);
        sum += value * value;
      }
      totalSamples += count;
      if (sqrt(sum / count) > 650) {
        heardSpeech = true;
        silenceSamples = 0;
      } else {
        silenceSamples += count;
      }
      if ((heardSpeech && silenceSamples > 22400) ||
          (!heardSpeech && totalSamples > 128000)) {
        finish();
      }
    }, onError: (Object _) {
      if (!_closed) _events.add({'type': 'error', 'message': '录音中断，请停止后重试。'});
      finish();
    });
  }

  @override
  Future<void> stopRecording() async {
    _generation++;
    _limit?.cancel();
    try {
      await _nativeRecorder?.stop();
    } catch (_) {}
    await _micSub?.cancel();
    _micSub = null;
  }

  @override
  Future<void> endRecording() async {
    await stopRecording();
    if (_recordingTurn && !_closed) {
      _recordingTurn = false;
      await send({'type': 'end'});
    }
  }

  @override
  Future<void> cancelRecording() async {
    _uploadGeneration++;
    _pendingPcm.clear();
    await stopRecording();
    if (_recordingTurn) {
      _recordingTurn = false;
      await _socket?.close();
    }
  }

  @override
  Future<void> stopPlayback() async {
    final playback = _playback;
    if (playback != null && !playback.isCompleted) playback.complete();
    await _nativePlayer?.stop();
  }

  @override
  Future<void> setPlaybackMuted(bool muted) async {
    _playbackMuted = muted;
    if (muted) await stopPlayback();
  }

  @override
  Future<void> setSessionActive(bool active) async {
    if (!active) {
      await cancelRecording();
      await stopPlayback();
    }
  }

  @override
  Future<void> play(Uint8List bytes) async {
    if (_playbackMuted || _closed) return;
    final completed = Completer<void>();
    _playback = completed;
    final subscription = _player.onPlayerComplete.listen((_) {
      if (!completed.isCompleted) completed.complete();
    });
    try {
      await _player.play(BytesSource(bytes, mimeType: 'audio/mpeg'));
      await completed.future.timeout(const Duration(seconds: 45));
    } finally {
      await subscription.cancel();
      if (identical(_playback, completed)) _playback = null;
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    final readiness = _readiness;
    if (readiness != null && !readiness.isCompleted) {
      readiness.completeError(const VoiceFailure('语音连接已关闭。'));
    }
    if (_playback != null && !_playback!.isCompleted) _playback!.complete();
    _generation++;
    _limit?.cancel();
    // Best-effort teardown: a plugin throwing must not skip later releases.
    try {
      await _micSub?.cancel();
    } catch (_) {}
    try {
      await _nativeRecorder?.dispose();
    } catch (_) {}
    try {
      await _nativePlayer?.dispose();
    } catch (_) {}
    try {
      await _socketSub?.cancel();
    } catch (_) {}
    try {
      await _socket?.close();
    } catch (_) {}
    await _events.close();
  }
}
