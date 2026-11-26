import 'dart:async';

import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';

import 'membership_api.dart';
import 'membership_cache.dart';
import 'membership_models.dart';
import 'membership_service.dart';
import 'store_gateway.dart';

typedef MembershipTokenProvider = Future<String?> Function({bool forceRefresh});
typedef MembershipLogger = void Function(String message);

class AppleMembershipService implements MembershipService {
  AppleMembershipService({
    required this.api,
    required this.cache,
    required this.tokenProvider,
    required this.productIds,
    MembershipStoreGateway? store,
    DateTime Function()? clock,
    this.storeOperationTimeout = const Duration(seconds: 20),
    this.restoreResultTimeout = const Duration(seconds: 15),
    this.verificationRetryDelays = const [
      Duration.zero,
      Duration(milliseconds: 500),
      Duration(seconds: 2),
    ],
    this.logger,
  }) : store = store ?? InAppPurchaseStoreGateway(),
       _clock = clock ?? (() => DateTime.now().toUtc()),
       assert(storeOperationTimeout > Duration.zero),
       assert(restoreResultTimeout > Duration.zero),
       assert(verificationRetryDelays.isNotEmpty);

  final MembershipApi api;
  final MembershipCache cache;
  final MembershipTokenProvider tokenProvider;
  final MembershipProductIds productIds;
  final MembershipStoreGateway store;
  final DateTime Function() _clock;
  final Duration storeOperationTimeout;
  final Duration restoreResultTimeout;
  final List<Duration> verificationRetryDelays;
  final MembershipLogger? logger;

  final _states = StreamController<MembershipSnapshot>.broadcast();
  final _purchaseEvents = StreamController<MembershipPurchaseEvent>.broadcast();
  final Map<String, ProductDetails> _storeProducts = {};
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  Timer? _restoreTimer;
  bool _restoreInProgress = false;
  bool _purchaseInProgress = false;
  MembershipSnapshot _current = const MembershipSnapshot.guest();

  @override
  MembershipSnapshot get current => _current;

  @override
  Stream<MembershipSnapshot> get states => _states.stream;

  @override
  Stream<MembershipPurchaseEvent> get purchaseEvents => _purchaseEvents.stream;

  @override
  Future<void> initialize() async {
    _purchaseSubscription ??= store.purchaseStream.listen(
      _handlePurchases,
      onError: (Object error) {
        final failure = _storeFailure('purchase_stream_failed', error);
        _purchaseEvents.add(
          MembershipPurchaseEvent(
            stage: MembershipPurchaseStage.failed,
            code: failure.code,
            message: failure.details,
          ),
        );
      },
    );
    await _recoverUnfinishedPurchases();
    await refresh();
  }

  Future<void> _recoverUnfinishedPurchases() async {
    try {
      final purchases = await _runStoreOperation(
        store.unfinishedPurchases,
        timeoutCode: 'unfinished_purchase_query_timeout',
        failureCode: 'unfinished_purchase_query_failed',
      );
      if (purchases.isEmpty) return;
      _log('Recovering ${purchases.length} unfinished StoreKit purchase(s)');
      await _handlePurchases(purchases);
    } catch (error) {
      // Recovery is retried on the next launch or explicit Restore Purchases.
      // It must not prevent the rest of the app from starting.
      _log('Unfinished StoreKit purchase recovery unavailable: $error');
    }
  }

  @override
  Future<MembershipSnapshot> refresh() async {
    try {
      final token = await tokenProvider(forceRefresh: false);
      if (token == null || token.isEmpty) {
        await signedOut();
        return _current;
      }
      final snapshot = await api.fetchMembership(token);
      await cache.write(snapshot);
      _emit(snapshot);
    } catch (error) {
      _log('Membership refresh unavailable: $error');
      MembershipSnapshot? cached;
      try {
        cached = await cache.read();
      } catch (cacheError) {
        _log('Membership cache read failed: $cacheError');
      }
      _emit(
        cached != null && cached.isOfflineUsableAt(_clock())
            ? cached
            : const MembershipSnapshot.unavailable(),
      );
    }
    return _current;
  }

