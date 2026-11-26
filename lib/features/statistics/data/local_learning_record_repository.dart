import 'dart:convert';

import '../../../core/services/local_store.dart';
import '../domain/learning_record_repository.dart';
import '../models/learning_stats.dart';

/// 本机学习记录实现：JSON 列表存于 shared_preferences。
/// 记录数有上限（防止无限增长），聚合口径以"天"为单位。
final class LocalLearningRecordRepository implements LearningRecordRepository {
  LocalLearningRecordRepository(this._store);

  static const String _storageKey = 'saypal.statistics.records';
  static const int _maxRecords = 500;

  final LocalStore _store;

  @override
  Future<void> recordSession(SessionLearningRecord record) async {
    final List<SessionLearningRecord> records =
        List<SessionLearningRecord>.of(await loadAllRecords());
    records.add(record);
    // 保留最近的记录。
    final List<SessionLearningRecord> trimmed = records.length > _maxRecords
        ? records.sublist(records.length - _maxRecords)
        : records;
    await _store.setString(
      _storageKey,
      jsonEncode(trimmed.map((SessionLearningRecord r) => r.toJson()).toList()),
    );
  }

  @override
  Future<List<SessionLearningRecord>> loadAllRecords() async {
    final List<dynamic>? raw = await _store.getJsonList(_storageKey);
    if (raw == null) {
      return const <SessionLearningRecord>[];
    }
    return raw
        .map(
          (dynamic item) => SessionLearningRecord.fromJson(
            item as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  @override
  Future<StatisticsSummary> loadLast7Days() async {
    final List<SessionLearningRecord> records = await loadAllRecords();
    final DateTime today = DateTime.now();
    final DateTime todayStart = DateTime(today.year, today.month, today.day);

    final List<DailyLearningStats> days = <DailyLearningStats>[];
    final Map<int, List<String>> weakWordsByDayIndex = <int, List<String>>{};

    for (int i = 6; i >= 0; i--) {
      final DateTime dayStart = todayStart.subtract(Duration(days: i));
      final List<SessionLearningRecord> dayRecords = records
          .where(
            (SessionLearningRecord r) => _sameDay(r.finishedAt, dayStart),
          )
          .toList();

      final int minutes = dayRecords.fold<int>(
        0,
        (int sum, SessionLearningRecord r) =>
            sum + (r.durationSeconds / 60).round(),
      );
      final int speakingCount = dayRecords.fold<int>(
        0,
        (int sum, SessionLearningRecord r) => sum + r.speakingTurns,
      );

      int averageOf(List<int> Function(SessionLearningRecord) pick) {
        final List<int> values = <int>[];
        for (final SessionLearningRecord record in dayRecords) {
          final List<int> picked = pick(record);
          values.addAll(picked);
        }
        if (values.isEmpty) {
          return 0;
        }
        return values.reduce((int a, int b) => a + b) ~/ values.length;
      }

      days.add(
        DailyLearningStats(
          date: dayStart,
          minutes: minutes,
          speakingCount: speakingCount,
          pronunciationScore: averageOf(
            (SessionLearningRecord r) => r.pronunciationScore > 0
                ? <int>[r.pronunciationScore]
                : <int>[],
          ),
          fluencyScore: averageOf(
            (SessionLearningRecord r) =>
                r.fluencyScore > 0 ? <int>[r.fluencyScore] : <int>[],
          ),
        ),
      );
      weakWordsByDayIndex[i] = dayRecords
          .expand((SessionLearningRecord r) => r.weakWords)
          .toList();
    }

    // 薄弱词：近 7 天按出现次数聚合，取 Top 8。
    final Map<String, int> counts = <String, int>{};
    for (final List<String> words in weakWordsByDayIndex.values) {
      for (final String word in words) {
        counts[word] = (counts[word] ?? 0) + 1;
      }
    }
    final List<WeakWordStat> weakWords = counts.entries
        .map((MapEntry<String, int> e) => WeakWordStat(word: e.key, count: e.value))
        .toList()
      ..sort((WeakWordStat a, WeakWordStat b) => b.count.compareTo(a.count));

    return StatisticsSummary(
      days: days,
      totalMinutes: days.fold<int>(0, (int s, DailyLearningStats d) => s + d.minutes),
      totalSpeakingCount:
          days.fold<int>(0, (int s, DailyLearningStats d) => s + d.speakingCount),
      weakWords: weakWords.take(8).toList(),
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
