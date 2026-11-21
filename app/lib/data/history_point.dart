import 'package:equatable/equatable.dart';

double? _d(Object? v) => v is num ? v.toDouble() : null;

/// One day of prices for one asset, in EGP.
class HistoryPoint extends Equatable {
  const HistoryPoint({required this.date, this.buy, this.sell, this.global});

  final DateTime date;

  /// Egyptian market: what you paid to buy / got when selling that day.
  final double? buy;
  final double? sell;

  /// World price converted to EGP.
  final double? global;

  static HistoryPoint? fromJson(Object? json) {
    if (json is! Map) return null;
    final date = DateTime.tryParse('${json['date']}');
    if (date == null) return null;
    return HistoryPoint(
      date: date,
      buy: _d(json['buy']),
      sell: _d(json['sell']),
      global: _d(json['global']),
    );
  }

  @override
  List<Object?> get props => [date, buy, sell, global];
}
