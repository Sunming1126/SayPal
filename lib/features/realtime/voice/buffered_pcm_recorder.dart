import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';

import 'voice_transport.dart';

abstract interface class PcmRecorder {
  Stream<Uint8List> get frames;
  Future<void> start({required void Function() onLimit});
  Future<void> stop();
  Future<void> cancel();
  Future<void> dispose();
}

typedef PcmRecorderFactory = PcmRecorder Function();

/// In-memory S16/16 kHz/mono capture used while RTC connects in the
/// background. Audio is never written to disk.
class BufferedPcmRecorder implements PcmRecorder {
  BufferedPcmRecorder({
    AudioRecorder? recorder,
    this.maxDuration = const Duration(seconds: 60),
  }) : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;
  final Duration maxDuration;
  final StreamController<Uint8List> _frames = StreamController<Uint8List>();
  StreamSubscription<Uint8List>? _subscription;
  Timer? _limit;
  bool _recording = false;
  bool _disposed = false;
  int _capturedBytes = 0;

  @override
  Stream<Uint8List> get frames => _frames.stream;

  @override
  Future<void> start({required void Function() onLimit}) async {
    if (_disposed) throw const VoiceFailure('麦克风暂时无法使用，请重试。');
    if (_recording) return;
    if (!await _recorder.hasPermission()) {
      throw const VoiceFailure('麦克风权限未允许，请在系统设置中开启。');
    }
    _capturedBytes = 0;
    final stream = await _recorder.startStream(const RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: 16000,
      numChannels: 1,
      echoCancel: true,
      noiseSuppress: true,
      streamBufferSize: 3200,
    ));
    _recording = true;
    _subscription = stream.listen((Uint8List bytes) {
      if (!_recording || bytes.isEmpty) return;
      final remaining = 16000 * 2 * maxDuration.inSeconds - _capturedBytes;
      if (remaining <= 0) return;
      final chunk = remaining >= bytes.length
          ? bytes
          : Uint8List.sublistView(bytes, 0, remaining);
      _capturedBytes += chunk.length;
      if (!_frames.isClosed) _frames.add(Uint8List.fromList(chunk));
    });
    _limit = Timer(maxDuration, onLimit);
  }

  @override
  Future<void> stop() async {
    if (!_recording) {
      _closeFrames();
      return;
    }
    _recording = false;
    _limit?.cancel();
    try {
      await _recorder.stop();
    } finally {
      try {
        await _subscription?.cancel();
      } finally {
        _subscription = null;
        _closeFrames();
      }
    }
  }

  @override
  Future<void> cancel() async {
    _recording = false;
    _limit?.cancel();
    try {
      await _recorder.cancel();
    } catch (_) {}
    await _subscription?.cancel();
    _subscription = null;
    _closeFrames();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await cancel();
    await _recorder.dispose();
  }

  // A single-subscription controller keeps the Future returned by close()
  // pending until a listener consumes `done`. During permission failures or a
  // quick page exit RTC may never attach that listener, so cleanup must not
  // await that Future. Existing listeners still receive `done` normally.
  void _closeFrames() {
    if (!_frames.isClosed) unawaited(_frames.close());
  }
}
