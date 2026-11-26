import 'dart:io';
import 'dart:typed_data';

import 'package:volc_engine_rtc/api/bytertc_video_api.dart' as rtc_public;
import 'package:volc_engine_rtc/codegen/android/index.dart' as rtc_android;
import 'package:volc_engine_rtc/codegen/ios/index.dart' as rtc_ios;

/// The 3.60.6 package exposes `setAudioSourceType` on the packed engine but
/// accidentally omits the engine-level `pushExternalAudioFrame` wrapper.
/// Keep the platform-specific generated call isolated here until the plugin
/// fixes its public wrapper.
Future<int?> pushVolcExternalPcmFrame(Uint8List pcm) async {
  const samples = 160; // 10 ms at 16 kHz, S16 mono => 320 bytes.
  if (Platform.isAndroid) {
    final frame = rtc_android.AudioFrame()
      ..buffer = pcm
      ..samples = samples
      ..sampleRate = rtc_android.AudioSampleRate.AUDIO_SAMPLE_RATE_16000
      ..channel = rtc_android.AudioChannel.AUDIO_CHANNEL_MONO;
    return (rtc_public.$engine_instance as rtc_android.RTCEngine)
        .pushExternalAudioFrame(frame);
  }
  if (Platform.isIOS) {
    final frame = rtc_ios.ByteRTCAudioFrame()
      ..buffer = pcm
      ..samples = samples
      ..sampleRate = rtc_ios.ByteRTCAudioSampleRate.ByteRTCAudioSampleRate16000
      ..channel = rtc_ios.ByteRTCAudioChannel.ByteRTCAudioChannelMono;
    return (rtc_public.$engine_instance as rtc_ios.ByteRTCEngine)
        .pushExternalAudioFrame(frame);
  }
  throw UnsupportedError('External RTC audio is only available on mobile.');
}
