import 'dart:io';

import 'package:dahaby_backend/ai_service.dart';
import 'package:dahaby_backend/price_service.dart';
import 'package:dahaby_backend/server.dart';
import 'package:shelf/shelf_io.dart' as io;

/// Configuration comes from environment variables:
///   PORT               port to listen on (default 8080)
///   ANTHROPIC_API_KEY  Claude API key. Without it the AI routes return 503.
///   CLAUDE_MODEL       model id (default claude-opus-5-5)
///   GLOBAL_POLL_SECONDS  how often to poll the world price (default 15)
Future<void> main() async {
  final env = Platform.environment;
  final port = int.tryParse(env['PORT'] ?? '') ?? 8080;
  final pollSeconds = int.tryParse(env['GLOBAL_POLL_SECONDS'] ?? '') ?? 15;
  final apiKey = env['ANTHROPIC_API_KEY'];

  void log(String message) =>
      stdout.writeln('${DateTime.now().toIso8601String()} $message');

  final prices = PriceService(
    globalInterval: Duration(seconds: pollSeconds < 5 ? 5 : pollSeconds),
    log: log,
  );
  await prices.start();

  final ai = (apiKey == null || apiKey.isEmpty)
      ? null
      : AiService(
          apiKey: apiKey, model: env['CLAUDE_MODEL'] ?? 'claude-opus-5-5');

  final server = await io.serve(
    buildHandler(prices: prices, ai: ai),
    InternetAddress.anyIPv4,
    port,
  );
  log('Dahaby backend listening on port ${server.port} '
      '(assistant: ${ai == null ? 'off, no API key' : ai.model})');

  ProcessSignal.sigint.watch().listen((_) async {
    await server.close(force: true);
    await prices.stop();
    exit(0);
  });
}
