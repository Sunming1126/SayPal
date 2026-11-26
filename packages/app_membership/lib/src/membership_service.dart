import 'membership_models.dart';

abstract interface class MembershipService {
  MembershipSnapshot get current;

  Stream<MembershipSnapshot> get states;

  Stream<MembershipPurchaseEvent> get purchaseEvents;

  Future<void> initialize();

  Future<MembershipSnapshot> refresh();

  Future<List<MembershipProduct>> loadProducts();

  Future<void> purchase(MembershipPlan plan);

  Future<void> restorePurchases();

  Future<void> signedOut();

  Future<void> dispose();
}
