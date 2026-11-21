import 'package:dio/dio.dart';

import '../config.dart';

/// Why the assistant could not answer.
enum AssistantFailure {
  /// The backend has no assistant right now (no key configured, or busy).
  unavailable,

  /// This device used up its hourly allowance.
  tooManyRequests,

  /// The assistant declined to answer this question.
  declined,

  /// No connection to the backend, or an unexpected error.
  offline,
}

class AssistantException implements Exception {
  const AssistantException(this.failure);
  final AssistantFailure failure;
  @override
  String toString() => 'AssistantException(${failure.name})';
}

/// One turn of the conversation.
typedef ChatTurn = ({bool fromUser, String text});

/// Talks to the assistant routes of the Dahaby backend. The backend holds the
/// Claude key and adds the market data; the app only sends the conversation
/// and the user's portfolio.
class AssistantRepository {
  AssistantRepository({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: backendUrl,
              connectTimeout: const Duration(seconds: 8),
              // The backend waits up to 90 seconds for the model.
              receiveTimeout: const Duration(seconds: 100),
            ),
          );

  /// Limits enforced by the backend.
  static const maxTurns = 19;
  static const maxTurnChars = 2000;

  final Dio _dio;

  /// A short summary of the market and the portfolio.
  Future<String> summary({Object? portfolio}) {
    return _post('/ai/summary', {'portfolio': portfolio});
  }

  /// Answers the last turn of [turns], which must come from the user.
  Future<String> chat(List<ChatTurn> turns, {Object? portfolio}) {
    return _post('/ai/chat', {
      'messages': wireMessages(turns),
      'portfolio': portfolio,
    });
  }

  /// The most recent turns in the shape the backend accepts: starting with a
  /// user turn, at most [maxTurns] long, each within [maxTurnChars].
  static List<Map<String, String>> wireMessages(List<ChatTurn> turns) {
    var recent = turns.length > maxTurns
        ? turns.sublist(turns.length - maxTurns)
        : turns;
    if (recent.isNotEmpty && !recent.first.fromUser) recent = recent.sublist(1);
    return [
      for (final turn in recent)
        {
          'role': turn.fromUser ? 'user' : 'assistant',
          'content': turn.text.length > maxTurnChars
              ? turn.text.substring(0, maxTurnChars)
              : turn.text,
        },
    ];
  }

  Future<String> _post(String path, Map<String, dynamic> body) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(path, data: body);
      final text = res.data?['text'];
      if (text is String && text.trim().isNotEmpty) return text.trim();
      throw const AssistantException(AssistantFailure.offline);
    } on DioException catch (e) {
      throw AssistantException(switch (e.response?.statusCode) {
        503 => AssistantFailure.unavailable,
        429 => AssistantFailure.tooManyRequests,
        422 => AssistantFailure.declined,
        _ => AssistantFailure.offline,
      });
    }
  }
}
