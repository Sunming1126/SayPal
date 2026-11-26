import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/local_store.dart';
import '../../realtime/domain/realtime_tutor_repository.dart';
import '../data/seed_learning.dart';
import '../models/learning_models.dart';

/// 已完成课程 id 集合（本机持久化）。
/// 解锁规则：场景按列表顺序解锁；场景内课程按顺序解锁。
final class LearningProgressController
    extends AutoDisposeAsyncNotifier<Set<String>> {
  static const String _storageKey = 'saypal.learning.completed';

  LocalStore get _store => ref.read(localStoreProvider);

  @override
  Future<Set<String>> build() async {
    final Map<String, dynamic>? raw = await _store.getJson(_storageKey);
    if (raw == null) {
      return const <String>{};
    }
    return Set<String>.from(raw['completedLessons'] as List<dynamic>);
  }

  Future<void> _persist(Set<String> completed) async {
    await _store.setJson(_storageKey, {
      'completedLessons': completed.toList(),
    });
  }

  /// 课程是否解锁（第一个场景的第一课永远解锁）。
  bool isUnlocked(String lessonId) {
    final List<Lesson> flatLessons = <Lesson>[
      for (final LearningScene scene in kSeedLearningScenes) ...scene.lessons,
    ];
    final int index = flatLessons.indexWhere(
      (Lesson l) => l.id == lessonId,
    );
    if (index <= 0) {
      return true;
    }
    final Set<String>? completed = state.value;
    return completed?.contains(flatLessons[index - 1].id) ?? false;
  }

  /// 场景是否解锁（第一个场景永远解锁；完成前一场景全部课程后解锁下一个）。
  bool isSceneUnlocked(String sceneId) {
    final int index = kSeedLearningScenes.indexWhere(
      (LearningScene s) => s.id == sceneId,
    );
    if (index <= 0) {
      return true;
    }
    final LearningScene previous = kSeedLearningScenes[index - 1];
    final Set<String>? completed = state.value;
    if (completed == null) {
      return false;
    }
    return previous.lessons.every(
      (Lesson lesson) => completed.contains(lesson.id),
    );
  }

  /// 记录课程完成，返回本次成绩。
  Future<void> completeLesson(LessonResult result) async {
    final Set<String> completed =
        Set<String>.of(state.value ?? const <String>{});
    completed.add(result.lessonId);
    await _persist(completed);
    state = AsyncData(completed);
  }
}

final learningProgressProvider =
    AsyncNotifierProvider.autoDispose<LearningProgressController, Set<String>>(
  LearningProgressController.new,
);

/// 按 id 找课程。
Lesson? findLesson(String lessonId) {
  for (final LearningScene scene in kSeedLearningScenes) {
    for (final Lesson lesson in scene.lessons) {
      if (lesson.id == lessonId) {
        return lesson;
      }
    }
  }
  return null;
}

/// 按 id 找所属场景。
LearningScene? findSceneOfLesson(String lessonId) {
  for (final LearningScene scene in kSeedLearningScenes) {
    if (scene.lessons.any((Lesson l) => l.id == lessonId)) {
      return scene;
    }
  }
  return null;
}

/// 根据真实完成记录找到下一节应继续的课；全部完成时返回 null。
Lesson? nextLearningLesson(Set<String> completed) {
  for (final LearningScene scene in kSeedLearningScenes) {
    for (final Lesson lesson in scene.lessons) {
      if (!completed.contains(lesson.id)) return lesson;
    }
  }
  return null;
}

/// 课程 → 会话请求的转换（封面页与练习页共用）。
RealtimeSessionRequest lessonSessionRequest(String lessonId) {
  final Lesson? lesson = findLesson(lessonId);
  if (lesson == null) {
    throw ArgumentError('Unknown lesson: $lessonId');
  }
  final LearningScene? scene = findSceneOfLesson(lesson.id);
  return RealtimeSessionRequest(
    sessionId: 'lesson-${lesson.id}',
    tutorName: scene?.title ?? '老师',
    tutorPersonaPrompt: '你是一位小学英语课堂老师，正在上《${lesson.title}》。',
    script: lesson.steps
        .map(
          (LessonStep step) => DemoScriptTurn(
            aiTextEn: step.aiTextEn,
            aiTextZh: step.aiTextZh,
            suggestions: step.suggestions,
            keywords: step.keywords,
            taskId: lesson.id,
          ),
        )
        .toList(),
  );
}