  @override
  Future<List<MembershipProduct>> loadProducts() async {
    final available = await _runStoreOperation(
      store.isAvailable,
      timeoutCode: 'store_availability_timeout',
      failureCode: 'store_availability_failed',
    );
    if (!available) {
      throw const MembershipFailure('store_unavailable');
    }
    final result = await _runStoreOperation(
      () => store.queryProducts(productIds.all),
      timeoutCode: 'product_query_timeout',
      failureCode: 'product_query_failed',
    );
    if (result.error != null) {
      throw _storeFailure('product_query_failed', result.error!);
    }
    final returnedIds = result.products.map((product) => product.id).toSet();
    final missingIds = {
      ...result.notFoundIds,
      ...productIds.all.difference(returnedIds),
    };
    if (missingIds.isNotEmpty) {
      _log('StoreKit products missing: ${missingIds.join(', ')}');
    }
    final invalid = <String>[];
    final products = <MembershipProduct>[];
    _storeProducts.clear();
    for (final details in result.products) {
      final plan = productIds.planFor(details.id);
      if (plan == null) continue;
      final descriptor = _inspectProduct(details);
      final configurationError = _configurationError(plan, descriptor);
      _log(
        'StoreKit product ${details.id}: price=${details.price}, '
        'currency=${details.currencyCode}, type=${descriptor.type.name}, '
        'period=${descriptor.periodValue ?? '-'} '
        '${descriptor.periodUnit?.name ?? '-'}',
      );
      if (configurationError != null) {
        invalid.add('${details.id}:$configurationError');
        continue;
      }
      _storeProducts[details.id] = details;
      products.add(
        MembershipProduct(
          plan: plan,
          productId: details.id,
          title: details.title,
          description: details.description,
          displayPrice: details.price,
          rawPrice: details.rawPrice,
          currencyCode: details.currencyCode,
          storeType: descriptor.type,
          periodUnit: descriptor.periodUnit,
          periodValue: descriptor.periodValue,
        ),
      );
    }
    if (invalid.isNotEmpty) {
      _log(
        'StoreKit products have invalid configuration: ${invalid.join(', ')}',
      );
    }
    if (products.isEmpty) {
      if (invalid.isNotEmpty) {
        throw MembershipFailure(
          'products_invalid_configuration',
          invalid.join(','),
        );
      }
      throw MembershipFailure('products_not_found', missingIds.join(','));
    }
    products.sort((a, b) => a.plan.index.compareTo(b.plan.index));
    return products;
  }

  @override
  Future<void> purchase(MembershipPlan plan) async {
    if (_purchaseInProgress) {
      throw const MembershipFailure('duplicate_purchase_pending');
    }
    _purchaseInProgress = true;
    try {
      var product = _storeProducts[productIds.idFor(plan)];
      if (product == null) {
        await loadProducts();
        product = _storeProducts[productIds.idFor(plan)];
      }
      if (product == null) {
        throw const MembershipFailure('product_not_found');
      }
      _log(
        'Starting StoreKit purchase: plan=${plan.name}, product=${product.id}',
      );
      final started = await _runPurchaseOperation(() => store.buy(product!));
      if (!started) {
        throw const MembershipFailure('purchase_not_started');
      }
    } finally {
      _purchaseInProgress = false;
    }
  }

  Future<T> _runPurchaseOperation<T>(Future<T> Function() operation) async {
    try {
      // StoreKit 2's purchase call remains pending while the system purchase
      // confirmation is on screen. Applying the short network-operation timeout
      // here abandons the Dart wait without cancelling the native purchase and
      // lets the user accidentally start overlapping transactions.
      return await operation();
    } on MembershipFailure {
      rethrow;
    } catch (error) {
      throw _storeFailure('purchase_failed', error);
    }
  }

  @override
  Future<void> restorePurchases() async {
    _restoreTimer?.cancel();
    _restoreInProgress = true;
    _purchaseEvents.add(
      const MembershipPurchaseEvent(
        stage: MembershipPurchaseStage.restoreStarted,
      ),
    );
    try {
      await _runStoreOperation(
        store.restorePurchases,
        timeoutCode: 'restore_timeout',
        failureCode: 'restore_failed',
      );
      if (_restoreInProgress) {
        _restoreTimer = Timer(restoreResultTimeout, _finishEmptyRestore);
      }
    } catch (_) {
      _clearRestoreState();
      rethrow;
    }
  }

  Future<T> _runStoreOperation<T>(
    Future<T> Function() operation, {
    required String timeoutCode,
    required String failureCode,
  }) async {
    try {
      return await operation().timeout(storeOperationTimeout);
    } on MembershipFailure {
      rethrow;
    } on TimeoutException {
      throw MembershipFailure(timeoutCode);
    } catch (error) {
      throw _storeFailure(failureCode, error);
    }
  }

