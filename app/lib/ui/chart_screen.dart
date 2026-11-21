import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../data/history_point.dart';
import '../data/holding.dart';
import '../logic/history_cubit.dart';
import 'format.dart';

final _axisNumber = NumberFormat.compact(locale: 'en_US');
final _dayMonth = DateFormat('d/M', 'en_US');

/// 30-day price history for one asset: Egyptian market vs. world price.
class ChartScreen extends StatelessWidget {
  const ChartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('حركة السعر')),
      body: BlocBuilder<HistoryCubit, HistoryState>(
        builder: (context, state) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final asset in Asset.values)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 8),
                        child: ChoiceChip(
                          label: Text(asset.label),
                          selected: asset == state.asset,
                          onSelected: (_) =>
                              context.read<HistoryCubit>().load(asset),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              switch (state.status) {
                HistoryStatus.loading => const SizedBox(
                  height: 280,
                  child: Center(child: CircularProgressIndicator()),
                ),
                HistoryStatus.failed => _Message(
                  text: 'مش قادرين نجيب بيانات الرسم دلوقتي.',
                  onRetry: context.read<HistoryCubit>().load,
                ),
                HistoryStatus.ready when state.points.length < 2 =>
                  const _Message(text: 'مفيش بيانات كفاية للرسم.'),
                HistoryStatus.ready => _Chart(
                  points: state.points,
                  unit: state.asset.unit,
                ),
              },
            ],
          );
        },
      ),
    );
  }
}

class _Chart extends StatelessWidget {
  const _Chart({required this.points, required this.unit});

  final List<HistoryPoint> points;
  final String unit;

  List<FlSpot> _spots(double? Function(HistoryPoint) pick) => [
    for (var i = 0; i < points.length; i++)
      if (pick(points[i]) != null) FlSpot(i.toDouble(), pick(points[i])!),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final localColor = scheme.primary;
    final globalColor = scheme.tertiary;

    final local = _spots((p) => p.sell);
    final global = _spots((p) => p.global);
    final all = [...local, ...global];
    if (all.length < 2) return const _Message(text: 'مفيش بيانات كفاية للرسم.');

    final lo = all.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    final hi = all.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final pad = hi == lo ? (hi.abs() * 0.01 + 1) : (hi - lo) * 0.1;
    final labelEvery = (points.length / 4).ceilToDouble();

    LineChartBarData line(List<FlSpot> spots, Color color) => LineChartBarData(
      spots: spots,
      color: color,
      barWidth: 2.5,
      isCurved: false,
      dotData: const FlDotData(show: false),
    );

    // Change over the period, on whichever series has data.
    final series = local.length >= 2 ? local : global;
    final first = series.first.y;
    final last = series.last.y;
    final change = last - first;
    final changePercent = first == 0 ? 0.0 : change / first * 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 20, 20, 8),
            child: SizedBox(
              height: 260,
              // Time runs left to right, as on every price chart.
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: LineChart(
                  LineChartData(
                    minY: lo - pad,
                    maxY: hi + pad,
                    lineBarsData: [
                      if (global.length >= 2) line(global, globalColor),
                      if (local.length >= 2) line(local, localColor),
                    ],
                    borderData: FlBorderData(show: false),
                    gridData: FlGridData(
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (_) =>
                          FlLine(color: scheme.outlineVariant, strokeWidth: 1),
                    ),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(),
                      rightTitles: const AxisTitles(),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 48,
                          getTitlesWidget: (value, meta) {
                            if (value == meta.min || value == meta.max) {
                              return const SizedBox.shrink();
                            }
                            return Text(
                              _axisNumber.format(value),
                              style: text.labelSmall,
                            );
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: labelEvery,
                          reservedSize: 28,
                          getTitlesWidget: (value, meta) {
                            final i = value.round();
                            if (i != value || i < 0 || i >= points.length) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                _dayMonth.format(points[i].date),
                                style: text.labelSmall,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (_) => scheme.inverseSurface,
                        getTooltipItems: (spots) => [
                          for (final spot in spots)
                            LineTooltipItem(
                              '${_dayMonth.format(points[spot.x.round()].date)}  ${egp(spot.y)}',
                              TextStyle(
                                color: scheme.onInverseSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [
            if (local.length >= 2)
              _Legend(color: localColor, label: 'سوق مصر (سعر البيع)'),
            if (global.length >= 2)
              _Legend(color: globalColor, label: 'السعر العالمي'),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'التغير في آخر ${points.length} يوم',
                    style: text.bodyLarge,
                  ),
                ),
                Text(
                  '${signedEgp(change)} (${signedPercent(changePercent)})',
                  textDirection: TextDirection.ltr,
                  style: text.titleMedium?.copyWith(
                    color: profitColor(context, change),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'الأسعار بالجنيه لكل $unit.',
          style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 14, height: 3, color: color),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.onRetry});

  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 280,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              FilledButton(onPressed: onRetry, child: const Text('حاول تاني')),
            ],
          ],
        ),
      ),
    );
  }
}
