import 'membership_models.dart';

abstract interface class MembershipCache {
  Future<MembershipSnapshot?> read();

  Future<void> write(MembershipSnapshot snapshot);

  Future<void> clear();
}

class MemoryMembershipCache implements MembershipCache {
  MembershipSnapshot? value;

  @override
  Future<void> clear() async => value = null;

  @override
  Future<MembershipSnapshot?> read() async => value;

  @override
  Future<void> write(MembershipSnapshot snapshot) async => value = snapshot;
}
