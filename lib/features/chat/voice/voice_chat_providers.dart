export '../../realtime/voice/voice_conversation_providers.dart'
    show
        pcmRecorderFactoryProvider,
        voicePracticeSinkProvider,
        voiceTransportFactoryProvider;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../realtime/voice/conversation_context.dart';
import '../../realtime/voice/voice_conversation_providers.dart';
import '../../vocabulary/domain/vocabulary_repository.dart';

/// Cross-feature repositories are injected by app, never read another feature's state here.
final voiceWordLookupProvider = Provider<WordLookupService>(
    (ref) => throw StateError('Word lookup not injected'));
final voiceVocabularyProvider = Provider<VocabularyRepository>(
    (ref) => throw StateError('Vocabulary not injected'));
final voiceChatProvider =
    voiceConversationProvider(const ConversationContext.freeChat());
