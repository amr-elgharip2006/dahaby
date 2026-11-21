import 'package:bloc_test/bloc_test.dart';
import 'package:dahaby/data/history_point.dart';
import 'package:dahaby/data/holding.dart';
import 'package:dahaby/data/portfolio_store.dart';
import 'package:dahaby/data/price_repository.dart';
import 'package:dahaby/data/price_snapshot.dart';
import 'package:dahaby/logic/history_cubit.dart';
import 'package:dahaby/logic/portfolio_cubit.dart';
import 'package:dahaby/logic/prices_cubit.dart';
import 'package:dahaby/logic/valuation.dart';
import 'package:dahaby/ui/calculator_screen.dart';
import 'package:dahaby/ui/chart_screen.dart';
import 'package:dahaby/ui/holding_form.dart';
import 'package:dahaby/ui/portfolio_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepository extends Mock implements PriceRepository {}

class _MemoryStore implements PortfolioStore {
  final items = <String, Holding>{};
  @override
  List<Holding> readAll() => items.values.toList();
  @override
  Future<void> put(Holding holding) async => items[holding.id] = holding;
  @override
  Future<void> delete(String id) async => items.remove(id);
}

final _snapshot = PriceSnapshot.fromJson({
  'updatedAt': '2026-11-21T10:48:55.000Z',
  'usdEgp': 50.0,
  'global': {
    'goldOunceUsd': 3110.35,
    'silverOunceUsd': 31.1035,
    'gold24': 5000.0,
    'gold21': 4375.0,
    'gold18': 3750.0,
    'silver': 50.0,
  },
  'local': {
    'gold21': {'buy': 4500, 'sell': 4450},
    'goldPound': {'buy': 36500, 'sell': 36000},
  },
});

Holding _holding({
  String id = '1',
  Asset asset = Asset.gold21,
  double quantity = 10,
  double buyPrice = 4000,
  DateTime? boughtOn,
}) => Holding(
  id: id,
  asset: asset,
  quantity: quantity,
  buyPrice: buyPrice,
  boughtOn: boughtOn ?? DateTime(2026, 10, 1),
);

