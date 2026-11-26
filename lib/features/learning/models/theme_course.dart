class ThemeCourseLine {
  const ThemeCourseLine({required this.en, required this.zh});

  final String en;
  final String zh;

  factory ThemeCourseLine.fromJson(Map<String, dynamic> json) =>
      ThemeCourseLine(
        en: json['en'] as String,
        zh: (json['zh'] ?? json['cn']) as String,
      );
}

class ThemeCourseQuestion {
  const ThemeCourseQuestion({required this.question, required this.answer});

  final String question;
  final String answer;

  factory ThemeCourseQuestion.fromJson(Map<String, dynamic> json) =>
      ThemeCourseQuestion(
        question: json['q'] as String,
        answer: json['a'] as String,
      );
}

/// 原“家教课”的课程模型。服务端 JSON 字段保持不变，仅调整客户端归属。
class ThemeCourse {
  const ThemeCourse({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.videoUrl,
    required this.vttUrl,
    required this.icon,
    required this.vocabulary,
    required this.introLines,
    required this.translationDrill,
    required this.qaPairs,
  });

  final String id;
  final String title;
  final String subtitle;
  final String videoUrl;
  final String vttUrl;
  final String icon;
  final List<String> vocabulary;
  final List<ThemeCourseLine> introLines;
  final List<ThemeCourseLine> translationDrill;
  final List<ThemeCourseQuestion> qaPairs;

  bool get videoReady =>
      videoUrl.startsWith('https://') && vttUrl.startsWith('https://');

  factory ThemeCourse.fromJson(Map<String, dynamic> json) => ThemeCourse(
        id: json['id'] as String,
        title: json['title'] as String,
        subtitle: json['subtitle'] as String,
        videoUrl: json['videoUrl'] as String,
        vttUrl: json['vttUrl'] as String,
        icon: json['icon'] as String,
        vocabulary: (json['vocabulary'] as List<dynamic>).cast<String>(),
        introLines: (json['introLines'] as List<dynamic>)
            .map((dynamic item) =>
                ThemeCourseLine.fromJson(item as Map<String, dynamic>))
            .toList(),
        translationDrill: (json['translationDrill'] as List<dynamic>)
            .map((dynamic item) =>
                ThemeCourseLine.fromJson(item as Map<String, dynamic>))
            .toList(),
        qaPairs: (json['qaPairs'] as List<dynamic>)
            .map((dynamic item) =>
                ThemeCourseQuestion.fromJson(item as Map<String, dynamic>))
            .toList(),
      );
}
