/// 对孩子回答的关键词评分模型，供"学一学"与"角色扮演"共用。
/// 真实链路中评分来自服务端报告；离线演示使用该模型做本地启发式评分。
class ReplyScore {
  const ReplyScore({
    required this.score,
    required this.matchedKeywords,
    required this.missedKeywords,
  });

  /// 0-100。
  final int score;
  final List<String> matchedKeywords;
  final List<String> missedKeywords;

  bool get passed => score >= 60;
}

/// 以期望关键词命中率给出 0-100 的演示评分。
/// 关键词支持 `|` 分隔的任一命中（如 'hot|iced'）。
ReplyScore scoreReplyByKeywords(String reply, List<String> keywords) {
  if (keywords.isEmpty) {
    return const ReplyScore(
        score: 100, matchedKeywords: [], missedKeywords: []);
  }
  final String normalized = reply.toLowerCase().trim();
  final List<String> matched = <String>[];
  final List<String> missed = <String>[];
  for (final String keyword in keywords) {
    final List<String> alternatives = keyword
        .toLowerCase()
        .split('|')
        .map((String k) => k.trim())
        .where((String k) => k.isNotEmpty)
        .toList();
    final bool hit = alternatives.any(normalized.contains);
    if (hit) {
      matched.add(keyword);
    } else {
      missed.add(keyword);
    }
  }
  final int score = (matched.length / keywords.length * 100).round();
  return ReplyScore(
    score: score,
    matchedKeywords: List.unmodifiable(matched),
    missedKeywords: List.unmodifiable(missed),
  );
}

/// 根据表现生成温和的中文鼓励语，避免挫败感。
String encouragementFor(int score) {
  if (score >= 90) {
    return '太棒啦！你说得又准确又流利！';
  }
  if (score >= 60) {
    return '做得很好！再练习一下会更棒！';
  }
  return '没关系，跟着老师再试一次，你一定可以的！';
}
