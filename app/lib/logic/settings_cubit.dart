import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive/hive.dart';

/// Remembers the user's choices between sessions.
abstract class SettingsStore {
  String? read(String key);
  Future<void> write(String key, String value);
}

class HiveSettingsStore implements SettingsStore {
  HiveSettingsStore(this._box);

  static const boxName = 'settings';
  final Box<String> _box;

  @override
  String? read(String key) => _box.get(key);

  @override
  Future<void> write(String key, String value) => _box.put(key, value);
}

/// Light or dark mode. The app opens in light mode until the user changes it.
class SettingsCubit extends Cubit<ThemeMode> {
  SettingsCubit(this._store) : super(_parse(_store.read(_key)));

  static const _key = 'themeMode';
  final SettingsStore _store;

  static ThemeMode _parse(String? saved) =>
      saved == ThemeMode.dark.name ? ThemeMode.dark : ThemeMode.light;

  void toggle() {
    final next = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    _store.write(_key, next.name);
    emit(next);
  }
}
