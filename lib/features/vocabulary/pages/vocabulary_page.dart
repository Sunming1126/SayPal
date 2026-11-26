import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../models/vocab_models.dart';
import '../providers/vocabulary_providers.dart';

/// 只复习用户真实保存的生词，不生成虚假的复习次数或评分。
class ReviewPage extends ConsumerStatefulWidget {
  const ReviewPage({super.key, this.showBackButton = false});

  final bool showBackButton;

  @override
  ConsumerState<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends ConsumerState<ReviewPage> {
  final TextEditingController _search = TextEditingController();
  String _source = '全部';

  @override
  void initState() {
    super.initState();
    _search.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _search
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<VocabWord>> words = ref.watch(vocabularyListProvider);
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFF),
      body: SafeArea(
        bottom: false,
        child: words.when(
          loading: () => const LoadingView(),
          error: (Object error, StackTrace stack) => ErrorStateView(
            title: '暂时无法打开生词本',
            message: '请稍后再试一次。',
            onRetry: () => ref.invalidate(vocabularyListProvider),
          ),
          data: _buildContent,
        ),
      ),
    );
  }

  Widget _buildContent(List<VocabWord> allWords) {
    final String query = _search.text.trim().toLowerCase();
    final List<String> sources = <String>[
      '全部',
      ...allWords
          .map((VocabWord word) => word.source?.trim())
          .whereType<String>()
          .where((String source) => source.isNotEmpty)
          .toSet(),
    ];
    if (!sources.contains(_source)) _source = '全部';
    final List<VocabWord> visible = allWords.where((VocabWord word) {
      final bool matchesSource =
          _source == '全部' || word.source?.trim() == _source;
      final bool matchesQuery = query.isEmpty ||
          word.word.toLowerCase().contains(query) ||
          word.meaningZh.toLowerCase().contains(query);
      return matchesSource && matchesQuery;
    }).toList();

    return ListView(
      key: const PageStorageKey<String>('review-list'),
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 118),
      children: <Widget>[
        Row(
          children: <Widget>[
            if (widget.showBackButton) ...<Widget>[
              GlassIconButton(
                size: 44,
                iconSize: 23,
                useOwnLayer: true,
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
              ),
              const SizedBox(width: 12),
            ],
            const Expanded(
              child: Text(
                '复习',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '${allWords.length} 个生词',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        TextField(
          key: const ValueKey<String>('review-search-field'),
          controller: _search,
          decoration: InputDecoration(
            hintText: '搜索单词或释义',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: query.isEmpty
                ? null
                : IconButton(
                    tooltip: '清空搜索',
                    onPressed: _search.clear,
                    icon: const Icon(Icons.close_rounded),
                  ),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(color: AppColors.outline),
            ),
          ),
        ),
        if (sources.length > 1) ...<Widget>[
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                for (final String source in sources)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(source),
                      selected: _source == source,
                      onSelected: (_) => setState(() => _source = source),
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 22),
        if (allWords.isEmpty)
          const _ReviewEmptyState()
        else if (visible.isEmpty)
          const _NoSearchResult()
        else ...<Widget>[
          const Text(
            '我的生词',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          for (final VocabWord word in visible) ...<Widget>[
            _WordCard(
              word: word,
              onDelete: () => ref
                  .read(vocabularyListProvider.notifier)
                  .removeWord(word.word),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ],
    );
  }
}

/// 保留给旧链接和“我的”页入口的全屏生词本。
class VocabularyPage extends StatelessWidget {
  const VocabularyPage({super.key});

  @override
  Widget build(BuildContext context) => const ReviewPage(showBackButton: true);
}

class _WordCard extends StatelessWidget {
  const _WordCard({required this.word, required this.onDelete});

  final VocabWord word;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => ContentCard(
        padding: const EdgeInsets.fromLTRB(18, 16, 10, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 9,
                    runSpacing: 4,
                    children: <Widget>[
                      Text(
                        word.word,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (word.phonetic?.isNotEmpty == true)
                        Text(
                          word.phonetic!,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(word.meaningZh, style: const TextStyle(fontSize: 16)),
                  if (word.exampleEn?.isNotEmpty == true) ...<Widget>[
                    const SizedBox(height: 10),
                    Text(
                      word.exampleEn!,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                  if (word.source?.isNotEmpty == true) ...<Widget>[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '来自 ${word.source}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              tooltip: '移出生词本',
              onPressed: onDelete,
              icon: const Icon(Icons.bookmark_remove_outlined),
            ),
          ],
        ),
      );
}

class _ReviewEmptyState extends StatelessWidget {
  const _ReviewEmptyState();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 56),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: AppColors.outline),
        ),
        child: const Column(
          children: <Widget>[
            Icon(Icons.bookmark_border_rounded,
                size: 44, color: AppColors.primary),
            SizedBox(height: 16),
            Text(
              '还没有保存的生词',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            SizedBox(height: 7),
            Text(
              '在对话或情景练习中保存单词后，可以在这里集中复习。',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, height: 1.5),
            ),
          ],
        ),
      );
}

class _NoSearchResult extends StatelessWidget {
  const _NoSearchResult();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: <Widget>[
            Icon(Icons.search_off_rounded,
                size: 40, color: AppColors.textSecondary),
            SizedBox(height: 12),
            Text('没有找到匹配的单词'),
          ],
        ),
      );
}
