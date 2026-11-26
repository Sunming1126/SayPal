import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/local_store.dart';
import '../data/theme_course_repository.dart';
import '../models/theme_course.dart';

final themeCourseRepositoryProvider = Provider<ThemeCourseRepository>(
  (Ref ref) => ThemeCourseRepository(),
);

final themeCoursesProvider = FutureProvider<List<ThemeCourse>>(
  (Ref ref) => ref.watch(themeCourseRepositoryProvider).loadCourses(),
);

final class ThemeCourseProgressController
    extends AutoDisposeAsyncNotifier<Set<String>> {
  static const String _storageKey = 'saypal.learning.theme.completed';

  @override
  Future<Set<String>> build() async {
    final Map<String, dynamic>? raw =
        await ref.read(localStoreProvider).getJson(_storageKey);
    if (raw == null) return const <String>{};
    return Set<String>.from(raw['completedCourseIds'] as List<dynamic>);
  }

  Future<void> completeCourse(String courseId) async {
    final Set<String> completed = Set<String>.of(
      state.value ?? const <String>{},
    )..add(courseId);
    await ref.read(localStoreProvider).setJson(
      _storageKey,
      <String, dynamic>{'completedCourseIds': completed.toList()},
    );
    state = AsyncData<Set<String>>(completed);
  }
}

final themeCourseProgressProvider = AsyncNotifierProvider.autoDispose<
    ThemeCourseProgressController, Set<String>>(
  ThemeCourseProgressController.new,
);
