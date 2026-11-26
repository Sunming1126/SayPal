import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../features/chat/voice/voice_chat_providers.dart';
import '../features/realtime/voice/buffered_pcm_recorder.dart';
import '../features/realtime/voice/conversation_context.dart';
import '../features/realtime/voice/rtc_voice_transport.dart';
import '../features/realtime/voice/websocket_voice_transport.dart';
import '../features/vocabulary/providers/vocabulary_providers.dart';
import '../features/statistics/providers/statistics_providers.dart';
import '../features/statistics/models/learning_stats.dart';

/// Debug defaults to the verified SayPal WebSocket service.
const effectiveChatTransport = AppConfig.chatTransport;

/// 名称为旧版兼容保留；RTC 与 WebSocket 真实语音页均为 true。
final websocketChatEnabled =
    effectiveChatTransport == 'websocket' || effectiveChatTransport == 'rtc';

final rtcChatEnabled = effectiveChatTransport == 'rtc';

final _voiceBaseUrl = AppConfig.instance.apiBaseUrl;

/// The shared token is never stored in source. A debug build can receive it
/// once through --dart-define, then [main] keeps it in platform secure storage
/// so subsequent runs on the same development device can use plain
/// `flutter run`. Release builds still require explicit production auth.
final voiceChatTokenProvider = Provider<String>((ref) => AppConfig.chatToken);

final voiceTransportOverride =
    voiceTransportFactoryProvider.overrideWith((ref) {
  final token = ref.watch(voiceChatTokenProvider);
  return () {
    if (rtcChatEnabled) {
      return RtcVoiceTransport(_voiceBaseUrl, token: token);
    }
    return WebsocketVoiceTransport(_voiceBaseUrl, token: token);
  };
});

final voiceFeatureOverrides = [
  voiceTransportOverride,
  if (effectiveChatTransport == 'websocket')
    pcmRecorderFactoryProvider.overrideWithValue(
      // The server closes on more than 30 seconds of PCM. Leave room for the
      // recorder's buffered frames when the timer fires.
      () => BufferedPcmRecorder(maxDuration: const Duration(seconds: 29)),
    ),
  voiceWordLookupProvider
      .overrideWith((ref) => ref.watch(wordLookupServiceProvider)),
  voiceVocabularyProvider
      .overrideWith((ref) => ref.watch(vocabularyRepositoryProvider)),
  voicePracticeSinkProvider.overrideWith((ref) {
    final repository = ref.watch(learningRecordRepositoryProvider);
    return (ConversationContext context, int seconds, int turns) async {
      final feature = switch (context.kind) {
        ConversationKind.freeChat => '聊一聊（真实语音）',
        ConversationKind.roleplay || ConversationKind.customRoleplay => '情景扮演',
        ConversationKind.tutorTranslation ||
        ConversationKind.tutorEnglishQa =>
          '主题课',
      };
      await repository.recordSession(SessionLearningRecord(
        finishedAt: DateTime.now(),
        feature: feature,
        durationSeconds: seconds,
        speakingTurns: turns,
        pronunciationScore: 0,
        fluencyScore: 0,
        contentId: context.catalogId,
      ));
      ref.invalidate(statisticsSummaryProvider);
    };
  }),
];
