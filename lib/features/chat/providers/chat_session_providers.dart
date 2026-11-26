import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/local_store.dart';
import '../data/local_chat_session_repository.dart';
import '../models/chat_session.dart';

final chatSessionRepositoryProvider = Provider<LocalChatSessionRepository>(
  (Ref ref) => LocalChatSessionRepository(ref.watch(localStoreProvider)),
);

final class ChatSessionHistoryController
    extends AutoDisposeAsyncNotifier<List<ChatSession>> {
  @override
  Future<List<ChatSession>> build() =>
      ref.watch(chatSessionRepositoryProvider).load();

  Future<void> save(ChatSession session) async {
    final List<ChatSession> sessions =
        await ref.read(chatSessionRepositoryProvider).save(session);
    state = AsyncData<List<ChatSession>>(sessions);
  }
}

final chatSessionHistoryProvider = AsyncNotifierProvider.autoDispose<
    ChatSessionHistoryController,
    List<ChatSession>>(ChatSessionHistoryController.new);
