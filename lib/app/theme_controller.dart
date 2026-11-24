import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';


// ---------------- ThemeController ----------------
class ThemeController {
  static final ValueNotifier<ThemeMode> themeMode =
      ValueNotifier(ThemeMode.light);

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('dark_mode') ?? false;
    themeMode.value = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  static Future<void> toggle() async {
    final prefs = await SharedPreferences.getInstance();
    final isCurrentlyDark = themeMode.value == ThemeMode.dark;
    themeMode.value = isCurrentlyDark ? ThemeMode.light : ThemeMode.dark;
    await prefs.setBool('dark_mode', !isCurrentlyDark);
  }
}
