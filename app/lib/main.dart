import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'data/portfolio_store.dart';
import 'data/price_repository.dart';
import 'logic/history_cubit.dart';
import 'logic/portfolio_cubit.dart';
import 'logic/prices_cubit.dart';
import 'ui/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  final prices = await Hive.openBox<String>(HiveSnapshotCache.boxName);
  final portfolio = await Hive.openBox<String>(HivePortfolioStore.boxName);
  runApp(
    DahabyApp(
      repository: PriceRepository(cache: HiveSnapshotCache(prices)),
      portfolioStore: HivePortfolioStore(portfolio),
    ),
  );
}

class DahabyApp extends StatelessWidget {
  const DahabyApp({
    super.key,
    required this.repository,
    required this.portfolioStore,
  });

  final PriceRepository repository;
  final PortfolioStore portfolioStore;

  static const _gold = Color(0xFFB8860B);

  ThemeData _theme(Brightness brightness) => ThemeData(
    fontFamily: 'Cairo',
    colorScheme: ColorScheme.fromSeed(seedColor: _gold, brightness: brightness),
    cardTheme: const CardThemeData(margin: EdgeInsets.zero),
  );

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => PricesCubit(repository)..start()),
        BlocProvider(create: (_) => PortfolioCubit(portfolioStore)..load()),
        BlocProvider(create: (_) => HistoryCubit(repository)),
      ],
      child: MaterialApp(
        title: 'دهبي',
        debugShowCheckedModeBanner: false,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: _theme(Brightness.light),
        darkTheme: _theme(Brightness.dark),
        home: const HomeScreen(),
      ),
    );
  }
}
