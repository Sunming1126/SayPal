import '../models/learning_stats.dart';

/// 学习记录仓库接口。
/// 聊一聊 / 学一学 / 角色扮演结束会话后通过该接口写入记录，
/// "我的"页面通过它读取聚合统计。
abstract interface class LearningRecordRepository {
  Future<void> recordSession(SessionLearningRecord record);

  Future<StatisticsSummary> loadLast7Days();

  /// 只读原始记录（测试与调试用）。
  Future<List<SessionLearningRecord>> loadAllRecords();
}
