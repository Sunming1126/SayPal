import '../models/vocab_models.dart';

/// 生词本仓库接口。其他 feature 只依赖该接口，不触碰持久化细节。
abstract interface class VocabularyRepository {
  /// 当前生词（按加入时间倒序）。
  Future<List<VocabWord>> loadWords();

  /// 保存生词（已存在则更新释义，返回是否新增）。
  Future<bool> saveWord(VocabWord word);

  /// 删除生词。
  Future<void> removeWord(String word);

  /// 是否已收藏该词。
  Future<bool> isSaved(String word);
}

/// 点词释义服务接口。
abstract interface class WordLookupService {
  /// 查询释义；演示词典未收录时返回 null。
  WordLookupResult? lookup(String word);
}
