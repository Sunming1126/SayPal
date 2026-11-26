/// 生词本中的词条。
class VocabWord {
  const VocabWord({
    required this.word,
    required this.meaningZh,
    this.phonetic,
    this.exampleEn,
    this.exampleZh,
    required this.addedAt,
    this.source,
  });

  final String word;
  final String meaningZh;
  final String? phonetic;
  final String? exampleEn;
  final String? exampleZh;
  final DateTime addedAt;

  /// 来源（如"聊一聊"/"学一学"/"角色扮演"）。
  final String? source;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'word': word,
        'meaningZh': meaningZh,
        if (phonetic != null) 'phonetic': phonetic,
        if (exampleEn != null) 'exampleEn': exampleEn,
        if (exampleZh != null) 'exampleZh': exampleZh,
        'addedAt': addedAt.millisecondsSinceEpoch,
        if (source != null) 'source': source,
      };

  static VocabWord fromJson(Map<String, dynamic> json) => VocabWord(
        word: json['word'] as String,
        meaningZh: json['meaningZh'] as String,
        phonetic: json['phonetic'] as String?,
        exampleEn: json['exampleEn'] as String?,
        exampleZh: json['exampleZh'] as String?,
        addedAt: DateTime.fromMillisecondsSinceEpoch(json['addedAt'] as int),
        source: json['source'] as String?,
      );
}

/// 查词结果（演示词典返回；未收录时为 null）。
class WordLookupResult {
  const WordLookupResult({
    required this.word,
    required this.meaningZh,
    this.phonetic,
    this.exampleEn,
    this.exampleZh,
  });

  final String word;
  final String meaningZh;
  final String? phonetic;
  final String? exampleEn;
  final String? exampleZh;
}
