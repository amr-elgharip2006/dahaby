import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import 'theme.dart';

final _money = NumberFormat('#,##0.00', 'en_US');
final _quantity = NumberFormat('#,##0.###', 'en_US');

/// "5,357.26", or a dash when the value is unknown.
String egp(double? v) => v == null ? '—' : _money.format(v);

/// "+1,200.00" / "-350.00".
String signedEgp(double v) => '${v > 0 ? '+' : ''}${_money.format(v)}';

/// "+4.2%" / "-1.0%".
String signedPercent(double v) => '${v > 0 ? '+' : ''}${v.toStringAsFixed(1)}%';

/// "10", "2.5" - no trailing zeros.
String quantity(double v) => _quantity.format(v);

String shortDate(DateTime d) => DateFormat('d/M/y', 'en_US').format(d);

/// Green for a gain, red for a loss, neutral for zero.
Color profitColor(BuildContext context, double v) {
  if (v > 0) return DahabyColors.of(context).gain;
  if (v < 0) return DahabyColors.of(context).loss;
  return Theme.of(context).colorScheme.onSurfaceVariant;
}
