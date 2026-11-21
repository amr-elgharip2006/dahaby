import 'dart:convert';

import 'package:hive/hive.dart';

import 'holding.dart';

/// Where the user's purchases are kept. They stay on the device.
abstract class PortfolioStore {
  List<Holding> readAll();
  Future<void> put(Holding holding);
  Future<void> delete(String id);
}

class HivePortfolioStore implements PortfolioStore {
  HivePortfolioStore(this._box);

  static const boxName = 'portfolio';
  final Box<String> _box;

  @override
  List<Holding> readAll() {
    final holdings = <Holding>[];
    for (final raw in _box.values) {
      try {
        final holding = Holding.fromJson(jsonDecode(raw));
        if (holding != null) holdings.add(holding);
      } catch (_) {
        // Skip a record that cannot be read rather than lose the rest.
      }
    }
    return holdings;
  }

  @override
  Future<void> put(Holding holding) =>
      _box.put(holding.id, jsonEncode(holding.toJson()));

  @override
  Future<void> delete(String id) => _box.delete(id);
}
