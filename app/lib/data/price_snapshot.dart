import 'package:equatable/equatable.dart';

double? _d(Object? v) => v is num ? v.toDouble() : null;

/// What you pay to buy and what you get when you sell, in EGP.
class Quote extends Equatable {
  const Quote({this.buy, this.sell});

  final double? buy;
  final double? sell;

  static Quote? fromJson(Object? json) {
    if (json is! Map) return null;
    return Quote(buy: _d(json['buy']), sell: _d(json['sell']));
  }

  @override
  List<Object?> get props => [buy, sell];
}

/// World prices converted to EGP per gram. Updates every few seconds.
class GlobalPrices extends Equatable {
  const GlobalPrices({
    required this.goldOunceUsd,
    required this.silverOunceUsd,
    required this.gold24,
    required this.gold21,
    required this.gold18,
    required this.silver,
    this.asOf,
  });

  final double goldOunceUsd;
  final double silverOunceUsd;
  final double gold24;
  final double gold21;
  final double gold18;
  final double silver;
  final DateTime? asOf;

  static GlobalPrices? fromJson(Object? json) {
    if (json is! Map) return null;
    final values = [
      for (final k in const [
        'goldOunceUsd',
        'silverOunceUsd',
        'gold24',
        'gold21',
        'gold18',
        'silver',
      ])
        _d(json[k]),
    ];
    if (values.contains(null)) return null;
    return GlobalPrices(
      goldOunceUsd: values[0]!,
      silverOunceUsd: values[1]!,
      gold24: values[2]!,
      gold21: values[3]!,
      gold18: values[4]!,
      silver: values[5]!,
      asOf: DateTime.tryParse('${json['asOf']}'),
    );
  }

  @override
  List<Object?> get props => [
    goldOunceUsd,
    silverOunceUsd,
    gold24,
    gold21,
    gold18,
    silver,
    asOf,
  ];
}

/// Egyptian market prices in EGP. Changes about once an hour.
class LocalPrices extends Equatable {
  const LocalPrices({
    this.gold24,
    this.gold21,
    this.gold18,
    this.goldPound,
    this.silver,
    this.asOf,
  });

  final Quote? gold24;
  final Quote? gold21;
  final Quote? gold18;
  final Quote? goldPound;
  final Quote? silver;
  final DateTime? asOf;

  static LocalPrices? fromJson(Object? json) {
    if (json is! Map) return null;
    return LocalPrices(
      gold24: Quote.fromJson(json['gold24']),
      gold21: Quote.fromJson(json['gold21']),
      gold18: Quote.fromJson(json['gold18']),
      goldPound: Quote.fromJson(json['goldPound']),
      silver: Quote.fromJson(json['silver']),
      asOf: DateTime.tryParse('${json['asOf']}'),
    );
  }

  @override
  List<Object?> get props => [gold24, gold21, gold18, goldPound, silver, asOf];
}

/// One message from the backend: everything the prices screen shows.
class PriceSnapshot extends Equatable {
  const PriceSnapshot({
    required this.updatedAt,
    this.usdEgp,
    this.global,
    this.local,
  });

  final DateTime updatedAt;
  final double? usdEgp;
  final GlobalPrices? global;
  final LocalPrices? local;

  factory PriceSnapshot.fromJson(Map<String, dynamic> json) {
    final updatedAt = DateTime.tryParse('${json['updatedAt']}');
    if (updatedAt == null) {
      throw const FormatException('snapshot has no updatedAt');
    }
    return PriceSnapshot(
      updatedAt: updatedAt,
      usdEgp: _d(json['usdEgp']),
      global: GlobalPrices.fromJson(json['global']),
      local: LocalPrices.fromJson(json['local']),
    );
  }

  @override
  List<Object?> get props => [updatedAt, usdEgp, global, local];
}
