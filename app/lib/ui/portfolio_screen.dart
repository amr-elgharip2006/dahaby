import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/holding.dart';
import '../logic/portfolio_cubit.dart';
import '../logic/prices_cubit.dart';
import '../logic/valuation.dart';
import 'format.dart';
import 'holding_form.dart';
import 'theme.dart';

class PortfolioScreen extends StatelessWidget {
  const PortfolioScreen({super.key});

  void _openForm(BuildContext context, [Holding? existing]) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => HoldingForm(existing: existing)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final portfolio = context.watch<PortfolioCubit>().state;
    final snapshot = context.select((PricesCubit c) => c.state.snapshot);
    final summary = PortfolioSummary.compute(
      portfolio.holdings,
      snapshot,
      portfolio.basis,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('محفظتي')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context),
        icon: const Icon(Icons.add),
        label: const Text('إضافة'),
      ),
      body: summary.items.isEmpty
          ? const _Empty()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                _SummaryCard(summary: summary),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'التقييم بسعر',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    SegmentedButton<PriceBasis>(
                      showSelectedIcon: false,
                      segments: [
                        for (final basis in PriceBasis.values)
                          ButtonSegment(value: basis, label: Text(basis.label)),
                      ],
                      selected: {portfolio.basis},
                      onSelectionChanged: (s) =>
                          context.read<PortfolioCubit>().setBasis(s.first),
                    ),
                  ],
                ),
                if (summary.unpriced > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${summary.unpriced} عملية مش داخلة في الإجمالي لأن سعرها مش متاح دلوقتي.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                for (final item in summary.items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _HoldingTile(
                      item: item,
                      onTap: () => _openForm(context, item.holding),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});

  final PortfolioSummary summary;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final soft = Brand.ink.withValues(alpha: 0.72);
    final percent = summary.profitPercent;
    return GoldCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'قيمة المحفظة الآن',
            style: text.titleMedium?.copyWith(
              color: Brand.ink,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                egp(summary.value),
                textDirection: TextDirection.ltr,
                style: text.headlineLarge?.copyWith(
                  color: Brand.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Text('جنيه', style: text.titleMedium?.copyWith(color: soft)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Stat(
                  label: 'دفعت',
                  value: egp(summary.cost),
                  color: Brand.ink,
                ),
              ),
              Expanded(
                child: _Stat(
                  label: summary.profit < 0 ? 'الخسارة' : 'المكسب',
                  value: percent == null
                      ? signedEgp(summary.profit)
                      : '${signedEgp(summary.profit)}  (${signedPercent(percent)})',
                  // The light-mode colours stay readable on gold.
                  color: summary.profit == 0
                      ? Brand.ink
                      : summary.profit > 0
                      ? DahabyColors.light.gain
                      : DahabyColors.light.loss,
                  pill: summary.profit != 0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.color,
    this.pill = false,
  });

  final String label;
  final String value;
  final Color color;

  /// Puts the value on a white pill so a green or red number reads on gold.
  final bool pill;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final number = Text(
      value,
      textDirection: TextDirection.ltr,
      style: text.titleSmall?.copyWith(
        color: color,
        fontWeight: FontWeight.w700,
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: text.bodySmall?.copyWith(
            color: Brand.ink.withValues(alpha: 0.72),
          ),
        ),
        const SizedBox(height: 4),
        if (pill)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(999),
            ),
            child: number,
          )
        else
          number,
      ],
    );
  }
}

class _HoldingTile extends StatelessWidget {
  const _HoldingTile({required this.item, required this.onTap});

  final ValuedHolding item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final holding = item.holding;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final profit = item.profit;
    final percent = item.profitPercent;

    return Dismissible(
      key: ValueKey(holding.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Icon(Icons.delete_outline, color: scheme.onErrorContainer),
      ),
      onDismissed: (_) {
        final cubit = context.read<PortfolioCubit>()..remove(holding.id);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: const Text('اتمسحت العملية'),
              action: SnackBarAction(
                label: 'تراجع',
                onPressed: () => cubit.save(holding),
              ),
            ),
          );
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        holding.asset.label,
                        style: text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${quantity(holding.quantity)} ${holding.asset.unit} · اشتريت بـ ${egp(holding.buyPrice)}',
                        style: text.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        shortDate(holding.boughtOn),
                        style: text.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      egp(item.value),
                      textDirection: TextDirection.ltr,
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (profit != null)
                      Text(
                        percent == null
                            ? signedEgp(profit)
                            : '${signedEgp(profit)} (${signedPercent(percent)})',
                        textDirection: TextDirection.ltr,
                        style: text.bodySmall?.copyWith(
                          color: profitColor(context, profit),
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    else
                      Text('السعر مش متاح', style: text.bodySmall),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 56,
              color: scheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'محفظتك فاضية',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'سجّل اللي عندك من دهب أو فضة أو دولار، وهنحسب لك قيمته ومكسبك لحظة بلحظة.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
