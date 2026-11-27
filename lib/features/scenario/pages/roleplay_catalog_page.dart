import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../statistics/models/learning_stats.dart';
import '../../statistics/providers/statistics_providers.dart';
import '../data/video_roleplay_lessons.dart';
import '../models/practice_catalog.dart';
import '../providers/practice_providers.dart';
import '../widgets/roleplay_artwork.dart';

class RoleplayCatalogPage extends ConsumerWidget {
  const RoleplayCatalogPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Load the small course catalog while the main scenario page is open.
    ref.listen(videoRoleplayLessonsProvider, (_, _) {});
    final AsyncValue<RoleplayCatalog> value =
        ref.watch(roleplayCollectionProvider);
    final Set<String> favorites =
        ref.watch(roleplayFavoritesProvider).valueOrNull ?? const <String>{};
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FC),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            _CatalogHeader(
              onHistory: () => _showHistory(context, ref, value.valueOrNull),
              onFavorites: () => _showFavorites(
                context,
                value.valueOrNull?.scenarios ?? const <RoleplayScenario>[],
                favorites,
              ),
            ),
            Expanded(
              child: value.when(
                loading: () => const LoadingView(),
                error: (_, __) => ErrorStateView(
                  title: '暂时无法加载场景',
                  message: '请稍后再试一次。',
                  onRetry: () => ref.invalidate(roleplayCollectionProvider),
                ),
                data: (RoleplayCatalog catalog) =>
                    _CatalogBody(catalog: catalog),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showHistory(
    BuildContext context,
    WidgetRef ref,
    RoleplayCatalog? catalog,
  ) async {
    final List<SessionLearningRecord> records =
        await ref.read(learningRecordRepositoryProvider).loadAllRecords();
    final List<CustomSceneDraft> drafts =
        await ref.read(customScenesProvider.future);
    if (!context.mounted) return;
    final Map<String, RoleplayScenario> official = <String, RoleplayScenario>{
      for (final RoleplayScenario item
          in catalog?.scenarios ?? const <RoleplayScenario>[])
        item.id: item,
    };
    final Map<String, CustomSceneDraft> custom = <String, CustomSceneDraft>{
      for (final CustomSceneDraft item in drafts) item.id: item,
    };
    final Set<String> seen = <String>{};
    final videos = {
      for (final lesson in ref.read(videoRoleplayLessonsProvider).valueOrNull ??
          const <VideoRoleplayLesson>[])
        lesson.catalogId: lesson,
    };
    final List<_HistoryItem> history = records.reversed
        .where((SessionLearningRecord item) =>
            item.feature == '情景扮演' &&
            item.contentId != null &&
            seen.add(item.contentId!))
        .map((SessionLearningRecord item) {
          final RoleplayScenario? scenario = official[item.contentId];
          final CustomSceneDraft? draft = custom[item.contentId];
          final video = videos[item.contentId];
          final videoRoute = VideoRoleplayLesson.routeFromCatalogId(item.contentId);
          return _HistoryItem(
            title: video?.title ?? scenario?.title ?? draft?.title ??
                (videoRoute != null ? '视频情景陪练' : '已完成的情景'),
            subtitle: video?.englishTitle ??
                scenario?.situation ??
                draft?.situation ??
                '情景练习',
            route: videoRoute ??
                (scenario != null
                    ? '/scenario/roleplay/${scenario.id}'
                    : '/scenario/roleplay/custom/saved'),
          );
        })
        .take(8)
        .toList();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (BuildContext sheetContext) => _HistorySheet(
        items: history,
        onOpen: (_HistoryItem item) {
          Navigator.of(sheetContext).pop();
          context.push(item.route);
        },
      ),
    );
  }

  Future<void> _showFavorites(
    BuildContext context,
    List<RoleplayScenario> scenarios,
    Set<String> favoriteIds,
  ) async {
    final List<RoleplayScenario> favorites = scenarios
        .where((RoleplayScenario item) => favoriteIds.contains(item.id))
        .toList();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (BuildContext sheetContext) => _FavoritesSheet(
        scenarios: favorites,
        onOpen: (RoleplayScenario item) {
          Navigator.of(sheetContext).pop();
          context.push('/scenario/roleplay/${item.id}');
        },
      ),
    );
  }
}

class _CatalogHeader extends StatelessWidget {
  const _CatalogHeader({required this.onHistory, required this.onFavorites});

  final VoidCallback onHistory;
  final VoidCallback onFavorites;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 18, 10),
        child: Row(
          children: <Widget>[
            const Expanded(
              child: Text(
                '角色扮演合集',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
              ),
            ),
            GlassIconButton(
              key: const ValueKey<String>('roleplay-history-button'),
              size: 44,
              iconSize: 22,
              useOwnLayer: true,
              onPressed: onHistory,
              icon: const Icon(Icons.history_rounded),
            ),
            const SizedBox(width: 8),
            GlassIconButton(
              key: const ValueKey<String>('roleplay-favorites-button'),
              size: 44,
              iconSize: 21,
              useOwnLayer: true,
              onPressed: onFavorites,
              icon: const Icon(Icons.bookmark_border_rounded),
            ),
          ],
        ),
      );
}

class _CatalogBody extends StatelessWidget {
  const _CatalogBody({required this.catalog});

  final RoleplayCatalog catalog;

