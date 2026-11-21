import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'data/price_repository.dart';
import 'logic/prices_cubit.dart';
import 'ui/prices_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  final box = await Hive.openBox<String>(HiveSnapshotCache.boxName);
  runApp(DahabyApp(repository: PriceRepository(cache: HiveSnapshotCache(box))));
}

class DahabyApp extends StatelessWidget {
  const DahabyApp({super.key, required this.repository});

  final PriceRepository repository;

  static const _gold = Color(0xFFB8860B);

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => PricesCubit(repository)..start(),
      child: MaterialApp(
        title: 'دهبي',
        debugShowCheckedModeBanner: false,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: _gold),
          cardTheme: const CardThemeData(margin: EdgeInsets.zero),
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: _gold,
            brightness: Brightness.dark,
          ),
          cardTheme: const CardThemeData(margin: EdgeInsets.zero),
        ),
        home: const PricesScreen(),
      ),
    );
  }
}
