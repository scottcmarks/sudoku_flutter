import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const Color bg            = Color(0xFFF5F0E8); // warm parchment
  static const Color gridLine      = Color(0xFF8B7355);
  static const Color groupBorder   = Color(0xFF4A3728);
  static const Color clueText      = Color(0xFF1A0A00);
  static const Color userText      = Color(0xFF1A4A8A);
  static const Color errorText     = Color(0xFFCC2200);
  static const Color pencilText    = Color(0xFF5A7A9A);
  static const Color selectedCell  = Color(0xFFD4E8FF);
  static const Color neighborCell  = Color(0xFFEAF2FF);
  static const Color sameDigitCell = Color(0xFFFFEAD4);
  static const Color clueCell      = Color(0xFFE8E0D0);
  static const Color keypadBg      = Color(0xFFDDD5C5);
  static const Color keypadPress   = Color(0xFF8B7355);
  static const Color winGold       = Color(0xFFFFC200);

  // 4-color map palette for irregular group backgrounds
  static const List<Color> groupColors = [
    Color(0xFFBED4EC), // 0 = cornflower blue
    Color(0xFFB8D4B4), // 1 = sage green
    Color(0xFFEABCBC), // 2 = salmon pink
    Color(0xFFE0D09C), // 3 = golden wheat
  ];

  static ThemeData get theme => ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF8B7355),
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: bg,
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF4A3728),
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF4A3728),
        foregroundColor: Colors.white,
      ),
    ),
    useMaterial3: true,
  );
}
