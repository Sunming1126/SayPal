import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/local_store.dart';
import '../data/local_learning_record_repository.dart';
import '../domain/learning_record_repository.dart';
import '../models/learning_stats.dart';

final learningRecordRepositoryProvider = Provider<LearningRecordRepository>(
  (ref) => LocalLearningRecordRepository(ref.watch(localStoreProvider)),
);

/// 近 7 日统计聚合。
final statisticsSummaryProvider =
    FutureProvider.autoDispose<StatisticsSummary>((ref) async {
  return ref.watch(learningRecordRepositoryProvider).loadLast7Days();
});

/// 会话结束时写入一条学习记录的统一入口。
Future<void> recordFinishedSession(
  WidgetRef ref, {
  required String feature,
  required int durationSeconds,
  required int speakingTurns,
  required int pronunciationScore,
  required int fluencyScore,
  List<String> weakWords = const <String>[],
}) async {
  final LearningRecordRepository repository =
      ref.read(learningRecordRepositoryProvider);
  await repository.recordSession(
    SessionLearningRecord(
      finishedAt: DateTime.now(),
      feature: feature,
      durationSeconds: durationSeconds,
      speakingTurns: speakingTurns,
      pronunciationScore: pronunciationScore,
      fluencyScore: fluencyScore,
      weakWords: weakWords,
    ),
  );
}
