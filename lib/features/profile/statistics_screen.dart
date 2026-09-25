import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/neumorphic.dart';
import '../../data/providers.dart';
import '../../models/models.dart';
import '../discover/job_card.dart';

/// Statistics (04_UIUX_Design.md §4.7) — fl_chart inside soft cards.
class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = ref.watch(applicationCardsProvider).valueOrNull ?? [];
    final matches = ref.watch(matchesProvider).valueOrNull ?? [];
    final palette = NeuPalette.of(context);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Row(
              children: [
                NeuIconButton(
                  icon: Icons.arrow_back,
                  onPressed: () => context.pop(),
                  size: 46,
                  tooltip: 'Back',
                ),
                const SizedBox(width: 14),
                Text('Statistics', style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 18),
            if (cards.isEmpty && matches.isEmpty)
              const EmptyState(
                icon: Icons.insights,
                message: 'Not much to chart yet — save a few jobs and track '
                    'applications to fill this in.',
              )
            else ...[
              _ChartCard(
                title: 'Applications over time',
                subtitle: 'Tracker entries added per week (last 8 weeks)',
                child: SizedBox(
                  height: 180,
                  child: _ApplicationsOverTime(cards: cards),
                ),
              ),
              const SizedBox(height: 18),
              _ChartCard(
                title: 'Status funnel',
                subtitle: 'Where your pipeline currently stands',
                child: SizedBox(
                  height: 200,
                  child: _StatusFunnel(cards: cards),
                ),
              ),
              const SizedBox(height: 18),
              _ChartCard(
                title: 'Match-score distribution',
                subtitle: 'All scored jobs against your profile',
                child: SizedBox(
                  height: 180,
                  child: _ScoreDistribution(matches: matches),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Scores are explainable: skills 40 · title 25 · location 20 · '
                'experience 10 · freshness 5.',
                style: Theme.of(context).textTheme.labelSmall!.copyWith(
                    color: palette.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

FlTitlesData _titles({
  required Widget Function(double) bottom,
  bool showLeft = true,
}) {
  return FlTitlesData(
    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    leftTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: showLeft,
        reservedSize: 30,
        getTitlesWidget: (value, meta) => Text(
          value.toInt().toString(),
          style: const TextStyle(fontSize: 10),
        ),
      ),
    ),
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 28,
        getTitlesWidget: (value, meta) => Padding(
          padding: const EdgeInsets.only(top: 6),
          child: bottom(value),
        ),
      ),
    ),
  );
}

class _ApplicationsOverTime extends StatelessWidget {
  const _ApplicationsOverTime({required this.cards});

  final List<ApplicationCardModel> cards;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final buckets = List<double>.filled(8, 0);
    for (final card in cards) {
      final weeksAgo = now.difference(card.application.createdAt).inDays ~/ 7;
      if (weeksAgo >= 0 && weeksAgo < 8) {
        buckets[7 - weeksAgo] += 1;
      }
    }
    final spots = [
      for (var i = 0; i < 8; i++) FlSpot(i.toDouble(), buckets[i]),
    ];
    final maxY = buckets.reduce((a, b) => a > b ? a : b);

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: (maxY + 1).clamp(2, double.infinity),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (v) => FlLine(
            color: NeuPalette.of(context).track,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: _titles(
          bottom: (v) {
            final weekLabel = 8 - v.toInt();
            return Text(weekLabel <= 0 ? 'now' : '-${weekLabel}w',
                style: const TextStyle(fontSize: 10));
          },
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Luna.luna500,
            barWidth: 3,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, bar, index) =>
                  FlDotCirclePainter(
                radius: 3,
                color: Luna.luna300,
                strokeWidth: 0,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: fade(Luna.luna500, 0.10),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusFunnel extends StatelessWidget {
  const _StatusFunnel({required this.cards});

  final List<ApplicationCardModel> cards;

  @override
  Widget build(BuildContext context) {
    const statuses = ApplicationStatus.values;
    final counts = {for (final s in statuses) s: 0};
    for (final card in cards) {
      counts[card.application.status] = counts[card.application.status]! + 1;
    }
    final maxY =
        counts.values.reduce((a, b) => a > b ? a : b).toDouble().clamp(1, 20);

    return BarChart(
      BarChartData(
        minY: 0,
        maxY: maxY + 1,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (v) => FlLine(
            color: NeuPalette.of(context).track,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: _titles(
          bottom: (v) {
            final i = v.toInt();
            if (i < 0 || i >= statuses.length) return const SizedBox.shrink();
            final label = statuses[i].label;
            return Text(
              label.length > 6 ? '${label.substring(0, 6)}.' : label,
              style: const TextStyle(fontSize: 9),
            );
          },
        ),
        barGroups: [
          for (var i = 0; i < statuses.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: counts[statuses[i]]!.toDouble(),
                  color: i == 0 ? Luna.luna300 : Luna.luna500,
                  width: 14,
                  borderRadius: BorderRadius.circular(6),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ScoreDistribution extends StatelessWidget {
  const _ScoreDistribution({required this.matches});

  final List<JobMatch> matches;

  @override
  Widget build(BuildContext context) {
    const labels = ['0–49', '50–59', '60–69', '70–79', '80–89', '90+'];
    final buckets = List<double>.filled(6, 0);
    for (final m in matches) {
      final s = m.matchScore;
      final i = s >= 90
          ? 5
          : s >= 80
              ? 4
              : s >= 70
                  ? 3
                  : s >= 60
                      ? 2
                      : s >= 50
                          ? 1
                          : 0;
      buckets[i] += 1;
    }
    final maxY = buckets.reduce((a, b) => a > b ? a : b).toDouble().clamp(1, 50);

    return BarChart(
      BarChartData(
        minY: 0,
        maxY: maxY + 1,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (v) => FlLine(
            color: NeuPalette.of(context).track,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: _titles(
          bottom: (v) {
            final i = v.toInt();
            if (i < 0 || i >= labels.length) return const SizedBox.shrink();
            return Text(labels[i], style: const TextStyle(fontSize: 9));
          },
        ),
        barGroups: [
          for (var i = 0; i < buckets.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: buckets[i],
                  color: i >= 3 ? Luna.luna500 : Luna.luna300,
                  width: 16,
                  borderRadius: BorderRadius.circular(6),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
