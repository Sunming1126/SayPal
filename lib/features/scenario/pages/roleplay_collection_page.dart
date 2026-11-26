import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../models/practice_catalog.dart';
import '../providers/practice_providers.dart';
import '../widgets/roleplay_artwork.dart';

class RoleplayCollectionPage extends ConsumerStatefulWidget {
  const RoleplayCollectionPage.category({required this.categoryId, super.key})
      : recommendedOnly = false;

  const RoleplayCollectionPage.recommended({super.key})
      : categoryId = null,
        recommendedOnly = true;

  final String? categoryId;
  final bool recommendedOnly;

  @override
  ConsumerState<RoleplayCollectionPage> createState() =>
      _RoleplayCollectionPageState();
}

class _RoleplayCollectionPageState
    extends ConsumerState<RoleplayCollectionPage> {
  late final PageController _controller;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: .88);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<RoleplayCatalog> value =
        ref.watch(roleplayCollectionProvider);
    return value.when(
      loading: () => const Scaffold(body: LoadingView()),
      error: (_, __) => const Scaffold(
        body: ErrorStateView(title: '场景加载失败', message: '请稍后再试。'),
      ),
      data: _buildCollection,
    );
  }

  Widget _buildCollection(RoleplayCatalog catalog) {
    RoleplayCategory? category;
    if (!widget.recommendedOnly) {
      for (final RoleplayCategory item in catalog.categories) {
        if (item.id == widget.categoryId) category = item;
      }
    }
    final List<RoleplayScenario> scenarios = widget.recommendedOnly
        ? (catalog.scenarios
            .where((RoleplayScenario item) => item.featuredOrder != null)
            .toList()
          ..sort((RoleplayScenario a, RoleplayScenario b) =>
              a.featuredOrder!.compareTo(b.featuredOrder!)))
        : catalog.scenarios
            .where((RoleplayScenario item) => item.categoryId == category?.id)
            .toList();
    final Color start = widget.recommendedOnly
        ? const Color(0xFFE8EEFF)
        : roleplayHexColor(category?.startColor ?? '#E8EEFF');
    final Color end = widget.recommendedOnly
        ? const Color(0xFFF5DDE5)
        : roleplayHexColor(category?.endColor ?? '#F5DDE5');
    final String title = widget.recommendedOnly ? '为你推荐' : category?.title ?? '';
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[start, end],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: <Widget>[
              _CollectionHeader(title: title),
              if (scenarios.isEmpty)
                const Expanded(
                  child: ErrorStateView(
                    title: '这个合集还在整理中',
                    message: '稍后再来看看。',
                  ),
                )
              else ...<Widget>[
                Expanded(
                  child: PageView.builder(
                    key: const ValueKey<String>('roleplay-collection-pages'),
                    controller: _controller,
                    itemCount: scenarios.length,
                    onPageChanged: (int index) =>
                        setState(() => _currentPage = index),
                    itemBuilder: (BuildContext context, int index) =>
                        Padding(
                      padding: const EdgeInsets.fromLTRB(7, 28, 7, 18),
                      child: _ScenarioPageCard(item: scenarios[index]),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 22),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      for (int index = 0; index < scenarios.length; index++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: index == _currentPage ? 22 : 7,
                          height: 7,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: index == _currentPage
                                ? AppColors.primaryDark
                                : Colors.white.withValues(alpha: .68),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CollectionHeader extends StatelessWidget {
  const _CollectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 64,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Positioned(
              left: 18,
              child: GlassIconButton(
                key: const ValueKey<String>('roleplay-collection-back'),
                size: 44,
                iconSize: 23,
                useOwnLayer: true,
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 76),
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      );
}

class _ScenarioPageCard extends ConsumerWidget {
  const _ScenarioPageCard({required this.item});

  final RoleplayScenario item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Set<String> favorites =
        ref.watch(roleplayFavoritesProvider).valueOrNull ?? const <String>{};
    final bool favorite = favorites.contains(item.id);
    return Material(
      color: Colors.white,
      elevation: 4,
      shadowColor: const Color(0x2815213A),
      borderRadius: BorderRadius.circular(34),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
        child: Column(
          children: <Widget>[
            Stack(
              children: <Widget>[
                AspectRatio(
                  aspectRatio: 1.08,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: RoleplayArtwork(
                      asset: item.imageAsset,
                      fallback: const Color(0xFFE8EEFA),
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Material(
                    color: Colors.white.withValues(alpha: .86),
                    shape: const CircleBorder(),
                    child: IconButton(
                      key: ValueKey<String>('collection-favorite-${item.id}'),
                      tooltip: favorite ? '取消收藏' : '收藏',
                      onPressed: () => ref
                          .read(roleplayFavoritesProvider.notifier)
                          .toggle(item.id),
                      icon: Icon(
                        favorite
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                        color: favorite
                            ? AppColors.primary
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              item.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              item.situation,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 15,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                item.difficulty,
                style: const TextStyle(
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                key: ValueKey<String>('start-roleplay-${item.id}'),
                onPressed: () =>
                    context.push('/scenario/roleplay/${item.id}'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF172033),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: const Text(
                  '开始练习',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
