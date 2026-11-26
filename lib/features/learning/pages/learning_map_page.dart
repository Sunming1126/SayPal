import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/adventure_widgets.dart';
import '../../../core/widgets/common_widgets.dart';
import '../data/seed_learning.dart';
import '../models/learning_models.dart';
import '../providers/learning_providers.dart';
import '../widgets/theme_course_catalog.dart';

/// 学一学：地图式课程陪练。完成当前场景全部课程后解锁下一个场景。
class LearningMapPage extends ConsumerWidget {
  const LearningMapPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool showTheme =
        GoRouterState.of(context).uri.queryParameters['tab'] == 'theme';
    final AsyncValue<Set<String>> progress =
        ref.watch(learningProgressProvider);

    return Scaffold(
      body: Column(
        children: <Widget>[
          CompactAdventureHeader(
            title: '学一学',
            subtitle: '每完成一课，就离下一站更近一点',
            trailing: CompactHeaderAction(
              icon: Icons.menu_book_rounded,
              label: '单词本',
              onPressed: () => context.push('/vocabulary'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _LearningTabs(
              selectedIndex: showTheme ? 1 : 0,
              onSelected: (int index) => context.go(
                index == 0 ? '/learning' : '/learning?tab=theme',
              ),
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: showTheme ? 1 : 0,
              children: <Widget>[
                _LearningMapContent(progress: progress),
                const ThemeCourseCatalog(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LearningTabs extends StatelessWidget {
  const _LearningTabs({required this.selectedIndex, required this.onSelected});

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => SegmentedButton<int>(
        segments: const <ButtonSegment<int>>[
          ButtonSegment<int>(
            value: 0,
            icon: Icon(Icons.route_rounded),
            label: Text('闯关课'),
          ),
          ButtonSegment<int>(
            value: 1,
            icon: Icon(Icons.auto_stories_rounded),
            label: Text('主题课'),
          ),
        ],
        selected: <int>{selectedIndex},
        showSelectedIcon: false,
        onSelectionChanged: (Set<int> value) => onSelected(value.first),
        style: ButtonStyle(
          minimumSize: WidgetStateProperty.all(const Size(48, 48)),
          textStyle: WidgetStateProperty.all(
            const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      );
}

class _LearningMapContent extends ConsumerWidget {
  const _LearningMapContent({required this.progress});

  final AsyncValue<Set<String>> progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) => progress.when(
        loading: () => const LoadingView(),
        error: (Object e, StackTrace s) => ErrorStateView(
          title: '地图打不开啦',
          message: '请稍后再试一次。',
          onRetry: () => ref.invalidate(learningProgressProvider),
        ),
        data: (Set<String> completed) {
          final Lesson? next = nextLearningLesson(completed);
          return ListView(
            key: const PageStorageKey<String>('learning-map-list'),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: <Widget>[
              _ContinueLearningCard(lesson: next),
              const SizedBox(height: 14),
              const Text(
                '完成一关，就能解锁下一关！跟着小老师一起闯关吧～',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              for (final LearningScene scene
                  in kSeedLearningScenes) ...<Widget>[
                _SceneSection(
                  scene: scene,
                  sceneUnlocked: ref
                      .read(learningProgressProvider.notifier)
                      .isSceneUnlocked(scene.id),
                  completed: completed,
                ),
                const SizedBox(height: 18),
              ],
            ],
          );
        },
      );
}

class _ContinueLearningCard extends StatelessWidget {
  const _ContinueLearningCard({required this.lesson});

  final Lesson? lesson;

  @override
  Widget build(BuildContext context) => PressScaleCard(
        onTap: lesson == null
            ? null
            : () => context.push('/learning/lesson/${lesson!.id}'),
        borderRadius: 20,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: lesson == null ? AppColors.mint : AppColors.primarySoft,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                lesson == null ? Icons.verified_rounded : Icons.play_circle,
                color:
                    lesson == null ? AppColors.mintStrong : AppColors.primary,
                size: 30,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      lesson == null ? '闯关课全部完成啦' : '继续学习',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      lesson?.title ?? '你已经走完了当前学习地图',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (lesson != null)
                const Icon(Icons.arrow_forward_rounded,
                    color: AppColors.primary),
            ],
          ),
        ),
      );
}

class _SceneSection extends ConsumerWidget {
  const _SceneSection({
    required this.scene,
    required this.sceneUnlocked,
    required this.completed,
  });

  final LearningScene scene;
  final bool sceneUnlocked;
  final Set<String> completed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.warmOutline),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: sceneUnlocked
                      ? scene.color.withValues(alpha: .14)
                      : AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  _sceneIcon(scene.id),
                  color: sceneUnlocked ? scene.color : AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                scene.title,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              if (!sceneUnlocked)
                const Icon(
                  Icons.lock_outline_rounded,
                  size: 22,
                  color: AppColors.textSecondary,
                ),
            ],
          ),
          if (!sceneUnlocked)
            const Padding(
              padding: EdgeInsets.only(left: 60, top: 2),
              child: Text(
                '完成上一个场景后解锁',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          const SizedBox(height: 10),
          for (final Lesson lesson in scene.lessons)
            _LessonCard(
              scene: scene,
              lesson: lesson,
              unlocked: sceneUnlocked &&
                  ref
                      .read(learningProgressProvider.notifier)
                      .isUnlocked(lesson.id),
              completed: completed.contains(lesson.id),
            ),
        ],
      ),
    );
  }

  IconData _sceneIcon(String id) {
    if (id.contains('campus')) return Icons.school_rounded;
    if (id.contains('restaurant')) return Icons.restaurant_rounded;
    return Icons.directions_bus_rounded;
  }
}

class _LessonCard extends StatelessWidget {
  const _LessonCard({
    required this.scene,
    required this.lesson,
    required this.unlocked,
    required this.completed,
  });

  final LearningScene scene;
  final Lesson lesson;
  final bool unlocked;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    final Color tint = unlocked ? scene.color : AppColors.outline;
    final String status = completed
        ? '已完成'
        : unlocked
            ? '现在可学'
            : '未解锁';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PressScaleCard(
        onTap: unlocked
            ? () => context.push('/learning/lesson/${lesson.id}')
            : null,
        borderRadius: 20,
        child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: completed
                  ? AppColors.mint.withValues(alpha: .65)
                  : unlocked
                      ? AppColors.surfaceMuted
                      : const Color(0xFFF1F2F5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 50,
                  height: 50,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: unlocked ? 0.14 : 0.3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    completed
                        ? Icons.check_rounded
                        : unlocked
                            ? Icons.play_arrow_rounded
                            : Icons.lock_rounded,
                    color: completed
                        ? AppColors.mintStrong
                        : unlocked
                            ? scene.color
                            : AppColors.textSecondary,
                    size: 27,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              lesson.title,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: unlocked
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        lesson.descriptionZh,
                        style: TextStyle(
                          fontSize: 13,
                          color: unlocked
                              ? AppColors.textSecondary
                              : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        status,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: completed
                              ? AppColors.mintStrong
                              : unlocked
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  unlocked ? Icons.chevron_right_rounded : Icons.lock_outline,
                  color: AppColors.textSecondary,
                ),
              ],
            )),
      ),
    );
  }
}
