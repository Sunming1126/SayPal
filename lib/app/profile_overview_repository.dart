import '../features/profile/domain/profile_overview_repository.dart';
import '../features/profile/models/profile_overview.dart';
import '../features/statistics/domain/learning_record_repository.dart';
import '../features/scenario/data/roleplay_favorites_repository.dart';
import '../features/vocabulary/domain/vocabulary_repository.dart';

/// App 层组合统计与生词数据，Profile feature 不直接依赖其他 feature。
final class AppProfileOverviewRepository implements ProfileOverviewRepository {
  AppProfileOverviewRepository(this._learning, this._vocabulary, [this._favorites]);

  final RoleplayFavoritesRepository? _favorites;

  final LearningRecordRepository _learning;
  final VocabularyRepository _vocabulary;

  @override
  Future<ProfileOverview> load() async {
    final summaryFuture = _learning.loadLast7Days();
    final recordsFuture = _learning.loadAllRecords();
    final wordsFuture = _vocabulary.loadWords();
    final favoritesFuture = _favorites?.load();
    final summary = await summaryFuture;
    final records = await recordsFuture;
    final words = await wordsFuture;
    return ProfileOverview(
      totalMinutes: summary.totalMinutes,
      speakingCount: summary.totalSpeakingCount,
      vocabularyCount: words.length,
      favoriteCount: (await favoritesFuture)?.length ?? 0,
      conversationCount: records
          .where((record) => record.feature.startsWith('聊一聊'))
          .length,
      roleplayCount: records
          .where((record) => record.feature == '角色扮演' || record.feature == '情景扮演')
          .length,
    );
  }
}
