import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/seed_personas.dart';
import '../models/chat_persona.dart';
import '../../realtime/domain/realtime_tutor_repository.dart';

/// 当前选中的 AI 角色。
final selectedPersonaProvider =
    NotifierProvider.autoDispose<SelectedPersonaController, ChatPersona>(
  SelectedPersonaController.new,
);

final class SelectedPersonaController
    extends AutoDisposeNotifier<ChatPersona> {
  @override
  ChatPersona build() => kSeedPersonas.first;

  void select(ChatPersona persona) {
    state = persona;
  }
}

/// 会话请求：跟随选中角色变化（切换角色后由页面重新拉起会话）。
final chatSessionRequestProvider = Provider.autoDispose<RealtimeSessionRequest>(
  (ref) {
    final ChatPersona persona = ref.watch(selectedPersonaProvider);
    return RealtimeSessionRequest(
      sessionId: 'chat-${persona.id}',
      tutorName: persona.name,
      tutorPersonaPrompt:
          '你是一位面向中国小学生的英语陪练，名字叫${persona.name}，'
          '性格：${persona.personalityZh}。请使用简短、简单的英文短句。',
      script: persona.demoScriptEn
          .map(
            (ChatDemoTurn turn) => DemoScriptTurn(
              aiTextEn: turn.aiText,
              aiTextZh: turn.aiTextZh,
              suggestions: turn.suggestions,
              // 自由聊天不评分。
              keywords: const <String>[],
            ),
          )
          .toList(),
    );
  },
);
