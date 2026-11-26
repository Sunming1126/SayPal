import '../../../core/services/local_store.dart';
import '../models/practice_catalog.dart';

class CustomSceneRepository {
  CustomSceneRepository(this._store);
  static const _key = 'saypal.scenario.custom.v1';
  final LocalStore _store;
  Future<List<CustomSceneDraft>> load() async {
    final raw = await _store.getJsonList(_key) ?? const <dynamic>[];
    return raw
        .map((e) => CustomSceneDraft.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<List<CustomSceneDraft>> save(CustomSceneDraft draft) async {
    final all = (await load()).where((item) => item.id != draft.id).toList()
      ..insert(0, draft);
    final trimmed = all.take(10).toList();
    await _store.setJsonList(_key, trimmed.map((e) => e.toJson()).toList());
    return trimmed;
  }
}
