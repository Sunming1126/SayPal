import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../realtime/domain/realtime_models.dart';
import '../../realtime/domain/realtime_session_state.dart';
import '../../realtime/domain/realtime_tutor_repository.dart';
import '../../realtime/session_controller.dart';
import '../../realtime/widgets/session_stage.dart';
import '../../statistics/providers/statistics_providers.dart';
import '../../vocabulary/providers/vocabulary_providers.dart';
import '../../vocabulary/widgets/word_lookup_sheet.dart';
import '../data/seed_scenarios.dart';
import '../models/scenario_models.dart';
import '../providers/scenario_providers.dart';

/// 角色扮演会话页：对话中实时显示任务进度，结束后展示完成度与评分。
class ScenarioSessionPage extends ConsumerStatefulWidget {
  const ScenarioSessionPage({required this.scenarioId, super.key});

  final String scenarioId;

  @override
  ConsumerState<ScenarioSessionPage> createState() =>
      _ScenarioSessionPageState();
}

class _ScenarioSessionPageState extends ConsumerState<ScenarioSessionPage> {
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final RealtimeSessionRequest request =
          scenarioSessionRequest(widget.scenarioId);
      final RealtimeSessionState state =
          ref.read(realtimeSessionControllerProvider(request));
      if (state.phase == RealtimeSessionPhase.idle) {
        ref.read(realtimeSessionControllerProvider(request).notifier).start();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final LifeScenario? scenario = findScenario(widget.scenarioId);
    if (scenario == null) {
      return const Scaffold(
        body: ErrorStateView(title: '情景不存在', message: ''),
      );
    }
    final RealtimeSessionRequest request =
        scenarioSessionRequest(widget.scenarioId);
    final RealtimeSessionState state =
        ref.watch(realtimeSessionControllerProvider(request));

    return Scaffold(
      appBar: AppBar(title: Text(scenario.title)),
      body: SafeArea(
        child: Column(
          children: [
            _TaskProgressHeader(scenario: scenario, state: state),
            Expanded(
              child: SessionStage(
                state: state,
                inputPlaceholder: '也可以自己说哦',
                onWordTap: (String word) async {
                  final bool saved = await ref
                      .read(vocabularyRepositoryProvider)
                      .isSaved(word);
                  if (!context.mounted) {
                    return;
                  }
                  await showWordLookupSheet(
                    context,
                    rawWord: word,
                    sheetRef: ref,
                    alreadySaved: saved,
                    source: '角色扮演',
                    wordLookup: (String w) =>
                        ref.read(wordLookupServiceProvider).lookup(w),
                  );
                },
                onSubmitReply: (String text) {
                  ref
                      .read(realtimeSessionControllerProvider(request).notifier)
                      .submitReply(text)
                      .then((_) => _maybeFinish(scenario, request));
                },
                onEndSession: () => _finish(scenario, request, early: true),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _maybeFinish(
    LifeScenario scenario,
    RealtimeSessionRequest request,
  ) async {
    final RealtimeSessionState state =
        ref.read(realtimeSessionControllerProvider(request));
    if (state.turnScores.length >= scenario.tasks.length &&
        !state.turnScores.any((int s) => s < 0) &&
        !_finished) {
      _finished = true;
      await _finish(scenario, request);
    }
  }

  Future<void> _finish(
    LifeScenario scenario,
    RealtimeSessionRequest request, {
    bool early = false,
  }) async {
    final controller =
        ref.read(realtimeSessionControllerProvider(request).notifier);
    await controller.endSession();
    final RealtimeSessionState state =
        ref.read(realtimeSessionControllerProvider(request));
    final TutorReport? report = state.report;
    if (report == null) {
      return;
    }

    final List<int> taskScores = state.turnScores;
    final List<bool> taskDone = taskScores.map((int s) => s >= 60).toList();
    final int completedCount = taskDone.where((bool done) => done).length;
    final int completionPercent =
        (completedCount * 100 ~/ scenario.tasks.length);
    final List<String> weakWords =
        report.weakWords.map((WeakWordRecord w) => w.word).toSet().toList();

    await recordFinishedSession(
      ref,
      feature: '角色扮演',
      durationSeconds: report.durationSeconds,
      speakingTurns: report.childTurns,
      pronunciationScore: report.pronunciationScore,
      fluencyScore: report.fluencyScore,
      weakWords: weakWords,
    );

    if (!early && completedCount == scenario.tasks.length) {
      await ref
          .read(scenarioProgressProvider.notifier)
          .completeScenario(scenario.id);
    }

    if (mounted) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) => _ScenarioResultDialog(
          scenario: scenario,
          taskScores: taskScores,
          completionPercent: early ? 0 : completionPercent,
          score: report.overallScore,
          encouragement: report.encouragement,
          early: early,
        ),
      );
      if (mounted) {
        context.go('/scenario');
      }
    }
  }
}

/// 顶部任务进度条。
class _TaskProgressHeader extends StatelessWidget {
  const _TaskProgressHeader({required this.scenario, required this.state});

  final LifeScenario scenario;
  final RealtimeSessionState state;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: ContentCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  '任务进度',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                Text(
                  '${state.turnScores.where((int s) => s >= 60).length}/${scenario.tasks.length}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (int i = 0; i < scenario.tasks.length; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Row(
                        children: [
                          Icon(
                            i < state.turnScores.length
                                ? (state.turnScores[i] >= 60
                                    ? Icons.check_circle
                                    : Icons.error_outline)
                                : Icons.radio_button_unchecked,
                            size: 18,
                            color: i < state.turnScores.length
                                ? (state.turnScores[i] >= 60
                                    ? AppColors.success
                                    : AppColors.warning)
                                : AppColors.outline,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              scenario.tasks[i].titleZh,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ScenarioResultDialog extends StatelessWidget {
  const _ScenarioResultDialog({
    required this.scenario,
    required this.taskScores,
    required this.completionPercent,
    required this.score,
    required this.encouragement,
    required this.early,
  });

  final LifeScenario scenario;
  final List<int> taskScores;
  final int completionPercent;
  final int score;
  final String encouragement;
  final bool early;

  @override
  Widget build(BuildContext context) {
    final bool allDone = completionPercent == 100;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Text(allDone ? '🎉' : '💪', style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 8),
          Text(allDone ? '情景通关！' : '本次演练结束'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('任务完成度：$completionPercent%'),
          const SizedBox(height: 6),
          Text(
            early ? '本次提前结束，任务不计入完成。' : '各任务得分：${taskScores.join(' / ')}',
          ),
          const SizedBox(height: 6),
          Text('口语评分：$score 分（演示评分）'),
          const SizedBox(height: 8),
          Text(encouragement, style: const TextStyle(color: AppColors.success)),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('好的'),
        ),
      ],
    );
  }
}
