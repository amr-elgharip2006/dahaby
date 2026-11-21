import 'dart:convert';

import 'package:dahaby_backend/ai_service.dart';
import 'package:dahaby_backend/price_service.dart';
import 'package:dahaby_backend/pricing.dart';
import 'package:dahaby_backend/rate_limiter.dart';
import 'package:dahaby_backend/server.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

const _feed = {
  'generatedAt': '2026-11-21T10:01:19Z',
  'assets': [
    {
      'id': 'USD-EGP',
      'directions': {
        'sell': {
          'best': {'value': 53.85}
        },
        'buy': {
          'best': {'value': 53.81}
        },
      },
      'global': {'value': 50.0},
      'series': [
        {'date': '2026-11-20', 'buyHi': 53.7, 'sellLo': 53.9, 'global': 53.8},
      ],
    },
    {
      'id': 'GOLD21K-EGP',
      'observedAt': '2026-11-21T10:00:00.000Z',
      'directions': {
        'sell': {
          'best': {'value': 5442.17}
        },
        'buy': {
          'best': {'value': 5450}
        },
      },
      'series': [
        {'date': '2026-11-20', 'buyHi': 5440, 'sellLo': 5455, 'global': 5350},
        {
          'date': '2026-11-21',
          'buyHi': 5442.17,
          'sellLo': 5450,
          'global': 5357.72
        },
      ],
    },
  ],
};

/// Fake upstreams: gold at [goldUsd] per ounce, silver at 31.1035 (1 USD/gram).
http.Client _upstream({double Function()? goldUsd, bool daleelakDown = false}) {
  return MockClient((req) async {
    final url = req.url.toString();
    if (url.contains('XAU')) {
      return http.Response(
        jsonEncode({
          'price': goldUsd?.call() ?? 3110.35,
          'updatedAt': '2026-11-21T10:10:37Z'
        }),
        200,
      );
    }
    if (url.contains('XAG')) {
      return http.Response(jsonEncode({'price': 31.1035}), 200);
    }
    if (url.contains('daleelak')) {
      if (daleelakDown) return http.Response('down', 500);
      return http.Response(jsonEncode(_feed), 200, headers: {'etag': '"v1"'});
    }
    if (url.contains('er-api')) {
      return http.Response(
          jsonEncode({
            'rates': {'EGP': 40.0}
          }),
          200);
    }
    return http.Response('not found', 404);
  });
}

