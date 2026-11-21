import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:hive/hive.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config.dart';
import 'price_snapshot.dart';

/// Keeps the last snapshot on the device so the app can open without internet.
abstract class SnapshotCache {
  String? read();
  Future<void> write(String json);
}

class HiveSnapshotCache implements SnapshotCache {
  HiveSnapshotCache(this._box);

  static const boxName = 'prices';
  static const _key = 'lastSnapshot';
  final Box<String> _box;

  @override
  String? read() => _box.get(_key);

  @override
  Future<void> write(String json) => _box.put(_key, json);
}

/// The app's only door to price data. It talks to the Dahaby backend and
/// nothing else.
class PriceRepository {
  PriceRepository({
    required SnapshotCache cache,
    Dio? dio,
    WebSocketChannel Function(Uri uri)? connect,
  }) : _cache = cache,
       _dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: backendUrl,
               connectTimeout: const Duration(seconds: 8),
               receiveTimeout: const Duration(seconds: 8),
             ),
           ),
       _connect = connect ?? WebSocketChannel.connect;

  final SnapshotCache _cache;
  final Dio _dio;
  final WebSocketChannel Function(Uri uri) _connect;

  /// The snapshot saved from the last session, if any.
  PriceSnapshot? cached() {
    final raw = _cache.read();
    if (raw == null) return null;
    try {
      return PriceSnapshot.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// One-off fetch, used when the socket is not available.
  Future<PriceSnapshot> fetch() async {
    final res = await _dio.get<Map<String, dynamic>>('/prices');
    return _accept(res.data!);
  }

  /// Live prices. The backend pushes a snapshot on connect and again every
  /// time a price moves. The stream ends or errors when the connection drops;
  /// the caller decides when to reconnect.
  Stream<PriceSnapshot> live() async* {
    final channel = _connect(pricesSocketUri);
    try {
      await channel.ready;
      await for (final message in channel.stream) {
        if (message is! String) continue;
        final PriceSnapshot snapshot;
        try {
          snapshot = _accept(jsonDecode(message) as Map<String, dynamic>);
        } catch (_) {
          continue; // skip a malformed message, keep the connection
        }
        yield snapshot;
      }
    } finally {
      await channel.sink.close();
    }
  }

  PriceSnapshot _accept(Map<String, dynamic> json) {
    final snapshot = PriceSnapshot.fromJson(json);
    _cache.write(jsonEncode(json));
    return snapshot;
  }
}
