import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../logic/settings_cubit.dart';

/// Switches between light and dark mode.
class ThemeToggle extends StatelessWidget {
  const ThemeToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<SettingsCubit?>();
    if (cubit == null) return const SizedBox.shrink();
    final dark = cubit.state == ThemeMode.dark;
    return IconButton(
      tooltip: dark ? 'الوضع الفاتح' : 'الوضع الغامق',
      onPressed: cubit.toggle,
      icon: Icon(dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
    );
  }
}