  Future<void> _handlePurchases(List<PurchaseDetails> purchases) async {
    if (purchases.isEmpty && _restoreInProgress) {
      _finishEmptyRestore();
      return;
    }
    for (final purchase in purchases) {
      final plan = productIds.planFor(purchase.productID);
      switch (purchase.status) {
        case PurchaseStatus.pending:
          _purchaseEvents.add(
            MembershipPurchaseEvent(
              stage: MembershipPurchaseStage.pending,
              plan: plan,
            ),
          );
        case PurchaseStatus.canceled:
          _purchaseEvents.add(
            MembershipPurchaseEvent(
              stage: MembershipPurchaseStage.cancelled,
              plan: plan,
            ),
          );
        case PurchaseStatus.error:
          if (_restoreInProgress) _clearRestoreState();
          final failure = _storeFailure(
            'purchase_failed',
            purchase.error ?? 'Unknown StoreKit purchase error',
          );
          _purchaseEvents.add(
            MembershipPurchaseEvent(
              stage: MembershipPurchaseStage.failed,
              plan: plan,
              code: failure.code,
              message: failure.details,
            ),
          );
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          if (purchase.status == PurchaseStatus.restored) {
            _clearRestoreState();
          }
          await _verifyPurchase(purchase, plan);
      }
    }
  }

  Future<void> _verifyPurchase(
    PurchaseDetails purchase,
    MembershipPlan? plan,
  ) async {
    try {
      final snapshot = await _verifyWithRetry(purchase);
      try {
        await cache.write(snapshot);
      } catch (error) {
        _log('Membership cache write failed after verification: $error');
      }
      _emit(snapshot);
      final shouldComplete =
          purchase.pendingCompletePurchase ||
          (purchase is SK2PurchaseDetails &&
              purchase.status == PurchaseStatus.restored &&
              purchase.purchaseID != null);
      if (shouldComplete) {
        await _runStoreOperation(
          () => store.completePurchase(purchase),
          timeoutCode: 'complete_purchase_timeout',
          failureCode: 'complete_purchase_failed',
        );
      }
      _purchaseEvents.add(
        MembershipPurchaseEvent(
          stage: purchase.status == PurchaseStatus.restored
              ? MembershipPurchaseStage.restored
              : MembershipPurchaseStage.purchased,
          plan: plan,
        ),
      );
    } on MembershipFailure catch (error) {
      final deferred = error.code == 'verification_deferred';
      _purchaseEvents.add(
        MembershipPurchaseEvent(
          stage: deferred
              ? MembershipPurchaseStage.verificationDeferred
              : MembershipPurchaseStage.failed,
          plan: plan,
          code: error.code,
          message: error.details,
        ),
      );
    } catch (error) {
      _purchaseEvents.add(
        MembershipPurchaseEvent(
          stage: MembershipPurchaseStage.failed,
          plan: plan,
          code: 'verification_failed',
          message: error.toString(),
        ),
      );
    }
  }

  Future<MembershipSnapshot> _verifyWithRetry(PurchaseDetails purchase) async {
    Object? lastError;
    for (var attempt = 0; attempt < verificationRetryDelays.length; attempt++) {
      final delay = verificationRetryDelays[attempt];
      if (delay > Duration.zero) await Future<void>.delayed(delay);
      try {
        final token = await tokenProvider(forceRefresh: attempt == 0);
        if (token == null || token.isEmpty) {
          throw const MembershipFailure('authentication_required');
        }
        return await api.verifyAppleTransaction(
          idToken: token,
          productId: purchase.productID,
          verificationData: purchase.verificationData.serverVerificationData,
          transactionDate: purchase.transactionDate,
        );
      } on MembershipFailure catch (error) {
        if (error.code != 'membership_request_failed') rethrow;
        lastError = error;
      } catch (error) {
        lastError = error;
      }
      _log('Membership verification attempt ${attempt + 1} failed: $lastError');
    }
    throw MembershipFailure('verification_deferred', lastError?.toString());
  }

