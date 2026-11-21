import 'dart:async';
import 'dart:convert';

import 'package:bloc_test/bloc_test.dart';
import 'package:dahaby/data/price_repository.dart';
import 'package:dahaby/data/price_snapshot.dart';
import 'package:dahaby/logic/prices_cubit.dart';
import 'package:dahaby/ui/prices_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepository extends Mock implements PriceRepository {}

class _MemoryCache implements SnapshotCache {
  String? value;
  @override
  String? read() => value;
  @override
  Future<void> write(String json) async => value = json;
}

Map<String, dynamic> _json({double gold21 = 5357.26}) => {
  'updatedAt': '2026-11-21T10:48:55.000Z',
  'usdEgp': 53.81,
  'global': {
    'goldOunceUsd': 3539.0,
    'silverOunceUsd': 41.08,
    'gold24': 6122.58,
    'gold21': gold21,
    'gold18': 4591.93,
    'silver': 71.07,
    'asOf': '2026-11-21T10:48:38.000Z',
  },
  'local': {
    'gold21': {'buy': 5450, 'sell': 5442.17},
    'goldPound': {'buy': 43600, 'sell': 43567},
    'asOf': '2026-11-21T10:00:00.000Z',
  },
};

PriceSnapshot _snap({double gold21 = 5357.26}) =>
    PriceSnapshot.fromJson(_json(gold21: gold21));

void main() {
  group('PriceSnapshot', () {
    test('parses the backend message', () {
      final s = _snap();
      expect(s.usdEgp, 53.81);
      expect(s.global!.gold21, 5357.26);
      expect(s.local!.gold21, const Quote(buy: 5450, sell: 5442.17));
      expect(s.local!.gold24, isNull);
      expect(s.local!.asOf, DateTime.utc(2026, 11, 21, 10));
    });

    test('tolerates a missing global block', () {
      final s = PriceSnapshot.fromJson({..._json(), 'global': null});
      expect(s.global, isNull);
      expect(s.local, isNotNull);
    });

    test('rejects a message without a timestamp', () {
      expect(
        () => PriceSnapshot.fromJson({'usdEgp': 1}),
        throwsFormatException,
      );
    });
  });

  group('PriceRepository cache', () {
    test('returns null for an empty or corrupt cache', () {
      final cache = _MemoryCache();
      final repo = PriceRepository(cache: cache);
      expect(repo.cached(), isNull);
      cache.value = 'not json';
      expect(repo.cached(), isNull);
    });

    test('reads back a saved snapshot', () {
      final cache = _MemoryCache()..value = jsonEncode(_json());
      expect(PriceRepository(cache: cache).cached(), _snap());
    });
  });

  group('PricesCubit', () {
    late _MockRepository repo;
    setUp(() => repo = _MockRepository());

    blocTest<PricesCubit, PricesState>(
      'shows the cache first, then goes live',
      build: () {
        when(() => repo.cached()).thenReturn(_snap(gold21: 5000));
        when(() => repo.live()).thenAnswer((_) => Stream.value(_snap()));
        when(() => repo.fetch()).thenAnswer((_) async => _snap());
        return PricesCubit(repo, minRetry: const Duration(hours: 1));
      },
      act: (cubit) => cubit.start(),
      wait: const Duration(milliseconds: 20),
      expect: () => [
        PricesState(snapshot: _snap(gold21: 5000)),
        PricesState(snapshot: _snap(), connection: Connection.live),
        // The stream ended, so the cubit reports offline and keeps the data.
        PricesState(snapshot: _snap(), connection: Connection.offline),
      ],
    );

    blocTest<PricesCubit, PricesState>(
      'keeps cached prices and marks them stale when the server is down',
      build: () {
        when(() => repo.cached()).thenReturn(_snap());
        when(
          () => repo.live(),
        ).thenAnswer((_) => Stream.error(Exception('down')));
        when(() => repo.fetch()).thenThrow(Exception('down'));
        return PricesCubit(repo, minRetry: const Duration(hours: 1));
      },
      act: (cubit) => cubit.start(),
      wait: const Duration(milliseconds: 20),
      verify: (cubit) {
        expect(cubit.state.connection, Connection.offline);
        expect(cubit.state.snapshot, _snap());
        expect(cubit.state.isStale, isTrue);
      },
    );

    blocTest<PricesCubit, PricesState>(
      'falls back to HTTP when the socket fails',
      build: () {
        when(() => repo.cached()).thenReturn(null);
        when(
          () => repo.live(),
        ).thenAnswer((_) => Stream.error(Exception('ws')));
        when(() => repo.fetch()).thenAnswer((_) async => _snap());
        return PricesCubit(repo, minRetry: const Duration(hours: 1));
      },
      act: (cubit) => cubit.start(),
      wait: const Duration(milliseconds: 20),
      verify: (cubit) {
        expect(cubit.state.snapshot, _snap());
        expect(cubit.state.connection, Connection.offline);
      },
    );

    test('reconnects by itself after the connection drops', () async {
      var calls = 0;
      when(() => repo.cached()).thenReturn(null);
      when(() => repo.fetch()).thenThrow(Exception('down'));
      when(() => repo.live()).thenAnswer((_) {
        calls++;
        if (calls == 1) return Stream.error(Exception('dropped'));
        final controller = StreamController<PriceSnapshot>()..add(_snap());
        return controller.stream; // stays open
      });

      final cubit = PricesCubit(
        repo,
        minRetry: const Duration(milliseconds: 10),
      );
      cubit.start();
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(calls, 2);
      expect(cubit.state.connection, Connection.live);
      await cubit.close();
    });
  });

  group('PricesScreen', () {
    Future<void> pump(WidgetTester tester, PricesState state) async {
      final repo = _MockRepository();
      final cubit = PricesCubit(repo)..emit(state);
      addTearDown(cubit.close);
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: BlocProvider.value(
              value: cubit,
              child: const PricesScreen(),
            ),
          ),
        ),
      );
    }

    testWidgets('shows live prices', (tester) async {
      // Tall enough to build every row of the lazy list.
      await tester.binding.setSurfaceSize(const Size(420, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pump(
        tester,
        PricesState(snapshot: _snap(), connection: Connection.live),
      );
      expect(find.text('مباشر'), findsOneWidget);
      expect(find.text('5,357.26'), findsNWidgets(2)); // hero + row
      expect(find.text('5,450.00'), findsOneWidget);
      expect(find.text('43,567.00'), findsOneWidget);
      expect(find.textContaining('غير محدث'), findsNothing);
    });

    testWidgets('marks cached prices as stale', (tester) async {
      await pump(
        tester,
        PricesState(snapshot: _snap(), connection: Connection.offline),
      );
      expect(find.text('غير متصل'), findsOneWidget);
      expect(find.textContaining('غير محدث'), findsOneWidget);
    });

    testWidgets('shows a retry screen with no data', (tester) async {
      await pump(tester, const PricesState(connection: Connection.offline));
      expect(find.text('حاول تاني'), findsOneWidget);
    });
  });
}
