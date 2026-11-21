import 'package:equatable/equatable.dart';

/// What the user can own. [unit] is how the quantity is counted.
enum Asset {
  gold24('ذهب عيار 24', 'جرام'),
  gold21('ذهب عيار 21', 'جرام'),
  gold18('ذهب عيار 18', 'جرام'),
  goldPound('جنيه ذهب', 'جنيه'),
  silver('فضة', 'جرام'),
  usd('دولار', 'دولار');

  const Asset(this.label, this.unit);

  final String label;
  final String unit;
}

/// One purchase the user recorded.
class Holding extends Equatable {
  const Holding({
    required this.id,
    required this.asset,
    required this.quantity,
    required this.buyPrice,
    required this.boughtOn,
  });

  final String id;
  final Asset asset;

  /// Grams, coins or dollars, depending on [asset].
  final double quantity;

  /// What was paid per unit, in EGP.
  final double buyPrice;
  final DateTime boughtOn;

  double get cost => quantity * buyPrice;

  Map<String, dynamic> toJson() => {
    'id': id,
    'asset': asset.name,
    'quantity': quantity,
    'buyPrice': buyPrice,
    'boughtOn': boughtOn.toIso8601String(),
  };

  /// Returns null for a record this version of the app cannot read.
  static Holding? fromJson(Object? json) {
    if (json is! Map) return null;
    final asset = Asset.values
        .where((a) => a.name == json['asset'])
        .firstOrNull;
    final quantity = json['quantity'];
    final buyPrice = json['buyPrice'];
    final boughtOn = DateTime.tryParse('${json['boughtOn']}');
    if (asset == null ||
        json['id'] is! String ||
        quantity is! num ||
        buyPrice is! num ||
        boughtOn == null) {
      return null;
    }
    return Holding(
      id: json['id'] as String,
      asset: asset,
      quantity: quantity.toDouble(),
      buyPrice: buyPrice.toDouble(),
      boughtOn: boughtOn,
    );
  }

  @override
  List<Object?> get props => [id, asset, quantity, buyPrice, boughtOn];
}
