import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../models/learning_stats.dart';
import '../providers/statistics_providers.dart';

/// 统计分析页（"我的"内入口）：近 7 日时长、开口次数、发音、流畅度与薄弱词。
class StatisticsPage extends ConsumerWidget {
  const StatisticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<StatisticsSummary> summary =
        ref.watch(statisticsSummaryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('学习统计')),
      body: summary.when(
        loading: () => const LoadingView(),
        error: (Object e, StackTrace s) => ErrorStateView(
          title: '统计打不开啦',
          message: '请稍后再试一次。',
          onRetry: () => ref.invalidate(statisticsSummaryProvider),
        ),
        data: (StatisticsSummary data) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _StatTile(
                      emoji: '⏱️',
                      label: '近 7 天时长',
                      value: '${data.totalMinutes} 分钟',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatTile(
                      emoji: '💬',
                      label: '开口次数',
                      value: '${data.totalSpeakingCount} 次',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ContentCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader(title: '每天学习时长'),
                    _DurationBarChart(
                      days: data.days.isEmpty ? _emptyDays() : data.days,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ContentCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader(title: '口语表现（近 7 天均值）'),
                    ..._scoreRows(data.days),
                    if (data.days.every(
                      (DailyLearningStats d) =>
                          d.pronunciationScore == 0 && d.fluencyScore == 0,
                    ))
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          '还没有口语评分记录，先去聊一聊吧！',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ContentCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader(title: '经常读错的词'),
                    if (data.weakWords.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          '暂时没有发现薄弱词，太棒啦！',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final WeakWordStat word in data.weakWords)
                            _WeakWordChip(word: word),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '当前为演示评分数据，仅用于了解学习趋势。',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<DailyLearningStats> _emptyDays() {
    final DateTime today = DateTime.now();
    return List<DailyLearningStats>.generate(
      7,
      (int i) => DailyLearningStats(
        date: DateTime(today.year, today.month, today.day)
            .subtract(Duration(days: 6 - i)),
        minutes: 0,
        speakingCount: 0,
        pronunciationScore: 0,
        fluencyScore: 0,
      ),
    );
  }

  List<Widget> _scoreRows(List<DailyLearningStats> days) {
    int averageOf(int Function(DailyLearningStats) pick) {
      final List<int> values = days
          .map(pick)
          .where((int v) => v > 0)
          .toList();
      if (values.isEmpty) {
        return 0;
      }
      return values.reduce((int a, int b) => a + b) ~/ values.length;
    }

    return [
      _ScoreRow(label: '发音', score: averageOf((DailyLearningStats d) => d.pronunciationScore)),
      const SizedBox(height: 10),
      _ScoreRow(label: '流畅度', score: averageOf((DailyLearningStats d) => d.fluencyScore)),
    ];
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.emoji, required this.label, required this.value});

  final String emoji;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ContentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 26)),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// 近 7 日时长柱状图（自绘，保证高对比与零外部依赖）。
class _DurationBarChart extends StatelessWidget {
  const _DurationBarChart({required this.days});

  final List<DailyLearningStats> days;

  @override
  Widget build(BuildContext context) {
    final int maxMinutes = days.fold<int>(
      1,
      (int m, DailyLearningStats d) => m > d.minutes ? m : d.minutes,
    );
    return SizedBox(
      height: 150,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final DailyLearningStats day in days)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      day.minutes > 0 ? '${day.minutes}' : '',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    FractionallySizedBox(
                      widthFactor: 0.6,
                      child: Container(
                        height:
                            80 * (day.minutes / maxMinutes).clamp(0.03, 1.0),
                        decoration: BoxDecoration(
                          color: day.minutes > 0
                              ? AppColors.primary
                              : AppColors.surfaceMuted,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      day.weekdayZh,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({required this.label, required this.score});

  final String label;
  final int score;

  Color get _color {
    if (score <= 0) {
      return AppColors.surfaceMuted;
    }
    if (score >= 80) {
      return AppColors.success;
    }
    if (score >= 60) {
      return AppColors.warning;
    }
    return AppColors.danger;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 64,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 14,
              child: Stack(
                children: [
                  Container(color: AppColors.surfaceMuted),
                  FractionallySizedBox(
                    widthFactor: (score / 100).clamp(0.0, 1.0),
                    child: Container(color: _color),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 44,
          child: Text(
            score > 0 ? '$score 分' : '—',
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _WeakWordChip extends StatelessWidget {
  const _WeakWordChip({required this.word});

  final WeakWordStat word;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
      ),
      child: Text(
        '${word.word} ×${word.count}',
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.danger,
        ),
      ),
    );
  }
}
