import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class ThemeViewModel with ChangeNotifier {
  static const String _themeBox = 'themeBox';
  static const String _themeModeKey = 'themeMode';

  late Box<String> _box;
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  ThemeViewModel();

  Future<void> init() async {
    _box = await Hive.openBox<String>(_themeBox);
    final theme = _box.get(_themeModeKey);
    switch (theme) {
      case 'light':
        _themeMode = ThemeMode.light;
        break;
      case 'dark':
        _themeMode = ThemeMode.dark;
        break;
      default:
        _themeMode = ThemeMode.system;
        break;
    }
  }

  Future<void> setTheme(ThemeMode themeMode) async {
    _themeMode = themeMode;
    if (!_box.isOpen) {
      _box = await Hive.openBox<String>(_themeBox);
    }
    await _box.put(_themeModeKey, themeMode.name);
    notifyListeners();
  }
}
