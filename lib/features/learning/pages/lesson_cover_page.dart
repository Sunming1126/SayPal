import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../models/learning_models.dart';
import '../providers/learning_providers.dart' show findLesson, learningProgressProvider;

/// 课程封面：展示课程信息与"开始"主操作。
class LessonCoverPage extends ConsumerWidget {
  const LessonCoverPage({required this.lessonId, super.key});

  final String lessonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Lesson? lesson = findLesson(lessonId);
    if (lesson == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('课程')),
        body: const ErrorStateView(
          title: '没有找到这门课',
          message: '课程可能已下架，回地图看看其他课程吧。',
        ),
      );
    }
    final bool unlocked =
        ref.read(learningProgressProvider.notifier).isUnlocked(lessonId);
    if (!unlocked) {
      return Scaffold(
        appBar: AppBar(title: Text(lesson.title)),
        body: const EmptyStateView(
          emoji: '🔒',
          title: '这关还没解锁',
          message: '先完成前面的课程，再来挑战吧！',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(lesson.title)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Center(
                child: Container(
                  width: 120,
                  height: 120,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    lesson.coverEmoji,
                    style: const TextStyle(fontSize: 64),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                lesson.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                lesson.descriptionZh,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '共 ${lesson.steps.length} 个小任务',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              PrimaryActionButton(
                label: '开始学习',
                icon: Icons.play_arrow_rounded,
                onPressed: () =>
                    context.pushReplacement('/learning/lesson/$lessonId/play'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
