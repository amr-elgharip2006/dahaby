import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'pricing.dart';

/// Pulls prices from the upstream sources, keeps the latest snapshot in
/// memory and emits a new snapshot on [changes] whenever a number moves.
///
/// Sources:
///  * gold-api.com  - world gold/silver price in USD, updates every few seconds.
///  * Daleelak      - Egyptian market prices in EGP plus 30 days of history,
///                    changes about once an hour.
///  * open.er-api   - official USD/EGP rate, used only when Daleelak is down.
class PriceService {
  PriceService({
    http.Client? client,
    this.globalInterval = const Duration(seconds: 15),
    this.localInterval = const Duration(minutes: 5),
    void Function(String message)? log,
  })  : _client = client ?? http.Client(),
        _log = log ?? ((_) {});

  /// The default Dart user agent is throttled by gold-api.com, so requests
  /// identify this project instead.
  static const _headers = {'user-agent': 'dahaby-backend/0.1'};

  static final _goldUrl = Uri.parse('https://api.gold-api.com/price/XAU');
  static final _silverUrl = Uri.parse('https://api.gold-api.com/price/XAG');
  static final _daleelakUrl = Uri.parse(
    'https://getdaleelak.com/api/v1/feed.json?category=currencies,metals',
  );
  static final _fxFallbackUrl =
      Uri.parse('https://open.er-api.com/v6/latest/USD');

  /// Maps our short asset names to Daleelak ids.
  static const assetIds = {
    'gold24': 'GOLD24K-EGP',
    'gold21': 'GOLD21K-EGP',
    'gold18': 'GOLD18K-EGP',
    'goldPound': 'GOLDPOUND-EGP',
    'silver': 'SILVER999-EGP',
    'usd': 'USD-EGP',
  };

  final http.Client _client;
  final Duration globalInterval;
  final Duration localInterval;
  final void Function(String) _log;

  final _changes = StreamController<Map<String, dynamic>>.broadcast();
  Timer? _globalTimer;
  Timer? _localTimer;

  double? _goldOunceUsd;
  double? _silverOunceUsd;
  DateTime? _globalAsOf;
  double? _usdEgp;
  Map<String, dynamic>? _local;
  String? _daleelakEtag;
  Map<String, List<Map<String, dynamic>>> _history = {};
  String? _lastFingerprint;
  Map<String, dynamic>? _snapshot;

  /// Emits a snapshot every time a price changes.
  Stream<Map<String, dynamic>> get changes => _changes.stream;

  /// The latest snapshot, or null until the first successful fetch.
  Map<String, dynamic>? get snapshot => _snapshot;

  /// Daily history for [asset] (one of [assetIds] keys). Empty if unknown.
  List<Map<String, dynamic>> history(String asset) =>
      _history[asset] ?? const [];

  Future<void> start() async {
    await Future.wait([refreshLocal(), refreshGlobal()]);
    _globalTimer = Timer.periodic(globalInterval, (_) => refreshGlobal());
    _localTimer = Timer.periodic(localInterval, (_) => refreshLocal());
  }

  Future<void> stop() async {
    _globalTimer?.cancel();
    _localTimer?.cancel();
    await _changes.close();
    _client.close();
  }

  Future<void> refreshGlobal() async {
    try {
      final results = await Future.wait([
        _getJson(_goldUrl),
        _getJson(_silverUrl),
      ]);
      _goldOunceUsd = (results[0]['price'] as num).toDouble();
      _silverOunceUsd = (results[1]['price'] as num).toDouble();
      _globalAsOf = DateTime.tryParse('${results[0]['updatedAt']}') ??
          DateTime.now().toUtc();
      _publish();
    } catch (e) {
      _log('global refresh failed: $e');
    }
  }

