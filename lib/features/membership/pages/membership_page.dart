import 'dart:async';

import 'package:app_membership/app_membership.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/legal_urls.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/membership_providers.dart';

/// 会员详情页：权益说明、商品选购、购买 / 恢复 / 管理订阅与法律链接。
class MembershipPage extends ConsumerStatefulWidget {
  const MembershipPage({super.key});

  @override
  ConsumerState<MembershipPage> createState() => _MembershipPageState();
}

class _MembershipPageState extends ConsumerState<MembershipPage> {
  MembershipPlan selected = MembershipPlan.annual;
  List<MembershipProduct> storeProducts = const [];
  StreamSubscription<MembershipPurchaseEvent>? purchaseSubscription;
  String? productsDiagnostic;
  String? productsError;
  bool productsLoading = true;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    final MembershipService service = ref.read(membershipServiceProvider);
    purchaseSubscription = service.purchaseEvents.listen(_purchaseEvent);
    unawaited(_loadProducts(setLoading: false));
  }

  @override
  void dispose() {
    final StreamSubscription<MembershipPurchaseEvent>? subscription =
        purchaseSubscription;
    if (subscription != null) unawaited(subscription.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final MembershipSnapshot snapshot = ref.watch(membershipSnapshotProvider)
            .valueOrNull ??
        const MembershipSnapshot.guest();
    final bool signedIn = ref.watch(signedInProvider);
    final bool canPurchase = !busy &&
        !productsLoading &&
        productsError == null &&
        storeProducts.any((MembershipProduct product) => product.plan == selected);
    return Scaffold(
      appBar: AppBar(
        title: const Text('会员详情'),
        actions: [
          if (signedIn)
            IconButton(
              tooltip: '刷新会员状态',
              onPressed: busy ? null : _refresh,
              icon: const Icon(CupertinoIcons.refresh),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 30),
          children: [
            _MembershipHero(snapshot: snapshot, signedIn: signedIn),
            const SizedBox(height: 18),
            _benefits(),
            const SizedBox(height: 22),
            Text(
              '选择会员方案',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            _productsSection(),
            const SizedBox(height: 16),
            if (!signedIn) ...[
              FilledButton(
                onPressed: busy ? null : _register,
                child: const Text('登录 / 注册并开始 3 天体验'),
              ),
            ] else ...[
              FilledButton(
                onPressed: canPurchase ? _purchase : null,
                child: busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(_purchaseButtonLabel(selected)),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: busy ? null : _restore,
                child: const Text('恢复购买'),
              ),
              if ((snapshot.state == MembershipState.active ||
                      snapshot.state == MembershipState.gracePeriod) &&
                  snapshot.plan != MembershipPlan.lifetime)
                TextButton(
                  onPressed: _manageSubscription,
                  child: const Text('管理 Apple 订阅'),
                ),
            ],
            const SizedBox(height: 14),
            const Text(
              '月卡与年卡通过 Apple 自动续费，可随时取消；取消后权益保留至当前计费周期结束。'
              '终身会员为一次性购买，不会自动续费，购买后可在同一 Apple 账户下恢复权益。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              children: [
                TextButton(
                  onPressed: () => _legal(privacy: false),
                  child: const Text('服务条款'),
                ),
                TextButton(
                  onPressed: () => _legal(privacy: true),
                  child: const Text('隐私政策'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _benefits() => ContentCard(
        child: Column(
          children: [
            _benefit(CupertinoIcons.chat_bubble_2, '全部情景口语陪练内容'),
            const Divider(height: 22),
            _benefit(CupertinoIcons.square_grid_2x2, '自定义角色扮演与场景练习'),
            const Divider(height: 22),
            _benefit(CupertinoIcons.arrow_2_circlepath, '跨设备恢复会员权益'),
          ],
        ),
      );

  Widget _benefit(IconData icon, String label) => Row(
        children: [
          Icon(icon, color: AppColors.accent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const Icon(
            CupertinoIcons.check_mark_circled_solid,
            color: AppColors.success,
            size: 19,
          ),
        ],
      );

  Widget _productsSection() {
    if (productsLoading) {
      return const ContentCard(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('正在连接 App Store…'),
          ],
        ),
      );
    }

    if (productsError != null || storeProducts.isEmpty) {
      return ContentCard(
        child: Column(
          children: [
            const Icon(
              CupertinoIcons.exclamationmark_circle,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 10),
            Text(
              productsError ?? '暂时无法加载 App Store 商品',
              textAlign: TextAlign.center,
            ),
            if (kDebugMode && productsDiagnostic != null) ...[
              const SizedBox(height: 8),
              SelectableText(
                productsDiagnostic!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 10,
                  height: 1.35,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: _reloadProducts,
              icon: const Icon(CupertinoIcons.refresh, size: 17),
              label: const Text('重新加载'),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final MembershipProduct product in storeProducts) ...[
          _ProductOption(
            product: product,
            selected: selected == product.plan,
            recommended: product.plan == MembershipPlan.annual,
            onTap: () => setState(() => selected = product.plan),
          ),
          if (product != storeProducts.last) const SizedBox(height: 10),
        ],
        const SizedBox(height: 8),
        const Text(
          '价格由 App Store 提供，以购买确认页为准',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Future<void> _register() async {
    await context.push('/auth');
    if (mounted) setState(() {});
  }

  Future<void> _refresh() async {
    setState(() => busy = true);
    try {
      await ref.read(membershipServiceProvider).refresh();
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _reloadProducts() {
    unawaited(_loadProducts());
  }

  Future<void> _loadProducts({bool setLoading = true}) async {
    if (setLoading && mounted) {
      setState(() {
        productsLoading = true;
        productsDiagnostic = null;
        productsError = null;
      });
    }
    try {
      final List<MembershipProduct> products =
          await ref.read(membershipServiceProvider).loadProducts();
      if (!mounted) return;
      setState(() {
        storeProducts = products;
        productsLoading = false;
        productsDiagnostic = null;
        productsError = products.isEmpty ? 'App Store 中没有找到可购买的会员商品' : null;
        if (products.isNotEmpty &&
            !products.any((MembershipProduct product) => product.plan == selected)) {
          selected = products.first.plan;
        }
      });
    } on MembershipFailure catch (error) {
      if (!mounted) return;
      debugPrint(
        '[Membership] StoreKit product loading failed: '
        '${error.code}; ${error.details ?? 'no details'}',
      );
      setState(() {
        storeProducts = const [];
        productsLoading = false;
        productsDiagnostic = error.details == null
            ? error.code
            : '${error.code}\n${error.details}';
        productsError = _storeFailureMessage(error);
      });
    } catch (error, stackTrace) {
      if (!mounted) return;
      debugPrint('[Membership] Unexpected product loading error: $error');
      debugPrintStack(stackTrace: stackTrace);
      setState(() {
        storeProducts = const [];
        productsLoading = false;
        productsDiagnostic = error.toString();
        productsError = '暂时无法加载 App Store 商品，请稍后重试';
      });
    }
  }

  Future<void> _purchase() async {
    if (!storeProducts.any((MembershipProduct product) => product.plan == selected)) {
      return;
    }
    setState(() => busy = true);
    try {
      await ref.read(membershipServiceProvider).purchase(selected);
    } on MembershipFailure catch (error) {
      if (mounted) {
        debugPrint(
          '[Membership] StoreKit purchase failed: '
          '${error.code}; ${error.details ?? 'no details'}',
        );
        _showMessage(_storeFailureMessage(error));
      }
    } catch (error, stackTrace) {
      if (mounted) {
        debugPrint('[Membership] Unexpected purchase error: $error');
        debugPrintStack(stackTrace: stackTrace);
        _showMessage('暂时无法发起购买，请稍后重试');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _restore() async {
    setState(() => busy = true);
    try {
      await ref.read(membershipServiceProvider).restorePurchases();
    } on MembershipFailure catch (error) {
      if (mounted) {
        debugPrint(
          '[Membership] StoreKit restore failed: '
          '${error.code}; ${error.details ?? 'no details'}',
        );
        _showMessage(_storeFailureMessage(error));
      }
    } catch (error, stackTrace) {
      if (mounted) {
        debugPrint('[Membership] Unexpected restore error: $error');
        debugPrintStack(stackTrace: stackTrace);
        _showMessage('暂时无法恢复购买，请稍后重试');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _purchaseEvent(MembershipPurchaseEvent event) {
    if (!mounted) return;
    setState(
      () => busy = event.stage == MembershipPurchaseStage.restoreStarted,
    );
    if (event.code != null || event.message != null) {
      debugPrint(
        '[Membership] Purchase event ${event.stage.name}: '
        '${event.code ?? 'no code'}; ${event.message ?? 'no details'}',
      );
    }
    final String message = switch (event.stage) {
      MembershipPurchaseStage.pending => '购买正在等待确认',
      MembershipPurchaseStage.purchased => '会员已开通',
      MembershipPurchaseStage.restoreStarted => '正在检查历史购买',
      MembershipPurchaseStage.restored => '会员权益已恢复',
      MembershipPurchaseStage.restoreNotFound => '没有找到可恢复的购买记录',
      MembershipPurchaseStage.verificationDeferred =>
        '购买已收到且不会丢失，请恢复网络后返回会员详情并点击恢复购买',
      MembershipPurchaseStage.cancelled => '已取消购买',
      MembershipPurchaseStage.failed => event.code == null
          ? '购买验证失败，请稍后重试'
          : _storeFailureMessage(MembershipFailure(event.code!, event.message)),
    };
    _showMessage(message);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _manageSubscription() => launchUrl(
        Uri.parse('https://apps.apple.com/account/subscriptions'),
        mode: LaunchMode.externalApplication,
      );

  Future<void> _legal({required bool privacy}) => launchUrl(
        Uri.parse(privacy ? AppLegalUrls.privacyPolicy : AppLegalUrls.termsOfUse),
        mode: LaunchMode.externalApplication,
      );
}

class _MembershipHero extends StatelessWidget {
  const _MembershipHero({required this.snapshot, required this.signedIn});

  final MembershipSnapshot snapshot;
  final bool signedIn;

  @override
  Widget build(BuildContext context) {
    final bool trial = signedIn && snapshot.state == MembershipState.trial;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFE9C7), Color(0xFFFFDDE5)],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFFFD7A3)),
      ),
      child: Column(
        children: [
          const Icon(CupertinoIcons.sparkles, color: AppColors.accent, size: 38),
          const SizedBox(height: 12),
          Text(
            trial ? '3 天完整体验已开启' : 'SayPal 会员',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 6),
          Text(
            trial
                ? _remaining(snapshot.expiresAt)
                : '解锁全部情景口语内容，陪伴孩子开口说英语。',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _ProductOption extends StatelessWidget {
  const _ProductOption({
    required this.product,
    required this.selected,
    required this.recommended,
    required this.onTap,
  });

  final MembershipProduct product;
  final bool selected;
  final bool recommended;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFFFF2DE) : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? AppColors.accent : AppColors.outline,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Icon(
                selected
                    ? CupertinoIcons.check_mark_circled_solid
                    : CupertinoIcons.circle,
                color: selected ? AppColors.accent : AppColors.textSecondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _planLabel(product.plan),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (recommended) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              '推荐',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      switch (product.plan) {
                        MembershipPlan.monthly => '每月自动续费，可随时取消',
                        MembershipPlan.annual => '每年自动续费，推荐选择',
                        MembershipPlan.lifetime => '一次购买，永久使用',
                      },
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              Text(
                product.displayPrice,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _planLabel(MembershipPlan? plan) => switch (plan) {
      MembershipPlan.monthly => '月度会员',
      MembershipPlan.annual => '年度会员',
      MembershipPlan.lifetime => '终身会员',
      null => '会员',
    };

String _storeFailureMessage(MembershipFailure failure) {
  return switch (failure.code) {
    'store_availability_timeout' ||
    'product_query_timeout' ||
    'purchase_timeout' ||
    'restore_timeout' =>
      '连接 App Store 超时，请检查网络后重试',
    'store_unavailable' => '当前设备暂时无法使用 App Store 购买',
    'store_availability_failed' =>
      '无法检查 App Store 购买服务，请确认设备已登录 Apple 账户并可正常访问 App Store',
    'product_query_failed' =>
      'App Store 未能返回会员商品。请检查付费协议、商品价格与可用地区，或稍后等待配置同步',
    'products_not_found' || 'product_not_found' =>
      'App Store 中没有找到这个会员商品，请确认商品已配置并可销售',
    'products_invalid_configuration' =>
      '会员商品类型配置不正确：月卡和年卡应为自动续期订阅，终身会员应为非消耗型项目',
    'product_unavailable' =>
      'App Store 已返回商品，但目前不允许购买。请检查商品是否可销售、价格和销售地区是否生效，并使用沙盒 Apple 账户重试',
    'purchase_not_allowed' =>
      '此 Apple 账户或设备当前禁止 App 内购买，请检查"屏幕使用时间"的购买限制',
    'duplicate_purchase_pending' =>
      '这笔商品已有一项交易等待处理，请保持联网，完成验证后再试',
    'purchase_cancelled' => '已取消购买',
    'store_network_error' => 'App Store 网络连接失败，请检查网络后重试',
    'authentication_required' => '请先登录后再购买会员',
    'apple_transaction_bound_to_another_account' =>
      '这笔 Apple 购买已绑定到另一个 SayPal 账号，请登录原账号后恢复购买',
    'verification_deferred' =>
      '购买已收到，但会员验证网络暂时不可用；请恢复网络后点击"恢复购买"',
    'complete_purchase_timeout' || 'complete_purchase_failed' =>
      '会员已在服务端确认，App Store 交易仍在同步，请稍后刷新会员详情',
    'purchase_not_started' => '购买没有成功发起，请稍后重试',
    'purchase_failed' => 'App Store 未能发起购买，请检查 Apple 账户与购买限制后重试',
    'restore_failed' => '暂时无法恢复购买，请稍后重试',
    _ => '暂时无法连接 App Store，请稍后重试',
  };
}

String _purchaseButtonLabel(MembershipPlan plan) => switch (plan) {
      MembershipPlan.monthly => '订阅月度会员',
      MembershipPlan.annual => '订阅年度会员',
      MembershipPlan.lifetime => '购买终身会员',
    };

String _remaining(DateTime? expiresAt) {
  if (expiresAt == null) return '正在同步到期时间';
  final Duration remaining = expiresAt.difference(DateTime.now().toUtc());
  if (remaining <= Duration.zero) return '体验已结束';
  if (remaining.inHours < 24) {
    final int hours = (remaining.inMinutes / Duration.minutesPerHour).ceil();
    return '剩余 $hours 小时';
  }
  final int days = (remaining.inMinutes / Duration.minutesPerDay).ceil();
  return '剩余 $days 天';
}
