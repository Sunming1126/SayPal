import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';

class StoreQueryResult {
  const StoreQueryResult({
    required this.products,
    this.notFoundIds = const {},
    this.error,
  });

  final List<ProductDetails> products;
  final Set<String> notFoundIds;
  final String? error;
}

abstract interface class MembershipStoreGateway {
  Stream<List<PurchaseDetails>> get purchaseStream;

  Future<bool> isAvailable();

  Future<StoreQueryResult> queryProducts(Set<String> productIds);

  Future<bool> buy(ProductDetails product);

  Future<List<PurchaseDetails>> unfinishedPurchases();

  Future<void> restorePurchases();

  Future<void> completePurchase(PurchaseDetails purchase);
}

class InAppPurchaseStoreGateway implements MembershipStoreGateway {
  InAppPurchaseStoreGateway([InAppPurchase? store])
    : _store = store ?? InAppPurchase.instance;

  final InAppPurchase _store;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _store.purchaseStream;

  @override
  Future<bool> isAvailable() => _store.isAvailable();

  @override
  Future<StoreQueryResult> queryProducts(Set<String> productIds) async {
    final result = await _store.queryProductDetails(productIds);
    return StoreQueryResult(
      products: result.productDetails,
      notFoundIds: result.notFoundIDs.toSet(),
      error: result.error?.toString(),
    );
  }

  @override
  Future<bool> buy(ProductDetails product) => _store.buyNonConsumable(
    purchaseParam: PurchaseParam(productDetails: product),
  );

  @override
  Future<List<PurchaseDetails>> unfinishedPurchases() async {
    if (defaultTargetPlatform != TargetPlatform.iOS &&
        defaultTargetPlatform != TargetPlatform.macOS) {
      return const [];
    }
    final transactions = await SK2Transaction.unfinishedTransactions();
    return transactions
        .map(
          (transaction) => SK2PurchaseDetails(
            productID: transaction.productId,
            purchaseID: transaction.id,
            verificationData: PurchaseVerificationData(
              localVerificationData: transaction.jsonRepresentation ?? '',
              serverVerificationData: transaction.receiptData ?? '',
              source: 'app_store',
            ),
            transactionDate: transaction.purchaseDate,
            status: PurchaseStatus.purchased,
            appAccountToken: transaction.appAccountToken,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> restorePurchases() => _store.restorePurchases();

  @override
  Future<void> completePurchase(PurchaseDetails purchase) =>
      _store.completePurchase(purchase);
}
