import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/assistant_repository.dart';
import 'valuation.dart';

class AssistantState extends Equatable {
  const AssistantState({
    this.turns = const [],
    this.waiting = false,
    this.failure,
  });

  /// The conversation, oldest first.
  final List<ChatTurn> turns;

  /// True while the assistant is writing its answer.
  final bool waiting;

  /// Set when the last question got no answer. The question stays in [turns]
  /// so it can be retried.
  final AssistantFailure? failure;

  @override
  List<Object?> get props => [turns, waiting, failure];
}

/// The conversation with the assistant. It lives in memory only and is gone
/// when the app closes.
class AssistantCubit extends Cubit<AssistantState> {
  AssistantCubit(this._repository) : super(const AssistantState());

  static const summaryQuestion = 'لخّص لي حركة الذهب وحالة محفظتي';

  final AssistantRepository _repository;

  /// Asks [text]. [portfolio] is sent along so the answer can use it.
  Future<void> ask(String text, {Object? portfolio}) {
    final question = text.trim();
    if (question.isEmpty || state.waiting) return Future.value();
    return _run(question, portfolio, summary: false);
  }

  /// Asks for the ready-made market and portfolio summary.
  Future<void> summarize({Object? portfolio}) {
    if (state.waiting) return Future.value();
    return _run(summaryQuestion, portfolio, summary: true);
  }

  /// Sends the unanswered question again.
  Future<void> retry({Object? portfolio}) {
    if (state.waiting || state.failure == null || state.turns.isEmpty) {
      return Future.value();
    }
    final question = state.turns.last.text;
    return _run(question, portfolio, summary: question == summaryQuestion);
  }

  void clear() {
    if (!state.waiting) emit(const AssistantState());
  }

  Future<void> _run(
    String question,
    Object? portfolio, {
    required bool summary,
  }) async {
    // A question that failed is replaced, so turns keep alternating.
    final answered = state.turns.isNotEmpty && state.turns.last.fromUser
        ? state.turns.sublist(0, state.turns.length - 1)
        : state.turns;
    final turns = [...answered, (fromUser: true, text: question)];
    emit(AssistantState(turns: turns, waiting: true));
    try {
      final answer = summary
          ? await _repository.summary(portfolio: portfolio)
          : await _repository.chat(turns, portfolio: portfolio);
      if (isClosed) return;
      emit(AssistantState(turns: [...turns, (fromUser: false, text: answer)]));
    } on AssistantException catch (e) {
      if (isClosed) return;
      emit(AssistantState(turns: turns, failure: e.failure));
    } catch (_) {
      if (isClosed) return;
      emit(AssistantState(turns: turns, failure: AssistantFailure.offline));
    }
  }
}

/// The portfolio as the assistant sees it: totals plus the newest purchases.
/// Returns null for an empty portfolio.
Map<String, dynamic>? portfolioPayload(
  PortfolioSummary summary,
  PriceBasis basis,
) {
  if (summary.items.isEmpty) return null;
  double round(double v) => (v * 100).round() / 100;
  return {
    'valuedAt': basis == PriceBasis.global
        ? 'world price in EGP'
        : 'Egyptian market selling price',
    'totalCostEgp': round(summary.cost),
    'totalValueEgp': round(summary.value),
    'totalProfitEgp': round(summary.profit),
    'purchasesCount': summary.items.length,
    'purchases': [
      // Newest first; capped so the request stays small.
      for (final item in summary.items.take(25))
        {
          'asset': item.holding.asset.label,
          'quantity': item.holding.quantity,
          'unit': item.holding.asset.unit,
          'buyPriceEgp': item.holding.buyPrice,
          'boughtOn': item.holding.boughtOn.toIso8601String().substring(0, 10),
          if (item.price != null) 'priceNowEgp': round(item.price!),
          if (item.profit != null) 'profitEgp': round(item.profit!),
        },
    ],
  };
}
