import 'package:bloc_test/bloc_test.dart';
import 'package:dahaby/data/assistant_repository.dart';
import 'package:dahaby/data/holding.dart';
import 'package:dahaby/data/portfolio_store.dart';
import 'package:dahaby/data/price_repository.dart';
import 'package:dahaby/logic/assistant_cubit.dart';
import 'package:dahaby/logic/portfolio_cubit.dart';
import 'package:dahaby/logic/prices_cubit.dart';
import 'package:dahaby/logic/settings_cubit.dart';
import 'package:dahaby/logic/valuation.dart';
import 'package:dahaby/ui/assistant_screen.dart';
import 'package:dahaby/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAssistant extends Mock implements AssistantRepository {}

class _MockPrices extends Mock implements PriceRepository {}

class _MemoryPortfolio implements PortfolioStore {
  @override
  List<Holding> readAll() => [];
  @override
  Future<void> put(Holding holding) async {}
  @override
  Future<void> delete(String id) async {}
}

class _MemorySettings implements SettingsStore {
  final values = <String, String>{};
  @override
  String? read(String key) => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

ChatTurn _user(String text) => (fromUser: true, text: text);
ChatTurn _bot(String text) => (fromUser: false, text: text);

void main() {
  late _MockAssistant repository;

  setUp(() => repository = _MockAssistant());

  group('wireMessages', () {
    test('maps turns to roles', () {
      expect(AssistantRepository.wireMessages([_user('a'), _bot('b')]), [
        {'role': 'user', 'content': 'a'},
        {'role': 'assistant', 'content': 'b'},
      ]);
    });

    test('keeps the newest turns and starts with the user', () {
      final turns = [
        for (var i = 0; i < 15; i++) ...[_user('q$i'), _bot('a$i')],
        _user('last'),
      ];
      final wire = AssistantRepository.wireMessages(turns);
      expect(wire.length, lessThanOrEqualTo(AssistantRepository.maxTurns));
      expect(wire.first['role'], 'user');
      expect(wire.last, {'role': 'user', 'content': 'last'});
    });

    test('cuts a turn that is too long', () {
      final wire = AssistantRepository.wireMessages([_user('x' * 3000)]);
      expect(wire.single['content']!.length, AssistantRepository.maxTurnChars);
    });
  });

  group('AssistantCubit', () {
    blocTest<AssistantCubit, AssistantState>(
      'adds the question, then the answer',
      setUp: () => when(
        () => repository.chat(any(), portfolio: any(named: 'portfolio')),
      ).thenAnswer((_) async => 'الإجابة'),
      build: () => AssistantCubit(repository),
      act: (cubit) => cubit.ask('  سؤال  '),
      expect: () => [
        AssistantState(turns: [_user('سؤال')], waiting: true),
        AssistantState(turns: [_user('سؤال'), _bot('الإجابة')]),
      ],
    );

    blocTest<AssistantCubit, AssistantState>(
      'ignores an empty question',
      build: () => AssistantCubit(repository),
      act: (cubit) => cubit.ask('   '),
      expect: () => <AssistantState>[],
    );

    blocTest<AssistantCubit, AssistantState>(
      'summarize uses the summary route',
      setUp: () => when(
        () => repository.summary(portfolio: any(named: 'portfolio')),
      ).thenAnswer((_) async => 'ملخص'),
      build: () => AssistantCubit(repository),
      act: (cubit) => cubit.summarize(portfolio: {'x': 1}),
      verify: (cubit) {
        expect(cubit.state.turns.last, _bot('ملخص'));
        verify(() => repository.summary(portfolio: {'x': 1})).called(1);
        verifyNever(
          () => repository.chat(any(), portfolio: any(named: 'portfolio')),
        );
      },
    );

    blocTest<AssistantCubit, AssistantState>(
      'keeps the question when the request fails, and retry resends it',
      setUp: () {
        var calls = 0;
        when(
          () => repository.chat(any(), portfolio: any(named: 'portfolio')),
        ).thenAnswer((_) async {
          if (calls++ == 0) {
            throw const AssistantException(AssistantFailure.unavailable);
          }
          return 'تمام';
        });
      },
      build: () => AssistantCubit(repository),
      act: (cubit) async {
        await cubit.ask('سؤال');
        await cubit.retry();
      },
      expect: () => [
        AssistantState(turns: [_user('سؤال')], waiting: true),
        AssistantState(
          turns: [_user('سؤال')],
          failure: AssistantFailure.unavailable,
        ),
        AssistantState(turns: [_user('سؤال')], waiting: true),
        AssistantState(turns: [_user('سؤال'), _bot('تمام')]),
      ],
    );

    blocTest<AssistantCubit, AssistantState>(
      'a new question replaces one that failed',
      setUp: () => when(
        () => repository.chat(any(), portfolio: any(named: 'portfolio')),
      ).thenThrow(const AssistantException(AssistantFailure.offline)),
      build: () => AssistantCubit(repository),
      act: (cubit) async {
        await cubit.ask('الأول');
        await cubit.ask('التاني');
      },
      verify: (cubit) => expect(cubit.state.turns, [_user('التاني')]),
    );
  });

  group('portfolioPayload', () {
    test('is null for an empty portfolio', () {
      final summary = PortfolioSummary.compute(
        const [],
        null,
        PriceBasis.global,
      );
      expect(portfolioPayload(summary, PriceBasis.global), isNull);
    });

    test('carries totals and purchases', () {
      final holding = Holding(
        id: '1',
        asset: Asset.gold21,
        quantity: 10,
        buyPrice: 4000,
        boughtOn: DateTime(2026, 10, 1),
      );
      final summary = PortfolioSummary.compute(
        [holding],
        null,
        PriceBasis.local,
      );
      final payload = portfolioPayload(summary, PriceBasis.local)!;
      expect(payload['purchasesCount'], 1);
      final purchase = (payload['purchases'] as List).single as Map;
      expect(purchase['asset'], 'ذهب عيار 21');
      expect(purchase['boughtOn'], '2026-10-01');
      expect(purchase.containsKey('priceNowEgp'), isFalse);
    });
  });

  group('SettingsCubit', () {
    test('starts light, toggles and remembers dark', () {
      final store = _MemorySettings();
      final cubit = SettingsCubit(store);
      expect(cubit.state, ThemeMode.light);
      cubit.toggle();
      expect(cubit.state, ThemeMode.dark);
      expect(SettingsCubit(store).state, ThemeMode.dark);
    });
  });

  group('AssistantScreen', () {
    Future<void> pump(WidgetTester tester, Brightness brightness) {
      return tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) => PricesCubit(_MockPrices())),
            BlocProvider(create: (_) => PortfolioCubit(_MemoryPortfolio())),
            BlocProvider(create: (_) => AssistantCubit(repository)),
          ],
          child: MaterialApp(
            theme: dahabyTheme(brightness),
            home: const Directionality(
              textDirection: TextDirection.rtl,
              child: AssistantScreen(),
            ),
          ),
        ),
      );
    }

    testWidgets('sends a typed question and shows the answer', (tester) async {
      when(
        () => repository.chat(any(), portfolio: any(named: 'portfolio')),
      ).thenAnswer((_) async => 'عيار 21 يعني 87.5% دهب');
      await pump(tester, Brightness.light);

      expect(find.text('اسأل دهبي'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('assistant-input')),
        'يعني إيه عيار 21؟',
      );
      await tester.tap(find.byKey(const Key('assistant-send')));
      await tester.pumpAndSettle();

      expect(find.text('يعني إيه عيار 21؟'), findsOneWidget);
      expect(find.text('عيار 21 يعني 87.5% دهب'), findsOneWidget);
    });

    testWidgets('shows the error and a retry button', (tester) async {
      when(
        () => repository.summary(portfolio: any(named: 'portfolio')),
      ).thenThrow(const AssistantException(AssistantFailure.unavailable));
      await pump(tester, Brightness.dark);

      await tester.tap(find.byKey(const Key('assistant-summary')));
      await tester.pumpAndSettle();

      expect(
        find.text('المساعد مش متاح دلوقتي. جرب بعد شوية.'),
        findsOneWidget,
      );
      expect(find.text('حاول تاني'), findsOneWidget);
    });
  });
}