  Future<void> refreshLocal() async {
    try {
      final res = await _client.get(_daleelakUrl, headers: {
        ..._headers,
        if (_daleelakEtag != null) 'If-None-Match': _daleelakEtag!,
      }).timeout(const Duration(seconds: 20));
      if (res.statusCode == 304) return;
      if (res.statusCode != 200) {
        throw http.ClientException('Daleelak HTTP ${res.statusCode}');
      }
      _daleelakEtag = res.headers['etag'];
      _applyDaleelak(
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
      _publish();
    } catch (e) {
      _log('local refresh failed: $e');
      if (_usdEgp == null) await _refreshFxFallback();
    }
  }

  Future<void> _refreshFxFallback() async {
    try {
      final body = await _getJson(_fxFallbackUrl);
      _usdEgp = ((body['rates'] as Map)['EGP'] as num).toDouble();
      _publish();
    } catch (e) {
      _log('fx fallback failed: $e');
    }
  }

  void _applyDaleelak(Map<String, dynamic> feed) {
    final byId = <String, Map<String, dynamic>>{
      for (final a in (feed['assets'] as List).cast<Map<String, dynamic>>())
        a['id'] as String: a,
    };

    num? best(Map<String, dynamic>? asset, String side) =>
        ((asset?['directions'] as Map?)?[side] as Map?)?['best']?['value']
            as num?;

    // In the feed, "buy"/"sell" are from the customer's side:
    // buy = what you pay a dealer, sell = what a dealer pays you.
    Map<String, dynamic>? quote(String key) {
      final asset = byId[assetIds[key]];
      final buy = best(asset, 'buy');
      final sell = best(asset, 'sell');
      if (buy == null && sell == null) return null;
      return {'buy': buy, 'sell': sell};
    }

    final usd = byId[assetIds['usd']];
    final usdGlobal = (usd?['global'] as Map?)?['value'] as num?;
    final usdRate = usdGlobal ?? best(usd, 'sell');
    if (usdRate != null) _usdEgp = usdRate.toDouble();

    final local = <String, dynamic>{
      for (final key in ['gold24', 'gold21', 'gold18', 'goldPound', 'silver'])
        if (quote(key) != null) key: quote(key),
    };
    if (local.isNotEmpty) {
      local['asOf'] =
          byId[assetIds['gold21']]?['observedAt'] ?? feed['generatedAt'];
      _local = local;
    }

    final history = <String, List<Map<String, dynamic>>>{};
    for (final entry in assetIds.entries) {
      final series =
          (byId[entry.value]?['series'] as List?)?.cast<Map<String, dynamic>>();
      if (series == null) continue;
      history[entry.key] = [
        for (final p in series)
          {
            'date': p['date'],
            // Dealers' lowest asking price is the best price to buy at,
            // their highest bid is the best price to sell at.
            'buy': p['sellLo'],
            'sell': p['buyHi'],
            'global': p['global'],
          },
      ];
    }
    if (history.isNotEmpty) _history = history;
  }

  void _publish() {
    final gold = _goldOunceUsd;
    final silver = _silverOunceUsd;
    final fx = _usdEgp;

    Map<String, dynamic>? global;
    if (gold != null && silver != null && fx != null) {
      double g(int karat) =>
          round2(goldGramEgp(ounceUsd: gold, usdEgp: fx, karat: karat));
      global = {
        'goldOunceUsd': gold,
        'silverOunceUsd': silver,
        'gold24': g(24),
        'gold21': g(21),
        'gold18': g(18),
        'silver': round2(gramPriceEgp(ounceUsd: silver, usdEgp: fx)),
        'asOf': _globalAsOf?.toIso8601String(),
      };
    }
    if (global == null && _local == null) return;

    final body = <String, dynamic>{
      'usdEgp': fx,
      'global': global,
      'local': _local,
    };
    // Timestamps are left out of the fingerprint: only a moved number counts.
    final fingerprint = jsonEncode({
      'usdEgp': fx,
      'global': global == null ? null : (Map.of(global)..remove('asOf')),
      'local': _local == null ? null : (Map.of(_local!)..remove('asOf')),
    });
    if (fingerprint == _lastFingerprint) return;
    _lastFingerprint = fingerprint;

    _snapshot = {
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
      ...body
    };
    if (!_changes.isClosed) _changes.add(_snapshot!);
  }

  Future<Map<String, dynamic>> _getJson(Uri url) async {
    final res = await _client
        .get(url, headers: _headers)
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw http.ClientException('HTTP ${res.statusCode}', url);
    }
    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }
}
