import '../../../core/services/local_store.dart';

final class RoleplayFavoritesRepository {
  RoleplayFavoritesRepository(this._store);

  static const String storageKey = 'saypal.scenario.favorites.v1';
  final LocalStore _store;

  Future<Set<String>> load() async {
    final Map<String, dynamic>? raw = await _store.getJson(storageKey);
    return (raw?['ids'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<String>()
        .toSet();
  }

  Future<Set<String>> toggle(String scenarioId) async {
    final Set<String> ids = await load();
    if (!ids.add(scenarioId)) ids.remove(scenarioId);
    await _store.setJson(storageKey, <String, dynamic>{
      'ids': ids.toList()..sort(),
    });
    return ids;
  }
}
