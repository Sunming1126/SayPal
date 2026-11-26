import '../../../core/services/local_store.dart';
import '../models/chat_session.dart';

class LocalChatSessionRepository {
  LocalChatSessionRepository(this._store);

  static const String _storageKey = 'saypal.chat.sessions.v1';
  static const int _maxSessions = 50;

  final LocalStore _store;

  Future<List<ChatSession>> load() async {
    final List<dynamic> raw =
        await _store.getJsonList(_storageKey) ?? const <dynamic>[];
    final List<ChatSession> sessions = raw
        .whereType<Map>()
        .map(
          (Map<dynamic, dynamic> item) => ChatSession.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
    sessions.sort(
      (ChatSession left, ChatSession right) =>
          right.updatedAt.compareTo(left.updatedAt),
    );
    return sessions;
  }

  Future<List<ChatSession>> save(ChatSession session) async {
    final List<ChatSession> sessions = await load();
    final List<ChatSession> next = <ChatSession>[
      session,
      ...sessions.where((ChatSession item) => item.id != session.id),
    ].take(_maxSessions).toList(growable: false);
    await _store.setJsonList(
      _storageKey,
      next.map((ChatSession item) => item.toJson()).toList(),
    );
    return next;
  }
}
