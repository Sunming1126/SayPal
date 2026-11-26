/// 会话里的字幕/消息条目。
class TranscriptEntry {
  const TranscriptEntry({
    required this.id,
    required this.speaker,
    required this.text,
    this.zhHint,
    this.createdAt,
  });

  final String id;
  final TranscriptSpeaker speaker;
  final String text;

  /// 中文提示（演示链路直接给出；真实链路可由服务端字幕/翻译补充）。
  final String? zhHint;
  final DateTime? createdAt;

  TranscriptEntry copyWith({String? zhHint}) => TranscriptEntry(
        id: id,
        speaker: speaker,
        text: text,
        zhHint: zhHint ?? this.zhHint,
        createdAt: createdAt,
      );
}

enum TranscriptSpeaker { ai, child }

/// 单个薄弱词的评分记录。
class WeakWordRecord {
  const WeakWordRecord({required this.word, required this.reason});

  final String word;
  final String reason;
}

/// 会话结束后的口语报告（真实链路来自服务端报告接口，
/// 演示链路由演示仓库按规则合成）。
class TutorReport {
  const TutorReport({
    required this.durationSeconds,
    required this.childTurns,
    required this.overallScore,
    required this.pronunciationScore,
    required this.fluencyScore,
    required this.weakWords,
    required this.encouragement,
    this.summary,
  });

  final int durationSeconds;
  final int childTurns;
  final int overallScore;
  final int pronunciationScore;
  final int fluencyScore;
  final List<WeakWordRecord> weakWords;
  final String encouragement;
  final String? summary;
}
