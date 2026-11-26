import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/practice_catalog.dart';

class PracticeCatalogRepository {
  Future<RoleplayCatalog> catalog() async {
    final Map<String, dynamic> raw = jsonDecode(
            await rootBundle.loadString('assets/content/roleplay_catalog.json'))
        as Map<String, dynamic>;
    final List<RoleplayCategory> categories = (raw['categories'] as List<dynamic>)
        .map((dynamic item) =>
            RoleplayCategory.fromJson(item as Map<String, dynamic>))
        .toList()
      ..sort((RoleplayCategory a, RoleplayCategory b) =>
          a.order.compareTo(b.order));
    final List<RoleplayScenario> scenarios = (raw['scenarios'] as List<dynamic>)
        .map((dynamic item) =>
            RoleplayScenario.fromJson(item as Map<String, dynamic>))
        .toList();
    return RoleplayCatalog(categories: categories, scenarios: scenarios);
  }

  Future<List<RoleplayScenario>> roleplays() async {
    return (await catalog()).scenarios;
  }
}
