import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/holding.dart';
import '../data/price_snapshot.dart';
import '../logic/prices_cubit.dart';
import '../logic/valuation.dart';
import 'format.dart';

/// What you pay a dealer for one unit of [asset] today, or null when unknown.
double? localBuyPrice(Asset asset, PriceSnapshot? snapshot) {
  final local = snapshot?.local;
  return switch (asset) {
    Asset.gold24 => local?.gold24?.buy,
    Asset.gold21 => local?.gold21?.buy,
    Asset.gold18 => local?.gold18?.buy,
    Asset.silver => local?.silver?.buy,
    Asset.goldPound => local?.goldPound?.buy,
    Asset.usd => snapshot?.usdEgp,
  };
}

/// Quick answer to "how much is X grams worth right now?".
class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  Asset _asset = Asset.gold21;
  final _quantity = TextEditingController(text: '1');
  final _fee = TextEditingController();

  @override
  void dispose() {
    _quantity.dispose();
    _fee.dispose();
    super.dispose();
  }

  bool get _hasFee => _asset != Asset.usd && _asset != Asset.goldPound;

  @override
  Widget build(BuildContext context) {
    final snapshot = context.select((PricesCubit c) => c.state.snapshot);
    final qty = parseNumber(_quantity.text);
    final fee = _hasFee ? (parseNumber(_fee.text) ?? 0) : 0.0;
    final valid = qty != null && qty > 0 && fee >= 0;

    double? times(double? price) => valid && price != null ? price * qty : null;

    final global = times(unitPrice(_asset, snapshot, PriceBasis.global));
    final sell = times(unitPrice(_asset, snapshot, PriceBasis.local));
    final buyUnit = localBuyPrice(_asset, snapshot);
    final buy = times(buyUnit == null ? null : buyUnit + fee);

    return Scaffold(
      appBar: AppBar(title: const Text('الحاسبة')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<Asset>(
            initialValue: _asset,
            decoration: const InputDecoration(
              labelText: 'النوع',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final asset in Asset.values)
                DropdownMenuItem(value: asset, child: Text(asset.label)),
            ],
            onChanged: (asset) => setState(() => _asset = asset ?? _asset),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('calc-quantity'),
            controller: _quantity,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(
              labelText: 'الكمية',
              suffix: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(_asset.unit),
              ),
              border: const OutlineInputBorder(),
              errorText: _quantity.text.trim().isEmpty || valid
                  ? null
                  : 'اكتب رقم أكبر من صفر',
            ),
            onChanged: (_) => setState(() {}),
          ),
          if (_hasFee) ...[
            const SizedBox(height: 16),
            TextField(
              key: const Key('calc-fee'),
              controller: _fee,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(
                labelText: 'المصنعية لكل جرام (اختياري)',
                suffix: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('جنيه'),
                ),
                helperText: 'بتتضاف على سعر الشراء بس',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Column(
                children: [
                  _Result(label: 'بالسعر العالمي', value: global),
                  const Divider(height: 1),
                  _Result(
                    label: fee > 0
                        ? 'تشتري من الصاغة بـ (بالمصنعية)'
                        : 'تشتري من الصاغة بـ',
                    value: buy,
                  ),
                  const Divider(height: 1),
                  _Result(label: 'تبيع للصاغة بـ', value: sell),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'الأرقام استرشادية، والسعر الفعلي عند التاجر ممكن يختلف.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({required this.label, required this.value});

  final String label;
  final double? value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Expanded(child: Text(label, style: text.bodyLarge)),
          Text(
            egp(value),
            textDirection: TextDirection.ltr,
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 6),
          Text('جنيه', style: text.bodySmall),
        ],
      ),
    );
  }
}
