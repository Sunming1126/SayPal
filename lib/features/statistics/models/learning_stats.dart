/// 一次学习会话结束后的记录（由各会话场景通过仓库接口写入）。
class SessionLearningRecord {
  const SessionLearningRecord({
    required this.finishedAt,
    required this.feature,
    required this.durationSeconds,
    required this.speakingTurns,
    required this.pronunciationScore,
    required this.fluencyScore,
    this.contentId,
    this.weakWords = const <String>[],
  });

  final DateTime finishedAt;

  /// 来源功能名：聊一聊 / 学一学 / 角色扮演。
  final String feature;
  final int durationSeconds;
  final int speakingTurns;
  final int pronunciationScore;
  final int fluencyScore;
  final String? contentId;

  /// 本次暴露的薄弱词。
  final List<String> weakWords;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'finishedAt': finishedAt.millisecondsSinceEpoch,
        'feature': feature,
        'durationSeconds': durationSeconds,
        'speakingTurns': speakingTurns,
        'pronunciationScore': pronunciationScore,
      'fluencyScore': fluencyScore,
      if (contentId != null) 'contentId': contentId,
        'weakWords': weakWords,
      };

  static SessionLearningRecord fromJson(Map<String, dynamic> json) =>
      SessionLearningRecord(
        finishedAt:
            DateTime.fromMillisecondsSinceEpoch(json['finishedAt'] as int),
        feature: json['feature'] as String,
        durationSeconds: json['durationSeconds'] as int,
        speakingTurns: json['speakingTurns'] as int,
        pronunciationScore: json['pronunciationScore'] as int,
        fluencyScore: json['fluencyScore'] as int,
        contentId: json['contentId'] as String?,
        weakWords:
            (json['weakWords'] as List<dynamic>? ?? <dynamic>[]).cast<String>(),
      );
}

/// 单日聚合统计。
class DailyLearningStats {
  const DailyLearningStats({
    required this.date,
    required this.minutes,
    required this.speakingCount,
    required this.pronunciationScore,
    required this.fluencyScore,
  });

  /// 当天零点。
  final DateTime date;
  final int minutes;
  final int speakingCount;
  final int pronunciationScore;
  final int fluencyScore;

  String get weekdayZh =>
      const ['周一', '周二', '周三', '周四', '周五', '周六', '周日'][date.weekday - 1];
}

/// 近 7 天统计汇总。
class StatisticsSummary {
  const StatisticsSummary({
    required this.days,
    required this.totalMinutes,
    required this.totalSpeakingCount,
    required this.weakWords,
  });

  final List<DailyLearningStats> days;
  final int totalMinutes;
  final int totalSpeakingCount;
  final List<WeakWordStat> weakWords;
}

/// 薄弱词统计。
class WeakWordStat {
  const WeakWordStat({required this.word, required this.count});

  final String word;
  final int count;
}
