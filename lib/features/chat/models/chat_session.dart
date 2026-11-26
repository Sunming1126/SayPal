import '../../realtime/voice/voice_conversation_controller.dart';

/// A locally persisted text-only free-chat session.
///
/// Audio bytes are deliberately excluded so conversation history stays small
/// and never turns into an implicit recording archive.
class ChatSession {
  const ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.messages,
  });

  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ChatSessionMessage> messages;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
        'messages': messages
            .map((ChatSessionMessage message) => message.toJson())
            .toList(),
      };

  factory ChatSession.fromJson(Map<String, dynamic> json) => ChatSession(
        id: json['id'] as String,
        title: json['title'] as String? ?? '日常交流',
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          json['createdAt'] as int? ?? 0,
        ),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          json['updatedAt'] as int? ?? 0,
        ),
        messages: (json['messages'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map>()
            .map(
              (Map<dynamic, dynamic> item) => ChatSessionMessage.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList(growable: false),
      );
}

class ChatSessionMessage {
  const ChatSessionMessage({
    required this.id,
    required this.text,
    required this.child,
    this.translation = '',
    this.correction = '',
  });

  final String id;
  final String text;
  final bool child;
  final String translation;
  final String correction;

  factory ChatSessionMessage.fromVoiceMessage(VoiceMessage message) =>
      ChatSessionMessage(
        id: message.id,
        text: message.text,
        child: message.child,
        translation: message.translation,
        correction: message.correction,
      );

  VoiceMessage toVoiceMessage() => VoiceMessage(
        id: id,
        text: text,
        child: child,
        translation: translation,
        correction: correction,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'text': text,
        'child': child,
        if (translation.isNotEmpty) 'translation': translation,
        if (correction.isNotEmpty) 'correction': correction,
      };

  factory ChatSessionMessage.fromJson(Map<String, dynamic> json) =>
      ChatSessionMessage(
        id: json['id'] as String,
        text: json['text'] as String,
        child: json['child'] as bool? ?? false,
        translation: json['translation'] as String? ?? '',
        correction: json['correction'] as String? ?? '',
      );
}
