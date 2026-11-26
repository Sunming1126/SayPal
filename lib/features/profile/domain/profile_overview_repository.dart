import '../models/profile_overview.dart';

abstract interface class ProfileOverviewRepository {
  Future<ProfileOverview> load();
}
