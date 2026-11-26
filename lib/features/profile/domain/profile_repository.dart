import '../../../core/services/local_store.dart';
import '../models/child_profile.dart';

/// 儿童档案仓库（本机实现）。
final class LocalProfileRepository {
  LocalProfileRepository(this._store);

  static const String _storageKey = 'saypal.profile.child';

  final LocalStore _store;

  Future<ChildProfile> load() async {
    final Map<String, dynamic>? raw = await _store.getJson(_storageKey);
    if (raw == null) {
      return ChildProfile.demo;
    }
    return ChildProfile.fromJson(raw);
  }

  Future<void> save(ChildProfile profile) async {
    await _store.setJson(_storageKey, profile.toJson());
  }
}
