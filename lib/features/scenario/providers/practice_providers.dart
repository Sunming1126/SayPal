import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/local_store.dart';
import '../data/custom_scene_repository.dart';
import '../data/practice_catalog_repository.dart';
import '../data/roleplay_favorites_repository.dart';
import '../data/roleplay_suggestion_repository.dart';
import '../data/scene_draft_repository.dart';
import '../models/practice_catalog.dart';

final practiceCatalogRepositoryProvider =
    Provider<PracticeCatalogRepository>((ref) => PracticeCatalogRepository());
final roleplayCatalogProvider = FutureProvider<List<RoleplayScenario>>(
    (ref) => ref.watch(practiceCatalogRepositoryProvider).roleplays());
final roleplayCollectionProvider = FutureProvider<RoleplayCatalog>(
    (ref) => ref.watch(practiceCatalogRepositoryProvider).catalog());
final customSceneRepositoryProvider = Provider<CustomSceneRepository>(
    (ref) => CustomSceneRepository(ref.watch(localStoreProvider)));
final customScenesProvider = FutureProvider<List<CustomSceneDraft>>(
    (ref) => ref.watch(customSceneRepositoryProvider).load());
final roleplayFavoritesRepositoryProvider = Provider<RoleplayFavoritesRepository>(
  (ref) => RoleplayFavoritesRepository(ref.watch(localStoreProvider)),
);
final roleplayFavoritesProvider =
    AsyncNotifierProvider.autoDispose<RoleplayFavoritesController, Set<String>>(
  RoleplayFavoritesController.new,
);

final class RoleplayFavoritesController
    extends AutoDisposeAsyncNotifier<Set<String>> {
  @override
  Future<Set<String>> build() =>
      ref.watch(roleplayFavoritesRepositoryProvider).load();

  Future<void> toggle(String scenarioId) async {
    state = AsyncData(
      await ref.read(roleplayFavoritesRepositoryProvider).toggle(scenarioId),
    );
  }
}
final sceneDraftRepositoryProvider =
    Provider<SceneDraftRepository>((ref) => LocalSceneDraftApi());
final roleplaySuggestionRepositoryProvider = Provider<RoleplaySuggestionRepository>(
  (ref) => HttpRoleplaySuggestionRepository(),
);
