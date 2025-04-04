import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Light theme colors
  static const Color _lightPrimaryColor = Color(0xFF0383C2);
  static const Color _lightPrimaryVariantColor = Color(0xFF0078D4);
  static const Color _lightSecondaryColor = Color(0xFF065F89);
  static const Color _lightOnPrimaryColor = Colors.white;
  static const Color _lightBackgroundColor = Colors.white;
  static const Color _lightSurfaceColor = Colors.white;
  static const Color _lightCardColor = Colors.white;
  static const Color _lightIconColor = Color(0xFF0383C2);
  static const Color _lightTextColor = Color(0xFF333333);
  static const Color _lightTextSecondaryColor = Color(0xFF68737D);
  static const Color _lightDividerColor = Color(0xFFE0E0E0);

  // Dark theme colors
  static const Color _darkPrimaryColor = Color(0xFF0383C2);
  static const Color _darkPrimaryVariantColor = Color(0xFF0099DD);
  static const Color _darkSecondaryColor = Color(0xFF90CAF9);
  static const Color _darkOnPrimaryColor = Colors.black;
  static const Color _darkBackgroundColor = Color(0xFF121212);
  static const Color _darkSurfaceColor = Color(0xFF1E1E1E);
  static const Color _darkCardColor = Color(0xFF252525);
  static const Color _darkIconColor = Color(0xFF90CAF9);
  static const Color _darkTextColor = Colors.white;
  static const Color _darkTextSecondaryColor = Color(0xFFB0B0B0);
  static const Color _darkDividerColor = Color(0xFF424242);

  static ThemeData light(BuildContext context) {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: _lightPrimaryColor,
      scaffoldBackgroundColor: _lightBackgroundColor,
      appBarTheme: const AppBarTheme(
        backgroundColor: _lightPrimaryColor,
        foregroundColor: _lightOnPrimaryColor,
        elevation: 0,
      ),
      colorScheme: const ColorScheme.light(
        primary: _lightPrimaryColor,
        primaryContainer: _lightPrimaryVariantColor,
        secondary: _lightSecondaryColor,
        onPrimary: _lightOnPrimaryColor,
        background: _lightBackgroundColor,
        surface: _lightSurfaceColor,
        onBackground: _lightTextColor,
        onSurface: _lightTextColor,
      ),
      cardColor: _lightCardColor,
      cardTheme: CardTheme(
        color: _lightCardColor,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      iconTheme: const IconThemeData(
        color: _lightIconColor,
      ),
      dividerColor: _lightDividerColor,
      textTheme: GoogleFonts.montserratTextTheme(
        Theme.of(context).textTheme,
      ).apply(
        bodyColor: _lightTextColor,
        displayColor: _lightTextColor,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: _lightIconColor,
        textColor: _lightTextColor,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith<Color>((states) {
          if (states.contains(MaterialState.selected)) {
            return _lightPrimaryColor;
          }
          return Colors.grey;
        }),
        trackColor: MaterialStateProperty.resolveWith<Color>((states) {
          if (states.contains(MaterialState.selected)) {
            return _lightPrimaryColor.withOpacity(0.5);
          }
          return Colors.grey.withOpacity(0.5);
        }),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: MaterialStateProperty.resolveWith<Color>((states) {
            if (states.contains(MaterialState.disabled)) {
              return Colors.grey;
            }
            return _lightPrimaryColor;
          }),
          foregroundColor:
              MaterialStateProperty.all<Color>(_lightOnPrimaryColor),
          shape: MaterialStateProperty.all<RoundedRectangleBorder>(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
          ),
        ),
      ),
    );
  }

  static ThemeData dark(BuildContext context) {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: _darkPrimaryColor,
      scaffoldBackgroundColor: _darkBackgroundColor,
      appBarTheme: const AppBarTheme(
        backgroundColor: _darkSurfaceColor,
        foregroundColor: _darkTextColor,
        elevation: 0,
      ),
      colorScheme: const ColorScheme.dark(
        primary: _darkPrimaryColor,
        primaryContainer: _darkPrimaryVariantColor,
        secondary: _darkSecondaryColor,
        onPrimary: _darkOnPrimaryColor,
        background: _darkBackgroundColor,
        surface: _darkSurfaceColor,
        onBackground: _darkTextColor,
        onSurface: _darkTextColor,
      ),
      cardColor: _darkCardColor,
      cardTheme: CardTheme(
        color: _darkCardColor,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      iconTheme: const IconThemeData(
        color: _darkIconColor,
      ),
      dividerColor: _darkDividerColor,
      textTheme: GoogleFonts.montserratTextTheme(
        Theme.of(context).textTheme,
      ).apply(
        bodyColor: _darkTextColor,
        displayColor: _darkTextColor,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: _darkIconColor,
        textColor: _darkTextColor,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith<Color>((states) {
          if (states.contains(MaterialState.selected)) {
            return _darkPrimaryColor;
          }
          return Colors.grey;
        }),
        trackColor: MaterialStateProperty.resolveWith<Color>((states) {
          if (states.contains(MaterialState.selected)) {
            return _darkPrimaryColor.withOpacity(0.5);
          }
          return Colors.grey.withOpacity(0.5);
        }),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: MaterialStateProperty.resolveWith<Color>((states) {
            if (states.contains(MaterialState.disabled)) {
              return Colors.grey;
            }
            return _darkPrimaryColor;
          }),
          foregroundColor:
              MaterialStateProperty.all<Color>(_darkOnPrimaryColor),
          shape: MaterialStateProperty.all<RoundedRectangleBorder>(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
          ),
        ),
      ),
    );
  }
}
