/// A constrained conversation description shared by chat, role play and tutor.
/// It is data, never a client-supplied system prompt.
enum ConversationKind {
  freeChat,
  roleplay,
  customRoleplay,
  tutorTranslation,
  tutorEnglishQa
}

class ConversationContext {
  const ConversationContext({
    required this.kind,
    this.catalogId,
    this.title = '',
    this.learnerRole = '',
    this.aiRole = '',
    this.situation = '',
    this.objectives = const <String>[],
    this.stageIndex = 0,
  });

  const ConversationContext.freeChat() : this(kind: ConversationKind.freeChat);

  final ConversationKind kind;
  final String? catalogId;
  final String title;
  final String learnerRole;
  final String aiRole;
  final String situation;
  final List<String> objectives;
  final int stageIndex;

  bool get needsConfiguration => kind != ConversationKind.freeChat;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'kind': kind.name,
        if (catalogId != null) 'catalogId': catalogId,
        if (title.isNotEmpty) 'title': title,
        if (learnerRole.isNotEmpty) 'learnerRole': learnerRole,
        if (aiRole.isNotEmpty) 'aiRole': aiRole,
        if (situation.isNotEmpty) 'situation': situation,
        if (objectives.isNotEmpty) 'objectives': objectives,
        'stageIndex': stageIndex,
      };
}
