import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService extends ChangeNotifier {
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal();

  String _currentTheme = 'default';

  // Liste des thèmes disponibles
  static const Map<String, Color> themeColors = {
    'default': Color(0xFFB71C1C), // Rouge actuel
    'pink': Color(0xFFE91E63), // Rose
    'blue': Color(0xFF2196F3), // Bleu
    'green': Color(0xFF4CAF50), // Vert
    'purple': Color(0xFF9C27B0), // Violet
    'orange': Color(0xFFFF9800), // Orange
  };

  static const Map<String, String> themeNames = {
    'default': 'Rouge (Par défaut)',
    'pink': 'Rose',
    'blue': 'Bleu',
    'green': 'Vert',
    'purple': 'Violet',
    'orange': 'Orange',
  };

  String get currentTheme => _currentTheme;
  Color get primaryColor =>
      themeColors[_currentTheme] ?? themeColors['default']!;
  String get themeDisplayName =>
      themeNames[_currentTheme] ?? themeNames['default']!;

  // Charger le thème sauvegardé
  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _currentTheme = prefs.getString('selected_theme') ?? 'default';
    notifyListeners();
  }

  // Changer le thème
  Future<void> setTheme(String themeName) async {
    if (themeColors.containsKey(themeName)) {
      _currentTheme = themeName;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_theme', themeName);
      notifyListeners();
    }
  }

  // Obtenir le thème Material
  ThemeData getTheme() {
    return ThemeData(
      primarySwatch: _createMaterialColor(primaryColor),
      primaryColor: primaryColor,
      scaffoldBackgroundColor: const Color(0xFF18191A),
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.dark,
        background: const Color(0xFF18191A),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        selectedItemColor: primaryColor,
        unselectedItemColor: Colors.grey,
      ),
    );
  }

  // Créer une MaterialColor à partir d'une couleur
  MaterialColor _createMaterialColor(Color color) {
    List<double> strengths = <double>[.05];
    Map<int, Color> swatch = {};
    final int r = color.red, g = color.green, b = color.blue;

    for (int i = 1; i < 10; i++) {
      strengths.add(0.1 * i);
    }
    for (var strength in strengths) {
      final double ds = 0.5 - strength;
      swatch[(strength * 1000).round()] = Color.fromRGBO(
        r + ((ds < 0 ? r : (255 - r)) * ds).round(),
        g + ((ds < 0 ? g : (255 - g)) * ds).round(),
        b + ((ds < 0 ? b : (255 - b)) * ds).round(),
        1,
      );
    }
    return MaterialColor(color.value, swatch);
  }
}
