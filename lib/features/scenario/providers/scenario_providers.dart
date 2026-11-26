import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/local_store.dart';
import '../../realtime/domain/realtime_tutor_repository.dart';
import '../data/seed_scenarios.dart';
import '../models/scenario_models.dart';

/// 情景 → 会话请求的转换。
RealtimeSessionRequest scenarioSessionRequest(String scenarioId) {
  final LifeScenario? scenario = findScenario(scenarioId);
  if (scenario == null) {
    throw ArgumentError('Unknown scenario: $scenarioId');
  }
  return RealtimeSessionRequest(
    sessionId: 'scenario-${scenario.id}',
    tutorName: scenario.title,
    tutorPersonaPrompt: '你正在与英语学习者进行“${scenario.title}”情景对话，请保持自然、简洁且友好。',
    script: scenario.tasks
        .map(
          (ScenarioTask task) => DemoScriptTurn(
            aiTextEn: task.aiTextEn,
            aiTextZh: task.aiTextZh,
            suggestions: task.suggestions,
            keywords: task.keywords,
            taskId: task.id,
          ),
        )
        .toList(),
  );
}

/// 情景通关记录（本机持久化）。
final class ScenarioProgressController
    extends AutoDisposeAsyncNotifier<Set<String>> {
  static const String _storageKey = 'saypal.scenario.completed';

  @override
  Future<Set<String>> build() async {
    final Map<String, dynamic>? raw =
        await ref.read(localStoreProvider).getJson(_storageKey);
    if (raw == null) {
      return const <String>{};
    }
    return Set<String>.from(raw['completedScenarios'] as List<dynamic>);
  }

  Future<void> completeScenario(String scenarioId) async {
    final Set<String> completed =
        Set<String>.of(state.value ?? const <String>{});
    completed.add(scenarioId);
    await ref.read(localStoreProvider).setJson(_storageKey, {
      'completedScenarios': completed.toList(),
    });
    state = AsyncData(completed);
  }
}

final scenarioProgressProvider =
    AsyncNotifierProvider.autoDispose<ScenarioProgressController, Set<String>>(
  ScenarioProgressController.new,
);
