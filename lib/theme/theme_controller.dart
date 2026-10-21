import 'package:flutter/material.dart';
import '../models/app_settings.dart';
import '../services/settings_service.dart';
import 'app_theme.dart';

// Holds the current theme settings. The app listens to it, so changing a
// colour in Settings restyles the whole app straight away.
class ThemeController extends ChangeNotifier {
  ThemeController._();
  static final ThemeController instance = ThemeController._();

  AppSettings _settings = AppSettings();

  Future<void> load() async {
    _settings = await SettingsService.load();
    notifyListeners();
  }

  void apply(AppSettings settings) {
    _settings = settings;
    notifyListeners(); // tells the app to redraw
  }

  ThemeMode get mode {
    switch (_settings.themeMode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  ThemeData get light => buildTheme(_settings, Brightness.light);
  ThemeData get dark => buildTheme(_settings, Brightness.dark);
}