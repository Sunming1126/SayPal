class ProfileOverview {
  const ProfileOverview({
    required this.totalMinutes,
    required this.speakingCount,
    required this.vocabularyCount,
    this.conversationCount = 0,
    this.roleplayCount = 0,
    this.favoriteCount = 0,
  });

  final int totalMinutes;
  final int speakingCount;
  final int vocabularyCount;
  final int conversationCount;
  final int roleplayCount;
  final int favoriteCount;

  static const ProfileOverview empty = ProfileOverview(
    totalMinutes: 0,
    speakingCount: 0,
    vocabularyCount: 0,
    conversationCount: 0,
    roleplayCount: 0,
    favoriteCount: 0,
  );
}
