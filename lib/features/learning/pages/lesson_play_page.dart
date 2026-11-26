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
import '../models/learning_models.dart';
import '../providers/learning_providers.dart';

/// 课程练习页：AI 逐步提问，孩子点选/输入回答，实时评分推进。
class LessonPlayPage extends ConsumerStatefulWidget {
  const LessonPlayPage({required this.lessonId, super.key});

  final String lessonId;

  @override
  ConsumerState<LessonPlayPage> createState() => _LessonPlayPageState();
}

class _LessonPlayPageState extends ConsumerState<LessonPlayPage> {
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    // 进入页面自动开始会话（帧渲染完成后执行）。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final RealtimeSessionRequest request =
          lessonSessionRequest(widget.lessonId);
      final RealtimeSessionState state =
          ref.read(realtimeSessionControllerProvider(request));
      if (state.phase == RealtimeSessionPhase.idle) {
        ref.read(realtimeSessionControllerProvider(request).notifier).start();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final Lesson? lesson = findLesson(widget.lessonId);
    if (lesson == null) {
      return const Scaffold(body: ErrorStateView(title: '课程不存在', message: ''));
    }
    final RealtimeSessionRequest request = lessonSessionRequest(widget.lessonId);
    final RealtimeSessionState state =
        ref.watch(realtimeSessionControllerProvider(request));

    return PopScope(
      canPop: state.isEnded || state.isFailed,
      child: Scaffold(
        appBar: AppBar(title: Text(lesson.title)),
        body: SafeArea(
          child: Column(
            children: [
              _StepProgressHeader(
                lesson: lesson,
                state: state,
              ),
              Expanded(
                child: SessionStage(
                  state: state,
                  header: null,
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
                      source: '学一学',
                      wordLookup: (String w) =>
                          ref.read(wordLookupServiceProvider).lookup(w),
                    );
                  },
                  onSubmitReply: (String text) {
                    ref
                        .read(
                          realtimeSessionControllerProvider(request).notifier,
                        )
                        .submitReply(text)
                        .then((_) => _maybeShowResult(lesson, request));
                  },
                  onEndSession: () =>
                      _finishLesson(lesson, request, early: true),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 全部轮次完成后自动出结果。
  Future<void> _maybeShowResult(
    Lesson lesson,
    RealtimeSessionRequest request,
  ) async {
    final RealtimeSessionState state =
        ref.read(realtimeSessionControllerProvider(request));
    // 脚本轮数 == 步数；turnScores 齐了就算完成。
    if (state.turnScores.length >= lesson.steps.length &&
        !state.turnScores.any((int s) => s < 0) &&
        !_finished) {
      _finished = true;
      await _finishLesson(lesson, request);
    }
  }

  Future<void> _finishLesson(
    Lesson lesson,
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

    final List<int> stepScores = state.turnScores;
    final List<String> weakWords =
        report.weakWords.map((WeakWordRecord w) => w.word).toList();
    final bool passed =
        early ? false : stepScores.every((int s) => s >= 60);

    // 记录统计（真实评分在服务接通后替换）。
    await recordFinishedSession(
      ref,
      feature: '学一学',
      durationSeconds: report.durationSeconds,
      speakingTurns: report.childTurns,
      pronunciationScore: report.pronunciationScore,
      fluencyScore: report.fluencyScore,
      weakWords: weakWords,
    );

    // 通过则解锁下一课。
    if (passed) {
      await ref.read(learningProgressProvider.notifier).completeLesson(
            LessonResult(
              lessonId: lesson.id,
              score: report.overallScore,
              stepScores: stepScores,
              weakWords: weakWords,
            ),
          );
    }

    if (mounted) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) => _LessonResultDialog(
          lesson: lesson,
          passed: passed,
          early: early,
          score: report.overallScore,
          stepScores: stepScores,
          weakWords: weakWords,
          encouragement: report.encouragement,
        ),
      );
      if (mounted) {
        context.go('/learning');
      }
    }
  }
}

class _StepProgressHeader extends StatelessWidget {
  const _StepProgressHeader({required this.lesson, required this.state});

  final Lesson lesson;
  final RealtimeSessionState state;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: ContentCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            const Text(
              '任务进度',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Row(
                children: [
                  for (int i = 0; i < lesson.steps.length; i++)
                    Expanded(
                      child: Container(
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: i < state.turnScores.length
                              ? (state.turnScores[i] >= 60
                                  ? AppColors.success
                                  : AppColors.warning)
                              : AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${state.turnScores.where((int s) => s >= 60).length}/${lesson.steps.length}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LessonResultDialog extends StatelessWidget {
  const _LessonResultDialog({
    required this.lesson,
    required this.passed,
    required this.early,
    required this.score,
    required this.stepScores,
    required this.weakWords,
    required this.encouragement,
  });

  final Lesson lesson;
  final bool passed;
  final bool early;
  final int score;
  final List<int> stepScores;
  final List<String> weakWords;
  final String encouragement;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Text(passed ? '🎉' : '💪', style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 8),
          Text(passed ? '通关成功！' : '再试一次吧'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('课程：${lesson.title}'),
          const SizedBox(height: 8),
          Text(
            early
                ? '本次提前结束，不计入通关。'
                : '每步得分：${stepScores.join(' / ')}，综合 $score 分',
          ),
          if (weakWords.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '可以再练练：${weakWords.toSet().join('、')}',
              style: const TextStyle(color: AppColors.warning),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            encouragement,
            style: const TextStyle(color: AppColors.success),
          ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(passed ? '继续闯关' : '回地图'),
        ),
      ],
    );
  }
}
