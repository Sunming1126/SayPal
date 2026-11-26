import 'dart:convert';

import 'package:app_membership/app_membership.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 会员快照的持久化缓存（Keychain / flutter_secure_storage）。
/// 离线时 AppleMembershipService 会回退读取它，保证已购权益可离线使用。
class SecureMembershipCache implements MembershipCache {
  SecureMembershipCache(
    this.storage, {
    this.key = 'saypal.membership.snapshot.v1',
  });

  final FlutterSecureStorage storage;
  final String key;

  @override
  Future<void> clear() => storage.delete(key: key);

  @override
  Future<MembershipSnapshot?> read() async {
    final raw = await storage.read(key: key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return MembershipSnapshot.fromJson(decoded);
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> write(MembershipSnapshot snapshot) =>
      storage.write(key: key, value: jsonEncode(snapshot.toJson()));
}
