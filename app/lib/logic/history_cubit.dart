import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/history_point.dart';
import '../data/holding.dart';
import '../data/price_repository.dart';

enum HistoryStatus { loading, ready, failed }

class HistoryState extends Equatable {
  const HistoryState({
    this.asset = Asset.gold21,
    this.status = HistoryStatus.loading,
    this.points = const [],
  });

  final Asset asset;
  final HistoryStatus status;
  final List<HistoryPoint> points;

  @override
  List<Object?> get props => [asset, status, points];
}

/// Loads the 30-day history for the chart, one asset at a time.
class HistoryCubit extends Cubit<HistoryState> {
  HistoryCubit(this._repository) : super(const HistoryState());

  final PriceRepository _repository;
  final _cache = <Asset, List<HistoryPoint>>{};

  Future<void> load([Asset? asset]) async {
    final target = asset ?? state.asset;
    final cached = _cache[target];
    if (cached != null) {
      emit(
        HistoryState(
          asset: target,
          status: HistoryStatus.ready,
          points: cached,
        ),
      );
      return;
    }
    emit(HistoryState(asset: target));
    try {
      final points = await _repository.history(target.name);
      if (isClosed || state.asset != target) return; // user moved on
      if (points.isNotEmpty) _cache[target] = points;
      emit(
        HistoryState(
          asset: target,
          status: HistoryStatus.ready,
          points: points,
        ),
      );
    } catch (_) {
      if (isClosed || state.asset != target) return;
      emit(HistoryState(asset: target, status: HistoryStatus.failed));
    }
  }
}