  MembershipFailure _storeFailure(String fallbackCode, Object error) {
    final platformCode = error is PlatformException ? error.code : '';
    final text = '$platformCode $error'.toLowerCase();
    final code = switch (text) {
      final value
          when value.contains('productunavailable') ||
              value.contains('product_unavailable') ||
              value.contains('storeproductnotavailable') =>
        'product_unavailable',
      final value
          when value.contains('purchasenotallowed') ||
              value.contains('purchase_not_allowed') ||
              value.contains('paymentnotallowed') =>
        'purchase_not_allowed',
      final value
          when value.contains('storekit_duplicate_product_object') ||
              value.contains('duplicate product') =>
        'duplicate_purchase_pending',
      final value
          when value.contains('usercancelled') ||
              value.contains('user_cancelled') ||
              value.contains('paymentcancelled') =>
        'purchase_cancelled',
      final value
          when value.contains('network') ||
              value.contains('timed out') ||
              value.contains('timeout') ||
              value.contains('urlerror') ||
              value.contains('cannotconnect') =>
        'store_network_error',
      _ => fallbackCode,
    };
    return MembershipFailure(code, error.toString());
  }

  void _finishEmptyRestore() {
    if (!_restoreInProgress) return;
    _clearRestoreState();
    _purchaseEvents.add(
      const MembershipPurchaseEvent(
        stage: MembershipPurchaseStage.restoreNotFound,
      ),
    );
  }

  void _clearRestoreState() {
    _restoreTimer?.cancel();
    _restoreTimer = null;
    _restoreInProgress = false;
  }

  void _log(String message) => logger?.call(message);

  void _emit(MembershipSnapshot snapshot) {
    _current = snapshot;
    _states.add(snapshot);
  }

  @override
  Future<void> signedOut() async {
    await cache.clear();
    _emit(const MembershipSnapshot.guest());
  }

  @override
  Future<void> dispose() async {
    _clearRestoreState();
    await _purchaseSubscription?.cancel();
    await _states.close();
    await _purchaseEvents.close();
  }
}

class _ProductDescriptor {
  const _ProductDescriptor({
    required this.type,
    this.periodUnit,
    this.periodValue,
    this.appleTypeKnown = false,
  });

  final MembershipProductStoreType type;
  final MembershipPeriodUnit? periodUnit;
  final int? periodValue;
  final bool appleTypeKnown;
}

_ProductDescriptor _inspectProduct(ProductDetails product) {
  if (product is AppStoreProduct2Details) {
    final subscription = product.sk2Product.subscription?.subscriptionPeriod;
    return _ProductDescriptor(
      type: switch (product.sk2Product.type) {
        SK2ProductType.autoRenewable =>
          MembershipProductStoreType.autoRenewable,
        SK2ProductType.nonConsumable =>
          MembershipProductStoreType.nonConsumable,
        SK2ProductType.nonRenewable => MembershipProductStoreType.nonRenewing,
        SK2ProductType.consumable => MembershipProductStoreType.consumable,
      },
      periodUnit: subscription == null
          ? null
          : _periodUnit(subscription.unit.name),
      periodValue: subscription?.value,
      appleTypeKnown: true,
    );
  }
  if (product is AppStoreProductDetails) {
    final subscription = product.skProduct.subscriptionPeriod;
    return _ProductDescriptor(
      type: subscription == null
          ? MembershipProductStoreType.unknown
          : MembershipProductStoreType.autoRenewable,
      periodUnit: subscription == null
          ? null
          : _periodUnit(subscription.unit.name),
      periodValue: subscription?.numberOfUnits,
    );
  }
  return const _ProductDescriptor(type: MembershipProductStoreType.unknown);
}

MembershipPeriodUnit _periodUnit(String name) => switch (name) {
  'day' => MembershipPeriodUnit.day,
  'week' => MembershipPeriodUnit.week,
  'month' => MembershipPeriodUnit.month,
  'year' => MembershipPeriodUnit.year,
  _ => throw StateError('Unsupported StoreKit period unit: $name'),
};

String? _configurationError(
  MembershipPlan plan,
  _ProductDescriptor descriptor,
) {
  if (plan == MembershipPlan.lifetime) {
    if (descriptor.appleTypeKnown &&
        descriptor.type != MembershipProductStoreType.nonConsumable) {
      return 'lifetime_must_be_non_consumable';
    }
    return null;
  }
  if (descriptor.appleTypeKnown &&
      descriptor.type != MembershipProductStoreType.autoRenewable) {
    return '${plan.name}_must_be_auto_renewable';
  }
  if (descriptor.periodUnit == null && !descriptor.appleTypeKnown) return null;
  final expectedUnit = plan == MembershipPlan.monthly
      ? MembershipPeriodUnit.month
      : MembershipPeriodUnit.year;
  if (descriptor.periodUnit != expectedUnit || descriptor.periodValue != 1) {
    return '${plan.name}_has_wrong_subscription_period';
  }
  return null;
}
