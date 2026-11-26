import 'package:flutter/material.dart';

/// 学习场景（地图上的"站点"）。
class LearningScene {
  const LearningScene({
    required this.id,
    required this.title,
    required this.emoji,
    required this.color,
    required this.lessons,
  });

  final String id;
  final String title;
  final String emoji;
  final Color color;
  final List<Lesson> lessons;
}

/// 一节课：封面 + AI 提问链。
class Lesson {
  const Lesson({
    required this.id,
    required this.title,
    required this.coverEmoji,
    required this.descriptionZh,
    required this.steps,
  });

  final String id;
  final String title;
  final String coverEmoji;
  final String descriptionZh;
  final List<LessonStep> steps;
}

/// 课程中的一步：AI 提问 → 期望回答（含关键词）。
class LessonStep {
  const LessonStep({
    required this.aiTextEn,
    required this.aiTextZh,
    required this.suggestions,
    required this.keywords,
  });

  final String aiTextEn;
  final String aiTextZh;
  final List<String> suggestions;
  final List<String> keywords;
}

/// 课程完成后的结果。
class LessonResult {
  const LessonResult({
    required this.lessonId,
    required this.score,
    required this.stepScores,
    required this.weakWords,
  });

  final String lessonId;
  final int score;
  final List<int> stepScores;
  final List<String> weakWords;
}
