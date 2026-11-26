class RoleplayCatalog {
  const RoleplayCatalog({required this.categories, required this.scenarios});

  final List<RoleplayCategory> categories;
  final List<RoleplayScenario> scenarios;
}

class RoleplayCategory {
  const RoleplayCategory({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.imageAsset,
    required this.startColor,
    required this.endColor,
    required this.order,
  });

  final String id, title, subtitle, imageAsset, startColor, endColor;
  final int order;

  factory RoleplayCategory.fromJson(Map<String, dynamic> json) =>
      RoleplayCategory(
        id: json['id'] as String,
        title: json['title'] as String,
        subtitle: json['subtitle'] as String,
        imageAsset: json['imageAsset'] as String,
        startColor: json['startColor'] as String,
        endColor: json['endColor'] as String,
        order: json['order'] as int,
      );
}

class RoleplayScenario {
  const RoleplayScenario(
      {required this.id,
      required this.categoryId,
      required this.category,
      required this.title,
      required this.icon,
      required this.imageAsset,
      required this.difficulty,
      this.featuredOrder,
      required this.learnerRole,
      required this.aiRole,
      required this.situation,
      required this.opening,
      required this.objectives});
  final String id,
      categoryId,
      category,
      title,
      icon,
      imageAsset,
      difficulty,
      learnerRole,
      aiRole,
      situation,
      opening;
  final int? featuredOrder;
  final List<String> objectives;
  factory RoleplayScenario.fromJson(Map<String, dynamic> json) =>
      RoleplayScenario(
        id: json['id'] as String,
        categoryId: json['categoryId'] as String,
        category: json['category'] as String,
        title: json['title'] as String,
        icon: json['icon'] as String,
        imageAsset: json['imageAsset'] as String,
        difficulty: json['difficulty'] as String,
        featuredOrder: json['featuredOrder'] as int?,
        learnerRole: json['learnerRole'] as String,
        aiRole: json['aiRole'] as String,
        situation: json['situation'] as String,
        opening: json['opening'] as String,
        objectives: (json['objectives'] as List<dynamic>).cast<String>(),
      );
}

class CustomSceneDraft {
  const CustomSceneDraft(
      {required this.id,
      required this.title,
      required this.learnerRole,
      required this.aiRole,
      required this.situation,
      required this.objectives,
      required this.createdAt});
  final String id, title, learnerRole, aiRole, situation;
  final List<String> objectives;
  final DateTime createdAt;
  factory CustomSceneDraft.fromJson(Map<String, dynamic> j) => CustomSceneDraft(
      id: j['id'] as String,
      title: j['title'] as String,
      learnerRole: j['learnerRole'] as String,
      aiRole: j['aiRole'] as String,
      situation: j['situation'] as String,
      objectives: (j['objectives'] as List<dynamic>).cast<String>(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(j['createdAt'] as int));
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'learnerRole': learnerRole,
        'aiRole': aiRole,
        'situation': situation,
        'objectives': objectives,
        'createdAt': createdAt.millisecondsSinceEpoch
      };
}

class SceneDraftSeed {
  const SceneDraftSeed({
    required this.learnerRole,
    required this.aiRole,
    required this.situation,
  });

  final String learnerRole;
  final String aiRole;
  final String situation;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'learnerRole': learnerRole,
        'aiRole': aiRole,
        'situation': situation,
      };
}
