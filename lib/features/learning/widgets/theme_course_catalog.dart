import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/adventure_widgets.dart';
import '../../../core/widgets/common_widgets.dart';
import '../models/theme_course.dart';
import '../providers/theme_course_providers.dart';

class ThemeCourseCatalog extends ConsumerWidget {
  const ThemeCourseCatalog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<ThemeCourse>> courses =
        ref.watch(themeCoursesProvider);
    final Set<String> completed =
        ref.watch(themeCourseProgressProvider).valueOrNull ?? const <String>{};
    return courses.when(
      loading: () => const LoadingView(),
      error: (_, __) => ErrorStateView(
        title: '主题课加载失败',
        message: '请稍后再试一次。',
        onRetry: () => ref.invalidate(themeCoursesProvider),
      ),
      data: (List<ThemeCourse> items) => ListView(
        key: const PageStorageKey<String>('theme-course-list'),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: <Widget>[
          const Text(
            '先认识单词和重点表达，视频准备好后再跟着小蓝练习。',
            style: TextStyle(
              fontSize: 14,
              height: 1.45,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          for (final ThemeCourse course in items)
            _ThemeCourseCard(
              course: course,
              completed: completed.contains(course.id),
              onTap: () => context.push('/learning/theme/${course.id}'),
            ),
        ],
      ),
    );
  }
}

class _ThemeCourseCard extends StatelessWidget {
  const _ThemeCourseCard({
    required this.course,
    required this.completed,
    required this.onTap,
  });

  final ThemeCourse course;
  final bool completed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String status = completed
        ? '已完成'
        : course.videoReady
            ? '观看视频开始'
            : '视频准备中 · 可以先预习';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PressScaleCard(
        onTap: onTap,
        borderRadius: 24,
        child: Container(
          constraints: const BoxConstraints(minHeight: 126),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.warmOutline),
            boxShadow: AppColors.softShadow,
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 76,
                height: 88,
                decoration: BoxDecoration(
                  color: completed ? AppColors.mint : AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  completed ? Icons.check_rounded : _themeIcon(course.icon),
                  size: 38,
                  color: completed ? AppColors.mintStrong : AppColors.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      course.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      course.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      status,
                      style: TextStyle(
                        color: completed
                            ? AppColors.mintStrong
                            : AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

IconData _themeIcon(String name) => switch (name) {
      'family_restroom' => Icons.family_restroom_rounded,
      'pets' => Icons.pets_rounded,
      'wb_sunny' => Icons.wb_sunny_rounded,
      _ => Icons.auto_stories_rounded,
    };
