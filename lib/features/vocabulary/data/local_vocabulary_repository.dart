import 'dart:convert';

import '../../../core/services/local_store.dart';
import '../domain/vocabulary_repository.dart';
import '../models/vocab_models.dart';

/// 基于本机存储的生词本实现（MVP 不上云）。
final class LocalVocabularyRepository implements VocabularyRepository {
  LocalVocabularyRepository(this._store);

  static const String _storageKey = 'saypal.vocabulary.words';

  final LocalStore _store;

  @override
  Future<List<VocabWord>> loadWords() async {
    final List<dynamic>? raw = await _store.getJsonList(_storageKey);
    if (raw == null) {
      return const <VocabWord>[];
    }
    final List<VocabWord> words = raw
        .map(
          (dynamic item) =>
              VocabWord.fromJson((item as Map<String, dynamic>)),
        )
        .toList();
    words.sort((VocabWord a, VocabWord b) => b.addedAt.compareTo(a.addedAt));
    return words;
  }

  @override
  Future<bool> saveWord(VocabWord word) async {
    final List<VocabWord> words = await loadWords();
    final bool existed = words.any(
      (VocabWord w) => w.word.toLowerCase() == word.word.toLowerCase(),
    );
    final List<VocabWord> next = existed
        ? words
            .map(
              (VocabWord w) => w.word.toLowerCase() == word.word.toLowerCase()
                  ? word
                  : w,
            )
            .toList()
        : [...words, word];
    await _writeAll(next);
    return !existed;
  }

  @override
  Future<void> removeWord(String word) async {
    final List<VocabWord> words = await loadWords();
    await _writeAll(
      words
          .where(
            (VocabWord w) => w.word.toLowerCase() != word.toLowerCase().trim(),
          )
          .toList(),
    );
  }

  @override
  Future<bool> isSaved(String word) async {
    final List<VocabWord> words = await loadWords();
    return words.any(
      (VocabWord w) => w.word.toLowerCase() == word.toLowerCase().trim(),
    );
  }

  Future<void> _writeAll(List<VocabWord> words) async {
    await _store.setString(
      _storageKey,
      jsonEncode(words.map((VocabWord w) => w.toJson()).toList()),
    );
  }
}
