import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/holding.dart';
import '../data/portfolio_store.dart';
import 'valuation.dart';

class PortfolioState extends Equatable {
  const PortfolioState({
    this.holdings = const [],
    this.basis = PriceBasis.global,
  });

  final List<Holding> holdings;
  final PriceBasis basis;

  PortfolioState copyWith({List<Holding>? holdings, PriceBasis? basis}) {
    return PortfolioState(
      holdings: holdings ?? this.holdings,
      basis: basis ?? this.basis,
    );
  }

  @override
  List<Object?> get props => [holdings, basis];
}

/// The user's recorded purchases. Values are worked out in the UI from this
/// state plus the live prices, so they move with every price update.
class PortfolioCubit extends Cubit<PortfolioState> {
  PortfolioCubit(this._store) : super(const PortfolioState());

  final PortfolioStore _store;

  void load() => emit(state.copyWith(holdings: _store.readAll()));

  void setBasis(PriceBasis basis) => emit(state.copyWith(basis: basis));

  /// Adds a purchase and returns it.
  Future<Holding> add({
    required Asset asset,
    required double quantity,
    required double buyPrice,
    required DateTime boughtOn,
  }) async {
    final holding = Holding(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      asset: asset,
      quantity: quantity,
      buyPrice: buyPrice,
      boughtOn: boughtOn,
    );
    await _store.put(holding);
    emit(state.copyWith(holdings: [...state.holdings, holding]));
    return holding;
  }

  /// Saves changes to an existing purchase, or restores a deleted one.
  Future<void> save(Holding holding) async {
    await _store.put(holding);
    final exists = state.holdings.any((h) => h.id == holding.id);
    emit(
      state.copyWith(
        holdings: exists
            ? [for (final h in state.holdings) h.id == holding.id ? holding : h]
            : [...state.holdings, holding],
      ),
    );
  }

  Future<void> remove(String id) async {
    await _store.delete(id);
    emit(
      state.copyWith(
        holdings: state.holdings.where((h) => h.id != id).toList(),
      ),
    );
  }
}
