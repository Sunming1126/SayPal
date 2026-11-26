import 'package:flutter/material.dart';

/// 生活情景。
class LifeScenario {
  const LifeScenario({
    required this.id,
    required this.title,
    required this.emoji,
    required this.color,
    required this.introZh,
    required this.tasks,
  });

  final String id;
  final String title;
  final String emoji;
  final Color color;

  /// 进入前展示的场景介绍。
  final String introZh;

  /// 需要在对话中完成的任务（按顺序）。
  final List<ScenarioTask> tasks;
}

/// 情景任务。
class ScenarioTask {
  const ScenarioTask({
    required this.id,
    required this.titleZh,
    required this.aiTextEn,
    required this.aiTextZh,
    required this.suggestions,
    required this.keywords,
  });

  final String id;
  final String titleZh;

  /// AI 在该任务阶段的台词。
  final String aiTextEn;
  final String aiTextZh;
  final List<String> suggestions;
  final List<String> keywords;
}