  @override
  Widget build(BuildContext context) {
    final List<RoleplayScenario> featured = catalog.scenarios
        .where((RoleplayScenario item) => item.featuredOrder != null)
        .toList()
      ..sort((RoleplayScenario a, RoleplayScenario b) =>
          a.featuredOrder!.compareTo(b.featuredOrder!));
    return ListView(
      key: const PageStorageKey<String>('roleplay-catalog-list'),
      padding: const EdgeInsets.only(bottom: 132),
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              leading: const Icon(Icons.ondemand_video_rounded),
              title: const Text('视频情景陪练'),
              subtitle: const Text('看完教学视频，和 AI 练习同一个场景'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push('/scenario/video-practice'),
            ),
          ),
        ),
        _SectionHeader(
          title: '为你推荐',
          action: '查看全部',
          onAction: () => context.push('/scenario/roleplay/recommended'),
        ),
        SizedBox(
          height: 292,
          child: ListView.separated(
            key: const ValueKey<String>('roleplay-featured-list'),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: featured.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (BuildContext context, int index) =>
                _FeaturedCard(item: featured[index]),
          ),
        ),
        const SizedBox(height: 28),
        const _SectionHeader(title: '分类主题'),
        SizedBox(
          height: 178,
          child: ListView.separated(
            key: const ValueKey<String>('roleplay-category-list'),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: catalog.categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (BuildContext context, int index) => _CategoryCard(
              category: catalog.categories[index],
              onTap: () => context.push(
                '/scenario/roleplay/category/${catalog.categories[index].id}',
              ),
            ),
          ),
        ),
        const SizedBox(height: 30),
        const _SectionHeader(title: '自定义场景'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _CustomSceneEntry(
            onTap: () => context.push('/scenario/roleplay/custom'),
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (action != null)
              TextButton(
                key: const ValueKey<String>('roleplay-view-all'),
                onPressed: onAction,
                child: Text(action!),
              ),
          ],
        ),
      );
}

class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({required this.item});

  final RoleplayScenario item;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        elevation: 1,
        shadowColor: const Color(0x1A15213A),
        borderRadius: BorderRadius.circular(26),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey<String>('featured-${item.id}'),
          onTap: () => context.push('/scenario/roleplay/${item.id}'),
          child: SizedBox(
            width: 228,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  width: double.infinity,
                  height: 194,
                  child: RoleplayArtwork(
                    asset: item.imageAsset,
                    fallback: const Color(0xFFE8EEFA),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
                  child: Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    item.difficulty,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.category, required this.onTap});

  final RoleplayCategory category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: roleplayHexColor(category.startColor),
        borderRadius: BorderRadius.circular(25),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey<String>('roleplay-category-${category.id}'),
          onTap: onTap,
          child: SizedBox(
            width: 318,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                RoleplayArtwork(
                  asset: category.imageAsset,
                  fallback: roleplayHexColor(category.startColor),
                  alignment: Alignment.centerRight,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 22, 178, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        category.title,
                        style: const TextStyle(
                          fontSize: 23,
                          height: 1.1,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        category.subtitle,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF42516A),
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _CustomSceneEntry extends StatelessWidget {
  const _CustomSceneEntry({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const ValueKey<String>('create-roleplay-entry'),
          onTap: onTap,
          child: Container(
            height: 142,
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[Color(0xFFF2F5FF), Color(0xFFECE6FF)],
              ),
            ),
            child: Row(
              children: <Widget>[
                const Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '创建你的专属情景',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 7),
                      Text(
                        '设置角色、背景和练习目标',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 82,
                  height: 82,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .78),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(
                    Icons.edit_note_rounded,
                    color: AppColors.primary,
                    size: 40,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _HistoryItem {
  const _HistoryItem({
    required this.title,
    required this.subtitle,
    required this.route,
  });

  final String title, subtitle, route;
}

class _HistorySheet extends StatelessWidget {
  const _HistorySheet({required this.items, required this.onOpen});

  final List<_HistoryItem> items;
  final ValueChanged<_HistoryItem> onOpen;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text('练习历史',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 14),
              if (items.isEmpty)
                const _SheetEmpty(message: '完成一次情景练习后，会保存在这里')
              else
                for (final _HistoryItem item in items)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    onTap: () => onOpen(item),
                    leading: const Icon(Icons.history_rounded),
                    title: Text(item.title),
                    subtitle: Text(item.subtitle,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: const Icon(Icons.chevron_right_rounded),
                  ),
            ],
          ),
        ),
      );
}

class _FavoritesSheet extends StatelessWidget {
  const _FavoritesSheet({required this.scenarios, required this.onOpen});

  final List<RoleplayScenario> scenarios;
  final ValueChanged<RoleplayScenario> onOpen;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text('收藏场景',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 14),
              if (scenarios.isEmpty)
                const _SheetEmpty(message: '收藏常用场景后，可以从这里快速进入')
              else
                for (final RoleplayScenario scenario in scenarios)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    onTap: () => onOpen(scenario),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: RoleplayArtwork(
                          asset: scenario.imageAsset,
                          fallback: const Color(0xFFE8EEFA),
                        ),
                      ),
                    ),
                    title: Text(scenario.title),
                    subtitle: Text(scenario.difficulty),
                    trailing: const Icon(Icons.chevron_right_rounded),
                  ),
            ],
          ),
        ),
      );
}

class _SheetEmpty extends StatelessWidget {
  const _SheetEmpty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      );
}
