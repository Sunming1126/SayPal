import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/local_store.dart';
import '../data/local_vocabulary_repository.dart';
import '../data/seed_dictionary.dart';
import '../domain/vocabulary_repository.dart';
import '../models/vocab_models.dart';

final vocabularyRepositoryProvider = Provider<VocabularyRepository>((ref) {
  return LocalVocabularyRepository(ref.watch(localStoreProvider));
});

final wordLookupServiceProvider = Provider<WordLookupService>((ref) {
  return SeedWordDictionary();
});

/// 生词本列表状态。
final class VocabularyListController
    extends AutoDisposeAsyncNotifier<List<VocabWord>> {
  @override
  Future<List<VocabWord>> build() =>
      ref.watch(vocabularyRepositoryProvider).loadWords();

  Future<void> addWord(VocabWord word) async {
    await ref.read(vocabularyRepositoryProvider).saveWord(word);
    state = await AsyncValue.guard(
      () => ref.read(vocabularyRepositoryProvider).loadWords(),
    );
  }

  Future<void> removeWord(String word) async {
    await ref.read(vocabularyRepositoryProvider).removeWord(word);
    state = await AsyncValue.guard(
      () => ref.read(vocabularyRepositoryProvider).loadWords(),
    );
  }
}

final vocabularyListProvider =
    AsyncNotifierProvider.autoDispose<VocabularyListController,
        List<VocabWord>>(VocabularyListController.new);

/// 保存生词并弹出轻提示的统一入口（供三个会话场景共用）。
Future<bool> saveVocabWord(
  WidgetRef ref, {
  required String word,
  required String meaningZh,
  String? phonetic,
  String? exampleEn,
  String? exampleZh,
  required String source,
}) async {
  await ref.read(vocabularyListProvider.notifier).addWord(
        VocabWord(
          word: word.toLowerCase().trim(),
          meaningZh: meaningZh,
          phonetic: phonetic,
          exampleEn: exampleEn,
          exampleZh: exampleZh,
          addedAt: DateTime.now(),
          source: source,
        ),
      );
  return true;
}
