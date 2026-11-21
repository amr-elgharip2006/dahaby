import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'ai_service.dart';
import 'price_service.dart';
import 'rate_limiter.dart';

const _json = {'content-type': 'application/json; charset=utf-8'};
const _maxBodyBytes = 64 * 1024;

Response _ok(Object body) => Response.ok(jsonEncode(body), headers: _json);

Response _error(int status, String message) =>
    Response(status, body: jsonEncode({'error': message}), headers: _json);

/// Builds the HTTP + WebSocket handler.
///
/// [ai] is null when no API key is configured; the AI routes then answer 503.
Handler buildHandler({
  required PriceService prices,
  AiService? ai,
  RateLimiter? aiLimiter,
}) {
  final limiter =
      aiLimiter ?? RateLimiter(limit: 20, window: const Duration(hours: 1));
  final router = Router();

  router.get('/health', (Request _) {
    return _ok(
        {'ok': true, 'hasPrices': prices.snapshot != null, 'ai': ai != null});
  });

  router.get('/prices', (Request _) {
    final snap = prices.snapshot;
    if (snap == null) return _error(503, 'prices are not ready yet');
    return _ok(snap);
  });

  router.get('/history', (Request req) {
    final asset = req.url.queryParameters['asset'] ?? 'gold21';
    if (!PriceService.assetIds.containsKey(asset)) {
      return _error(
        400,
        'unknown asset, use one of: ${PriceService.assetIds.keys.join(', ')}',
      );
    }
    return _ok({'asset': asset, 'points': prices.history(asset)});
  });

  // Pushes a snapshot on connect and again every time a price moves.
  router.get(
      '/ws',
      webSocketHandler((WebSocketChannel socket, String? _) {
        final snap = prices.snapshot;
        if (snap != null) socket.sink.add(jsonEncode(snap));
        final sub =
            prices.changes.listen((s) => socket.sink.add(jsonEncode(s)));
        socket.stream
            .listen((_) {}, onDone: sub.cancel, onError: (_) => sub.cancel());
      }, pingInterval: const Duration(seconds: 25)));

  Future<Response> aiRoute(
    Request req,
    Future<String> Function(
            Map<String, dynamic> body, Map<String, dynamic> market)
        run,
  ) async {
    if (ai == null) return _error(503, 'the assistant is not configured');
    if (!limiter.allow(_clientKey(req))) {
      return _error(429, 'too many assistant requests, try again later');
    }
    final Map<String, dynamic> body;
    try {
      body = await _readJson(req);
    } on FormatException catch (e) {
      return _error(400, e.message);
    }
    final market = {
      'now': prices.snapshot,
      'gold21History': prices.history('gold21'),
      'usdHistory': prices.history('usd'),
    };
    try {
      return _ok({'text': await run(body, market)});
    } on AiException catch (e) {
      return _error(e.status, e.message);
    }
  }

  router.post('/ai/summary', (Request req) {
    return aiRoute(req, (body, market) {
      return ai!.summary(marketContext: market, portfolio: body['portfolio']);
    });
  });

  router.post('/ai/chat', (Request req) {
    return aiRoute(req, (body, market) {
      final raw = body['messages'];
      if (raw is! List) throw AiException(400, 'messages must be a list');
      final messages = <Map<String, String>>[
        for (final m in raw)
          if (m is Map)
            {'role': '${m['role']}', 'content': '${m['content']}'}
          else
            throw AiException(400, 'each message must be an object'),
      ];
      return ai!.chat(
        messages: messages,
        marketContext: market,
        portfolio: body['portfolio'],
      );
    });
  });

  return const Pipeline().addMiddleware(_cors()).addHandler(router.call);
}

String _clientKey(Request req) {
  final info = req.context['shelf.io.connection_info'];
  return info is HttpConnectionInfo ? info.remoteAddress.address : 'unknown';
}

Future<Map<String, dynamic>> _readJson(Request req) async {
  final bytes = <int>[];
  await for (final chunk in req.read()) {
    bytes.addAll(chunk);
    if (bytes.length > _maxBodyBytes) {
      throw const FormatException('request body is too large');
    }
  }
  try {
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is Map<String, dynamic>) return decoded;
  } catch (_) {
    // fall through to the error below
  }
  throw const FormatException('request body must be a JSON object');
}

Middleware _cors() {
  const headers = {
    'access-control-allow-origin': '*',
    'access-control-allow-methods': 'GET, POST, OPTIONS',
    'access-control-allow-headers': 'content-type',
  };
  return (inner) => (req) async {
        if (req.method == 'OPTIONS') return Response.ok('', headers: headers);
        final res = await inner(req);
        return res.change(headers: headers);
      };
}
