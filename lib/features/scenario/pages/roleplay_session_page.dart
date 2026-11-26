import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../realtime/voice/conversation_context.dart';
import '../../realtime/voice/pages/practice_conversation_page.dart';
import '../providers/practice_providers.dart';

class RoleplaySessionPage extends ConsumerWidget {
  const RoleplaySessionPage({required this.scenarioId, super.key});
  final String scenarioId;
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(roleplayCatalogProvider).when(
          loading: () => const Scaffold(body: LoadingView()),
          error: (_, __) => const Scaffold(
              body: ErrorStateView(title: '场景加载失败', message: '')),
          data: (items) {
            final matches = items.where((e) => e.id == scenarioId).toList();
            if (matches.isEmpty) {
              return const Scaffold(
                  body: ErrorStateView(title: '场景不存在', message: ''));
            }
            final s = matches.first;
            return PracticeConversationPage(
                context: ConversationContext(
                    kind: ConversationKind.roleplay,
                    catalogId: s.id,
                    title: s.title,
                    learnerRole: s.learnerRole,
                    aiRole: s.aiRole,
                    situation: s.situation,
                    objectives: s.objectives),
                welcome: s.opening,
                objectives: s.objectives,
                finishedLabel: '情景练习结束');
          });
}
