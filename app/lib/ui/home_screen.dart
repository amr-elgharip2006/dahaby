import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../logic/history_cubit.dart';
import 'calculator_screen.dart';
import 'chart_screen.dart';
import 'portfolio_screen.dart';
import 'prices_screen.dart';

/// The four tabs of the app.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _chartTab = 2;
  int _index = 0;
  bool _chartLoaded = false;

  void _select(int index) {
    setState(() => _index = index);
    // The chart needs a network call, so it loads the first time it is opened.
    if (index == _chartTab && !_chartLoaded) {
      _chartLoaded = true;
      context.read<HistoryCubit>().load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          PricesScreen(),
          PortfolioScreen(),
          ChartScreen(),
          CalculatorScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _select,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.show_chart), label: 'الأسعار'),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'محفظتي',
          ),
          NavigationDestination(
            icon: Icon(Icons.area_chart_outlined),
            selectedIcon: Icon(Icons.area_chart),
            label: 'الرسم',
          ),
          NavigationDestination(
            icon: Icon(Icons.calculate_outlined),
            selectedIcon: Icon(Icons.calculate),
            label: 'الحاسبة',
          ),
        ],
      ),
    );
  }
}
