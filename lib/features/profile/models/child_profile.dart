/// 本机儿童档案（MVP 不注册、不上云）。
class ChildProfile {
  const ChildProfile({
    required this.name,
    required this.grade,
    required this.avatarId,
  });

  final String name;

  /// 年级（1-6）。
  final int grade;
  final String avatarId;

  String get gradeLabel =>
      const <int, String>{
        1: '一年级',
        2: '二年级',
        3: '三年级',
        4: '四年级',
        5: '五年级',
        6: '六年级',
      }[grade] ??
      '小学';

  static const ChildProfile demo = ChildProfile(
    name: '小家伙',
    grade: 3,
    avatarId: 'tiger',
  );

  static const Set<String> supportedAvatarIds = <String>{
    'tiger',
    'panda',
    'fox',
    'rabbit',
    'koala',
    'lion',
  };

  static const Map<String, String> legacyEmojiToAvatarId = <String, String>{
    '🐯': 'tiger',
    '🐼': 'panda',
    '🦊': 'fox',
    '🐰': 'rabbit',
    '🐨': 'koala',
    '🦁': 'lion',
  };

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'grade': grade,
        'avatarId': avatarId,
      };

  static ChildProfile fromJson(Map<String, dynamic> json) {
    final String? storedId = json['avatarId'] as String?;
    final String? legacyEmoji = json['avatarEmoji'] as String?;
    final String candidate = storedId ??
        legacyEmojiToAvatarId[legacyEmoji] ??
        ChildProfile.demo.avatarId;
    return ChildProfile(
      name: json['name'] as String? ?? ChildProfile.demo.name,
      grade: json['grade'] as int? ?? ChildProfile.demo.grade,
      avatarId: supportedAvatarIds.contains(candidate) ? candidate : 'tiger',
    );
  }
}
