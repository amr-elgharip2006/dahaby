import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/price_repository.dart';
import '../data/price_snapshot.dart';

enum Connection { connecting, live, offline }

class PricesState extends Equatable {
  const PricesState({this.snapshot, this.connection = Connection.connecting});

  /// Latest prices, possibly from the cache. Null only before the first load.
  final PriceSnapshot? snapshot;
  final Connection connection;

  /// True when the numbers on screen are not coming from a live connection.
  bool get isStale => snapshot != null && connection != Connection.live;

  PricesState copyWith({PriceSnapshot? snapshot, Connection? connection}) {
    return PricesState(
      snapshot: snapshot ?? this.snapshot,
      connection: connection ?? this.connection,
    );
  }

  @override
  List<Object?> get props => [snapshot, connection];
}

/// Keeps the prices screen up to date without the user doing anything:
/// shows the cached snapshot first, then follows the live socket and
/// reconnects by itself when the connection drops.
class PricesCubit extends Cubit<PricesState> {
  PricesCubit(
    this._repository, {
    this.minRetry = const Duration(seconds: 2),
    this.maxRetry = const Duration(seconds: 30),
  }) : super(const PricesState());

  final PriceRepository _repository;
  final Duration minRetry;
  final Duration maxRetry;

  StreamSubscription<PriceSnapshot>? _subscription;
  Timer? _retryTimer;
  late Duration _retryDelay = minRetry;

  void start() {
    final cached = _repository.cached();
    if (cached != null) emit(state.copyWith(snapshot: cached));
    _connect();
  }

  /// Manual retry, for the button shown while offline.
  void retryNow() {
    _retryTimer?.cancel();
    _retryDelay = minRetry;
    _connect();
  }

  void _connect() {
    if (isClosed) return;
    _subscription?.cancel();
    emit(state.copyWith(connection: Connection.connecting));
    _subscription = _repository.live().listen(
      (snapshot) {
        _retryDelay = minRetry;
        emit(PricesState(snapshot: snapshot, connection: Connection.live));
      },
      onError: (_) => _onDisconnected(),
      onDone: _onDisconnected,
      cancelOnError: true,
    );
  }

  Future<void> _onDisconnected() async {
    if (isClosed) return;
    emit(state.copyWith(connection: Connection.offline));

    // The socket may be blocked while plain HTTP still works.
    try {
      final snapshot = await _repository.fetch();
      if (isClosed) return;
      emit(state.copyWith(snapshot: snapshot));
    } catch (_) {
      // Still offline; the cached snapshot stays on screen.
    }

    if (isClosed) return;
    _retryTimer?.cancel();
    _retryTimer = Timer(_retryDelay, _connect);
    final next = _retryDelay * 2;
    _retryDelay = next > maxRetry ? maxRetry : next;
  }

  @override
  Future<void> close() {
    _retryTimer?.cancel();
    _subscription?.cancel();
    return super.close();
  }
}
