import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/local_store.dart';
import '../domain/profile_repository.dart';
import '../domain/profile_overview_repository.dart';
import '../models/child_profile.dart';
import '../models/profile_overview.dart';

final class _EmptyProfileOverviewRepository
    implements ProfileOverviewRepository {
  const _EmptyProfileOverviewRepository();

  @override
  Future<ProfileOverview> load() async => ProfileOverview.empty;
}

final profileOverviewRepositoryProvider =
    Provider<ProfileOverviewRepository>((ref) {
  return const _EmptyProfileOverviewRepository();
});

final profileOverviewProvider =
    FutureProvider.autoDispose<ProfileOverview>((ref) {
  return ref.watch(profileOverviewRepositoryProvider).load();
});

final profileRepositoryProvider = Provider<LocalProfileRepository>((ref) {
  return LocalProfileRepository(ref.watch(localStoreProvider));
});

/// 儿童档案状态。
final class ChildProfileController
    extends AutoDisposeAsyncNotifier<ChildProfile> {
  @override
  Future<ChildProfile> build() => ref.watch(profileRepositoryProvider).load();

  Future<void> updateProfile(ChildProfile profile) async {
    await ref.read(profileRepositoryProvider).save(profile);
    state = AsyncData(profile);
  }
}

final childProfileProvider =
    AsyncNotifierProvider.autoDispose<ChildProfileController, ChildProfile>(
  ChildProfileController.new,
);