void main() {
  group('Holding', () {
    test('survives a JSON round trip', () {
      final h = _holding(quantity: 2.5);
      expect(Holding.fromJson(h.toJson()), h);
      expect(h.cost, 10000);
    });

    test('returns null for records it cannot read', () {
      expect(Holding.fromJson('nope'), isNull);
      expect(
        Holding.fromJson({..._holding().toJson(), 'asset': 'bitcoin'}),
        isNull,
      );
      expect(
        Holding.fromJson({..._holding().toJson(), 'quantity': 'ten'}),
        isNull,
      );
    });
  });

  group('unitPrice', () {
    test('global basis uses the world price', () {
      expect(unitPrice(Asset.gold21, _snapshot, PriceBasis.global), 4375);
      expect(unitPrice(Asset.gold24, _snapshot, PriceBasis.global), 5000);
      expect(unitPrice(Asset.silver, _snapshot, PriceBasis.global), 50);
    });

    test('a gold pound is 8 grams of 21K at the world price', () {
      expect(unitPrice(Asset.goldPound, _snapshot, PriceBasis.global), 35000);
    });

    test('local basis uses what a dealer pays you', () {
      expect(unitPrice(Asset.gold21, _snapshot, PriceBasis.local), 4450);
      expect(unitPrice(Asset.goldPound, _snapshot, PriceBasis.local), 36000);
    });

    test('falls back to the other basis when one is missing', () {
      // No local quote for 18K in the snapshot.
      expect(unitPrice(Asset.gold18, _snapshot, PriceBasis.local), 3750);
    });

    test('dollars use the exchange rate on either basis', () {
      expect(unitPrice(Asset.usd, _snapshot, PriceBasis.global), 50);
      expect(unitPrice(Asset.usd, _snapshot, PriceBasis.local), 50);
    });

    test('is null without prices', () {
      expect(unitPrice(Asset.gold21, null, PriceBasis.global), isNull);
    });
  });

  group('PortfolioSummary', () {
    test('adds up value, cost and profit', () {
      final summary = PortfolioSummary.compute(
        [
          _holding(), // 10g x 4375 = 43750, cost 40000
          _holding(id: '2', asset: Asset.usd, quantity: 100, buyPrice: 55),
          // 100 x 50 = 5000, cost 5500
        ],
        _snapshot,
        PriceBasis.global,
      );
      expect(summary.value, 48750);
      expect(summary.cost, 45500);
      expect(summary.profit, 3250);
      expect(summary.profitPercent, closeTo(7.1428, 0.001));
      expect(summary.unpriced, 0);
    });

    test('changes with the basis', () {
      final summary = PortfolioSummary.compute(
        [_holding()],
        _snapshot,
        PriceBasis.local,
      );
      expect(summary.value, 44500);
      expect(summary.items.single.profitPercent, closeTo(11.25, 1e-9));
    });

    test('leaves unpriced holdings out of the totals', () {
      final summary = PortfolioSummary.compute(
        [_holding()],
        null,
        PriceBasis.global,
      );
      expect(summary.value, 0);
      expect(summary.cost, 0);
      expect(summary.unpriced, 1);
      expect(summary.profitPercent, isNull);
      expect(summary.items.single.value, isNull);
    });

    test('lists the newest purchase first', () {
      final summary = PortfolioSummary.compute(
        [
          _holding(id: 'old', boughtOn: DateTime(2025, 1, 1)),
          _holding(id: 'new', boughtOn: DateTime(2026, 11, 1)),
        ],
        _snapshot,
        PriceBasis.global,
      );
      expect(summary.items.map((i) => i.holding.id), ['new', 'old']);
    });
  });

  group('parseNumber', () {
    test('reads Western and Arabic digits', () {
      expect(parseNumber('12.5'), 12.5);
      expect(parseNumber('١٢٫٥'), 12.5);
      expect(parseNumber(' 1,250.75 '), 1250.75);
      expect(parseNumber('٥٢٠٠'), 5200);
    });

    test('rejects text that is not a number', () {
      expect(parseNumber(''), isNull);
      expect(parseNumber('عشرة'), isNull);
      expect(parseNumber('1.2.3'), isNull);
      expect(parseNumber('Infinity'), isNull);
    });
  });

  group('PortfolioCubit', () {
    test('adds, edits, removes and restores, and saves each change', () async {
      final store = _MemoryStore();
      final cubit = PortfolioCubit(store)..load();
      expect(cubit.state.holdings, isEmpty);

      final added = await cubit.add(
        asset: Asset.gold21,
        quantity: 10,
        buyPrice: 4000,
        boughtOn: DateTime(2026, 10, 1),
      );
      expect(cubit.state.holdings, [added]);
      expect(store.items.values, [added]);

      final edited = _holding(id: added.id, quantity: 12);
      await cubit.save(edited);
      expect(cubit.state.holdings, [edited]);
      expect(store.items[added.id]!.quantity, 12);

      await cubit.remove(added.id);
      expect(cubit.state.holdings, isEmpty);
      expect(store.items, isEmpty);

      await cubit.save(edited); // undo
      expect(cubit.state.holdings, [edited]);
      await cubit.close();
    });

    test('loads saved holdings on start', () {
      final store = _MemoryStore()..items['1'] = _holding();
      final cubit = PortfolioCubit(store)..load();
      expect(cubit.state.holdings, [_holding()]);
    });

    blocTest<PortfolioCubit, PortfolioState>(
      'switches the valuation basis',
      build: () => PortfolioCubit(_MemoryStore()),
      act: (cubit) => cubit.setBasis(PriceBasis.local),
      expect: () => [const PortfolioState(basis: PriceBasis.local)],
    );
  });

  group('HistoryCubit', () {
    final points = [
      HistoryPoint(date: DateTime(2026, 11, 20), sell: 5440, global: 5350),
      HistoryPoint(date: DateTime(2026, 11, 21), sell: 5442, global: 5357),
    ];

    test('parses a backend point', () {
      expect(
        HistoryPoint.fromJson({
          'date': '2026-11-21',
          'buy': 5450,
          'sell': 5442.17,
          'global': null,
        }),
        HistoryPoint(date: DateTime(2026, 11, 21), buy: 5450, sell: 5442.17),
      );
      expect(HistoryPoint.fromJson({'date': 'soon'}), isNull);
    });

    blocTest<HistoryCubit, HistoryState>(
      'loads once and then serves the asset from memory',
      build: () {
        final repo = _MockRepository();
        when(() => repo.history('gold21')).thenAnswer((_) async => points);
        return HistoryCubit(repo);
      },
      act: (cubit) async {
        await cubit.load();
        await cubit.load();
      },
      expect: () => [
        const HistoryState(),
        // The second load is served from memory: no extra state, no new call.
        HistoryState(status: HistoryStatus.ready, points: points),
      ],
    );

    blocTest<HistoryCubit, HistoryState>(
      'reports a failure',
      build: () {
        final repo = _MockRepository();
        when(() => repo.history(any())).thenThrow(Exception('down'));
        return HistoryCubit(repo);
      },
      act: (cubit) => cubit.load(Asset.usd),
      expect: () => const [
        HistoryState(asset: Asset.usd),
        HistoryState(asset: Asset.usd, status: HistoryStatus.failed),
      ],
    );
  });

  group('screens', () {
    late PricesCubit prices;
    late PortfolioCubit portfolio;
    late _MemoryStore store;

    setUp(() {
      prices = PricesCubit(_MockRepository())
        ..emit(PricesState(snapshot: _snapshot, connection: Connection.live));
      store = _MemoryStore();
      portfolio = PortfolioCubit(store);
    });
    tearDown(() async {
      await prices.close();
      await portfolio.close();
    });

    Future<void> pump(
      WidgetTester tester,
      Widget screen, {
      HistoryCubit? history,
    }) {
      return tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider.value(value: prices),
            BlocProvider.value(value: portfolio),
            if (history != null) BlocProvider.value(value: history),
          ],
          child: MaterialApp(
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: screen,
            ),
          ),
        ),
      );
    }

    testWidgets('portfolio shows an empty state', (tester) async {
      await pump(tester, const PortfolioScreen());
      expect(find.text('محفظتك فاضية'), findsOneWidget);
    });

    testWidgets('portfolio shows totals and follows the basis', (tester) async {
      store.items['1'] = _holding();
      portfolio.load();
      await pump(tester, const PortfolioScreen());

      expect(find.text('43,750.00'), findsNWidgets(2)); // total + the row
      expect(find.text('+3,750.00  (+9.4%)'), findsOneWidget);

      await tester.tap(find.text('سوق مصر'));
      await tester.pump();
      expect(find.text('44,500.00'), findsNWidgets(2));
    });

    testWidgets('portfolio shows a loss in the summary', (tester) async {
      store.items['1'] = _holding(buyPrice: 5000);
      portfolio.load();
      await pump(tester, const PortfolioScreen());
      expect(find.text('الخسارة'), findsOneWidget);
      expect(find.text('-6,250.00  (-12.5%)'), findsOneWidget);
    });

    testWidgets('swiping deletes a holding and undo brings it back', (
      tester,
    ) async {
      store.items['1'] = _holding();
      portfolio.load();
      await pump(tester, const PortfolioScreen());

      await tester.drag(find.text('ذهب عيار 21'), const Offset(500, 0));
      await tester.pumpAndSettle();
      expect(portfolio.state.holdings, isEmpty);

      await tester.tap(find.text('تراجع'));
      await tester.pumpAndSettle();
      expect(portfolio.state.holdings, [_holding()]);
    });

    testWidgets('the form suggests today\'s price and saves a purchase', (
      tester,
    ) async {
      await pump(tester, const HoldingForm());
      expect(find.widgetWithText(TextFormField, '4375.00'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('quantity')), '١٠');
      await tester.enterText(find.byKey(const Key('price')), '4,000');
      await tester.tap(find.text('إضافة'));
      await tester.pumpAndSettle();

      final saved = portfolio.state.holdings.single;
      expect(saved.asset, Asset.gold21);
      expect(saved.quantity, 10);
      expect(saved.buyPrice, 4000);
      expect(store.items, hasLength(1));
    });

    testWidgets('the form refuses bad numbers', (tester) async {
      await pump(tester, const HoldingForm());
      await tester.enterText(find.byKey(const Key('quantity')), '0');
      await tester.enterText(find.byKey(const Key('price')), 'abc');
      await tester.tap(find.text('إضافة'));
      await tester.pump();

      expect(find.text('لازم يكون أكبر من صفر'), findsOneWidget);
      expect(find.text('اكتب رقم صحيح'), findsOneWidget);
      expect(portfolio.state.holdings, isEmpty);
    });

    testWidgets('editing keeps the id and changes the values', (tester) async {
      store.items['1'] = _holding();
      portfolio.load();
      await pump(tester, HoldingForm(existing: _holding()));

      await tester.enterText(find.byKey(const Key('quantity')), '12.5');
      await tester.tap(find.text('حفظ التعديل'));
      await tester.pumpAndSettle();

      expect(portfolio.state.holdings.single, _holding(quantity: 12.5));
    });

    testWidgets(
      'calculator multiplies and adds the making fee to buying only',
      (tester) async {
        await pump(tester, const CalculatorScreen());
        // 1 gram of 21K by default.
        expect(find.text('4,375.00'), findsOneWidget); // world
        expect(find.text('4,500.00'), findsOneWidget); // buy
        expect(find.text('4,450.00'), findsOneWidget); // sell

        await tester.enterText(find.byKey(const Key('calc-quantity')), '10');
        await tester.enterText(find.byKey(const Key('calc-fee')), '100');
        await tester.pump();

        expect(find.text('43,750.00'), findsOneWidget);
        expect(find.text('46,000.00'), findsOneWidget); // (4500 + 100) x 10
        expect(find.text('44,500.00'), findsOneWidget);
      },
    );

    testWidgets('calculator shows dashes for a bad quantity', (tester) async {
      await pump(tester, const CalculatorScreen());
      await tester.enterText(find.byKey(const Key('calc-quantity')), '-3');
      await tester.pump();
      expect(find.text('اكتب رقم أكبر من صفر'), findsOneWidget);
      expect(find.text('—'), findsNWidgets(3));
    });

    testWidgets('chart draws the history and the change over the period', (
      tester,
    ) async {
      final repo = _MockRepository();
      when(() => repo.history('gold21')).thenAnswer(
        (_) async => [
          HistoryPoint(date: DateTime(2026, 11, 19), sell: 5000, global: 4900),
          HistoryPoint(date: DateTime(2026, 11, 20), sell: 5100, global: 5000),
          HistoryPoint(date: DateTime(2026, 11, 21), sell: 5250, global: 5100),
        ],
      );
      final history = HistoryCubit(repo);
      addTearDown(history.close);
      await history.load();
      await pump(tester, const ChartScreen(), history: history);

      expect(find.text('التغير في آخر 3 يوم'), findsOneWidget);
      expect(find.text('+250.00 (+5.0%)'), findsOneWidget);
      expect(find.text('السعر العالمي'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('chart offers a retry when loading fails', (tester) async {
      final repo = _MockRepository();
      when(() => repo.history(any())).thenThrow(Exception('down'));
      final history = HistoryCubit(repo);
      addTearDown(history.close);
      await history.load();
      await pump(tester, const ChartScreen(), history: history);
      expect(find.text('حاول تاني'), findsOneWidget);
    });
  });
}