void main() {
  group('pricing', () {
    test('converts an ounce in USD to a gram in EGP', () {
      expect(gramPriceEgp(ounceUsd: 3110.35, usdEgp: 50), closeTo(5000, 1e-9));
    });

    test('scales by karat purity', () {
      double g(int k) => goldGramEgp(ounceUsd: 3110.35, usdEgp: 50, karat: k);
      expect(g(24), closeTo(5000, 1e-9));
      expect(g(21), closeTo(4375, 1e-9));
      expect(g(18), closeTo(3750, 1e-9));
    });

    test('rejects an unsupported karat', () {
      expect(() => goldGramEgp(ounceUsd: 1, usdEgp: 1, karat: 22),
          throwsArgumentError);
    });
  });

  group('PriceService', () {
    test('builds a snapshot from both sources', () async {
      final service = PriceService(client: _upstream());
      await service.refreshLocal();
      await service.refreshGlobal();

      final snap = service.snapshot!;
      expect(snap['usdEgp'], 50.0);
      expect(snap['global']['gold24'], 5000.0);
      expect(snap['global']['gold21'], 4375.0);
      expect(snap['global']['silver'], 50.0);
      expect(snap['local']['gold21'], {'buy': 5450, 'sell': 5442.17});
      expect(snap['local']['asOf'], '2026-11-21T10:00:00.000Z');
    });

    test('maps history to customer buy and sell prices', () async {
      final service = PriceService(client: _upstream());
      await service.refreshLocal();

      final points = service.history('gold21');
      expect(points, hasLength(2));
      expect(points.last, {
        'date': '2026-11-21',
        'buy': 5450,
        'sell': 5442.17,
        'global': 5357.72,
      });
      expect(service.history('nope'), isEmpty);
    });

    test('emits only when a price actually moves', () async {
      var gold = 3110.35;
      final service = PriceService(client: _upstream(goldUsd: () => gold));
      final emitted = <Map<String, dynamic>>[];
      final sub = service.changes.listen(emitted.add);

      await service.refreshLocal();
      await service.refreshGlobal();
      await service.refreshGlobal(); // same price, no new event
      await Future<void>.delayed(Duration.zero);
      final before = emitted.length;

      gold = 3200;
      await service.refreshGlobal();
      await Future<void>.delayed(Duration.zero);

      expect(emitted.length, before + 1);
      expect(emitted.last['global']['goldOunceUsd'], 3200);
      await sub.cancel();
    });

    test('falls back to the official rate when Daleelak is down', () async {
      final service = PriceService(client: _upstream(daleelakDown: true));
      await service.refreshLocal();
      await service.refreshGlobal();

      final snap = service.snapshot!;
      expect(snap['usdEgp'], 40.0);
      expect(snap['local'], isNull);
      expect(snap['global']['gold24'], 4000.0);
    });
  });

  group('RateLimiter', () {
    test('blocks over the limit and recovers after the window', () {
      var now = DateTime(2026, 1, 1);
      final limiter = RateLimiter(
          limit: 2, window: const Duration(hours: 1), now: () => now);
      expect(limiter.allow('a'), isTrue);
      expect(limiter.allow('a'), isTrue);
      expect(limiter.allow('a'), isFalse);
      expect(limiter.allow('b'), isTrue);
      now = now.add(const Duration(hours: 1, seconds: 1));
      expect(limiter.allow('a'), isTrue);
    });
  });

  group('AiService', () {
    test('rejects bad conversations', () {
      void bad(List<Map<String, String>> m) => expect(
            () => AiService.validateMessages(m),
            throwsA(isA<AiException>().having((e) => e.status, 'status', 400)),
          );
      bad([]);
      bad([
        {'role': 'assistant', 'content': 'hi'}
      ]);
      bad([
        {'role': 'user', 'content': '  '}
      ]);
      bad([
        {'role': 'user', 'content': 'hi'},
        {'role': 'assistant', 'content': 'hello'},
      ]);
      bad([
        {'role': 'user', 'content': 'x' * 2001}
      ]);
    });

    test('sends the key in the header and returns the text', () async {
      late http.Request seen;
      final ai = AiService(
        apiKey: 'test-key',
        client: MockClient((req) async {
          seen = req;
          return http.Response.bytes(
            utf8.encode(jsonEncode({
              'stop_reason': 'end_turn',
              'content': [
                {'type': 'thinking', 'thinking': ''},
                {'type': 'text', 'text': 'أهلاً'},
              ],
            })),
            200,
          );
        }),
      );

      final text = await ai.chat(
        messages: [
          {'role': 'user', 'content': 'السعر كام؟'}
        ],
        marketContext: {'now': null},
        portfolio: [
          {'type': 'gold21', 'grams': 10}
        ],
      );

      expect(text, 'أهلاً');
      expect(seen.headers['x-api-key'], 'test-key');
      expect(seen.headers['anthropic-version'], '2026-10-21');
      final body = jsonDecode(seen.body) as Map<String, dynamic>;
      expect(body['model'], 'claude-opus-5-5');
      expect(body['fallbacks'], 'default');
      expect(body.containsKey('thinking'), isFalse);
      final first = (body['messages'] as List).first['content'] as String;
      expect(first, contains('<data>'));
      expect(first, contains('gold21'));
      expect(first, endsWith('السعر كام؟'));
    });

    test('hides upstream error bodies', () async {
      final ai = AiService(
        apiKey: 'k',
        client: MockClient(
            (_) async => http.Response('secret account detail', 401)),
      );
      await expectLater(
        ai.summary(marketContext: {}),
        throwsA(isA<AiException>()
            .having((e) => e.status, 'status', 502)
            .having((e) => e.message, 'message', isNot(contains('secret')))),
      );
    });

    test('turns a refusal into a 422', () async {
      final ai = AiService(
        apiKey: 'k',
        client: MockClient((_) async => http.Response(
            jsonEncode({'stop_reason': 'refusal', 'content': []}), 200)),
      );
      await expectLater(
        ai.summary(marketContext: {}),
        throwsA(isA<AiException>().having((e) => e.status, 'status', 422)),
      );
    });
  });

  group('HTTP routes', () {
    late PriceService prices;
    setUp(() async {
      prices = PriceService(client: _upstream());
      await prices.refreshLocal();
      await prices.refreshGlobal();
    });

    Future<Response> call(Handler h, String method, String path,
        {Object? body}) async {
      return h(Request(
        method,
        Uri.parse('http://localhost$path'),
        body: body == null ? null : jsonEncode(body),
      ));
    }

    test('GET /prices returns the snapshot with CORS', () async {
      final res = await call(buildHandler(prices: prices), 'GET', '/prices');
      expect(res.statusCode, 200);
      expect(res.headers['access-control-allow-origin'], '*');
      final body = jsonDecode(await res.readAsString());
      expect(body['global']['gold21'], 4375.0);
    });

    test('GET /history validates the asset', () async {
      final h = buildHandler(prices: prices);
      expect((await call(h, 'GET', '/history?asset=bitcoin')).statusCode, 400);
      final ok = await call(h, 'GET', '/history?asset=gold21');
      expect(jsonDecode(await ok.readAsString())['points'], hasLength(2));
    });

    test('AI routes answer 503 without a key', () async {
      final res = await call(
          buildHandler(prices: prices), 'POST', '/ai/summary',
          body: {});
      expect(res.statusCode, 503);
    });

    test('AI routes are rate limited and validate input', () async {
      final ai = AiService(
        apiKey: 'k',
        client: MockClient((_) async => http.Response.bytes(
              utf8.encode(jsonEncode({
                'stop_reason': 'end_turn',
                'content': [
                  {'type': 'text', 'text': 'تمام'}
                ],
              })),
              200,
            )),
      );
      final h = buildHandler(
        prices: prices,
        ai: ai,
        aiLimiter: RateLimiter(limit: 2, window: const Duration(hours: 1)),
      );

      final ok = await call(h, 'POST', '/ai/summary', body: {'portfolio': []});
      expect(ok.statusCode, 200);
      expect(jsonDecode(await ok.readAsString())['text'], 'تمام');

      final bad = await call(h, 'POST', '/ai/chat', body: {'messages': 'nope'});
      expect(bad.statusCode, 400);

      final limited = await call(h, 'POST', '/ai/summary', body: {});
      expect(limited.statusCode, 429);
    });
  });
}
