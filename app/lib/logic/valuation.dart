import 'package:equatable/equatable.dart';

import '../data/holding.dart';
import '../data/price_snapshot.dart';

/// Which price the portfolio is valued at.
enum PriceBasis {
  /// World price converted to EGP. Moves every few seconds.
  global('عالمي'),

  /// What an Egyptian dealer pays you today.
  local('سوق مصر');

  const PriceBasis(this.label);
  final String label;
}

/// A gold pound is 8 grams of 21 karat gold.
const double goldPoundGrams = 8;

/// Current price of one unit of [asset] in EGP, or null when unknown.
///
/// If the chosen [basis] has no price for the asset, the other one is used.
double? unitPrice(Asset asset, PriceSnapshot? snapshot, PriceBasis basis) {
  if (snapshot == null) return null;
  if (asset == Asset.usd) return snapshot.usdEgp;

  final g = snapshot.global;
  final l = snapshot.local;
  final global = switch (asset) {
    Asset.gold24 => g?.gold24,
    Asset.gold21 => g?.gold21,
    Asset.gold18 => g?.gold18,
    Asset.silver => g?.silver,
    Asset.goldPound => g == null ? null : g.gold21 * goldPoundGrams,
    Asset.usd => null,
  };
  final local = switch (asset) {
    Asset.gold24 => l?.gold24?.sell,
    Asset.gold21 => l?.gold21?.sell,
    Asset.gold18 => l?.gold18?.sell,
    Asset.silver => l?.silver?.sell,
    Asset.goldPound => l?.goldPound?.sell,
    Asset.usd => null,
  };
  return basis == PriceBasis.global ? (global ?? local) : (local ?? global);
}

/// A holding with its value at today's price.
class ValuedHolding extends Equatable {
  const ValuedHolding({required this.holding, this.price});

  final Holding holding;

  /// Today's price per unit. Null when the price is not available.
  final double? price;

  double? get value => price == null ? null : holding.quantity * price!;
  double? get profit => value == null ? null : value! - holding.cost;
  double? get profitPercent =>
      profit == null || holding.cost == 0 ? null : profit! / holding.cost * 100;

  @override
  List<Object?> get props => [holding, price];
}

/// Totals for the whole portfolio.
class PortfolioSummary extends Equatable {
  const PortfolioSummary({
    required this.items,
    required this.cost,
    required this.value,
    required this.unpriced,
  });

  /// Newest purchase first.
  final List<ValuedHolding> items;

  /// What was paid for the holdings that have a price today.
  final double cost;

  /// What those holdings are worth today.
  final double value;

  /// Holdings left out of the totals because their price is unknown.
  final int unpriced;

  double get profit => value - cost;
  double? get profitPercent => cost == 0 ? null : profit / cost * 100;

  factory PortfolioSummary.compute(
    List<Holding> holdings,
    PriceSnapshot? snapshot,
    PriceBasis basis,
  ) {
    final items = [
      for (final h in holdings)
        ValuedHolding(holding: h, price: unitPrice(h.asset, snapshot, basis)),
    ]..sort((a, b) => b.holding.boughtOn.compareTo(a.holding.boughtOn));

    var cost = 0.0;
    var value = 0.0;
    var unpriced = 0;
    for (final item in items) {
      final v = item.value;
      if (v == null) {
        unpriced++;
      } else {
        value += v;
        cost += item.holding.cost;
      }
    }
    return PortfolioSummary(
      items: items,
      cost: cost,
      value: value,
      unpriced: unpriced,
    );
  }

  @override
  List<Object?> get props => [items, cost, value, unpriced];
}

/// Reads a number typed with Western or Arabic digits, e.g. "١٢٫٥" or "1,250.5".
/// Returns null when the text is not a number.
double? parseNumber(String input) {
  const arabic = '٠١٢٣٤٥٦٧٨٩';
  final buffer = StringBuffer();
  for (final char in input.trim().split('')) {
    final digit = arabic.indexOf(char);
    if (digit >= 0) {
      buffer.write(digit);
    } else if (char == '٫') {
      buffer.write('.');
    } else if (char == ',' || char == '٬' || char == ' ') {
      continue; // thousands separators
    } else {
      buffer.write(char);
    }
  }
  final value = double.tryParse(buffer.toString());
  return value == null || !value.isFinite ? null : value;
}
