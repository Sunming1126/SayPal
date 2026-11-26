import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'conversation_context.dart';
import 'buffered_pcm_recorder.dart';
import 'voice_conversation_controller.dart';
import 'voice_transport.dart';

final voiceTransportFactoryProvider = Provider<VoiceTransport Function()>(
  (ref) => throw StateError('Voice transport must be injected by app'),
);

final pcmRecorderFactoryProvider = Provider<PcmRecorderFactory>(
  (ref) => BufferedPcmRecorder.new,
);

final voicePracticeSinkProvider =
    Provider<VoicePracticeSink>((ref) => (_, __, ___) async {});

final voiceConversationProvider = StateNotifierProvider.autoDispose
    .family<VoiceConversationController, VoiceChatState, ConversationContext>(
  (ref, context) => VoiceConversationController(
    ref.watch(voiceTransportFactoryProvider),
    context: context,
    savePractice: ref.watch(voicePracticeSinkProvider),
    recorderFactory: ref.watch(pcmRecorderFactoryProvider),
  ),
);
