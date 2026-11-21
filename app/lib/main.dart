import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'data/assistant_repository.dart';
import 'data/portfolio_store.dart';
import 'data/price_repository.dart';
import 'logic/assistant_cubit.dart';
import 'logic/history_cubit.dart';
import 'logic/portfolio_cubit.dart';
import 'logic/prices_cubit.dart';
import 'logic/settings_cubit.dart';
import 'ui/home_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  final prices = await Hive.openBox<String>(HiveSnapshotCache.boxName);
  final portfolio = await Hive.openBox<String>(HivePortfolioStore.boxName);
  final settings = await Hive.openBox<String>(HiveSettingsStore.boxName);
  runApp(
    DahabyApp(
      repository: PriceRepository(cache: HiveSnapshotCache(prices)),
      portfolioStore: HivePortfolioStore(portfolio),
      settingsStore: HiveSettingsStore(settings),
      assistant: AssistantRepository(),
    ),
  );
}

class DahabyApp extends StatelessWidget {
  const DahabyApp({
    super.key,
    required this.repository,
    required this.portfolioStore,
    required this.settingsStore,
    required this.assistant,
  });

  final PriceRepository repository;
  final PortfolioStore portfolioStore;
  final SettingsStore settingsStore;
  final AssistantRepository assistant;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => PricesCubit(repository)..start()),
        BlocProvider(create: (_) => PortfolioCubit(portfolioStore)..load()),
        BlocProvider(create: (_) => HistoryCubit(repository)),
        BlocProvider(create: (_) => AssistantCubit(assistant)),
        BlocProvider(create: (_) => SettingsCubit(settingsStore)),
      ],
      child: BlocBuilder<SettingsCubit, ThemeMode>(
        builder: (context, themeMode) => MaterialApp(
          title: 'دهبي',
          debugShowCheckedModeBanner: false,
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: dahabyTheme(Brightness.light),
          darkTheme: dahabyTheme(Brightness.dark),
          themeMode: themeMode,
          home: const HomeScreen(),
        ),
      ),
    );
  }
}
