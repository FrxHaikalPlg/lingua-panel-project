import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// LinguaPanel Design System
/// Premium manga-inspired color palette with modern aesthetics.
class AppThemes {
  AppThemes._();

  // ── Brand Colors ──
  static const Color _primaryLight = Color(0xFF6366F1);  // Indigo-500
  static const Color _primaryDark = Color(0xFF818CF8);   // Indigo-400
  static const Color _accent = Color(0xFFF472B6);        // Pink-400
  static const Color _success = Color(0xFF34D399);       // Emerald-400
  static const Color _warning = Color(0xFFFBBF24);       // Amber-400
  static const Color _error = Color(0xFFF87171);         // Red-400

  // ── Surface Colors ──
  static const Color _surfaceLight = Color(0xFFF8FAFC);    // Slate-50
  static const Color _surfaceDark = Color(0xFF0F172A);     // Slate-900
  static const Color _cardLight = Color(0xFFFFFFFF);
  static const Color _cardDark = Color(0xFF1E293B);        // Slate-800
  static const Color _elevatedDark = Color(0xFF334155);    // Slate-700

  // ── Shared Config ──
  static const double _borderRadius = 14.0;
  static const double _buttonRadius = 12.0;

  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.light(
      primary: _primaryLight,
      onPrimary: Colors.white,
      secondary: _accent,
      onSecondary: Colors.white,
      surface: _surfaceLight,
      onSurface: const Color(0xFF1E293B),
      error: _error,
      onError: Colors.white,
      surfaceContainerHighest: _cardLight,
    ),
    scaffoldBackgroundColor: _surfaceLight,
    appBarTheme: const AppBarTheme(
      backgroundColor: _primaryLight,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      titleTextStyle: TextStyle(
        fontFamily: 'Roboto',
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        color: Colors.white,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_borderRadius),
      ),
      color: _cardLight,
      surfaceTintColor: Colors.transparent,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 52),
        backgroundColor: _primaryLight,
        foregroundColor: Colors.white,
        elevation: 2,
        shadowColor: _primaryLight.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_buttonRadius),
        ),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return _primaryLight;
          }
          return Colors.transparent;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return _primaryLight;
        }),
        side: WidgetStateProperty.all(
          const BorderSide(color: _primaryLight, width: 1.5),
        ),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_buttonRadius),
          ),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF1F5F9), // Slate-100
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(_buttonRadius),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: _primaryLight, width: 2),
        borderRadius: BorderRadius.circular(_buttonRadius),
      ),
      errorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: _error),
        borderRadius: BorderRadius.circular(_buttonRadius),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: _error, width: 2),
        borderRadius: BorderRadius.circular(_buttonRadius),
      ),
      hintStyle: TextStyle(color: Colors.grey[500]),
      labelStyle: const TextStyle(fontWeight: FontWeight.w500),
    ),
    dropdownMenuTheme: const DropdownMenuThemeData(
      textStyle: TextStyle(fontSize: 14),
    ),
    dividerTheme: DividerThemeData(
      color: Colors.grey.shade200,
      thickness: 1,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
    iconTheme: const IconThemeData(
      color: _primaryLight,
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.5),
      headlineMedium: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.5),
      titleLarge: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.15),
      titleMedium: TextStyle(fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(fontWeight: FontWeight.w400),
      bodyMedium: TextStyle(fontWeight: FontWeight.w400),
      labelLarge: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.5),
    ),
  );

  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.dark(
      primary: _primaryDark,
      onPrimary: const Color(0xFF1E1B4B),
      secondary: _accent,
      onSecondary: Colors.white,
      surface: _surfaceDark,
      onSurface: const Color(0xFFE2E8F0),
      error: _error,
      onError: Colors.white,
      surfaceContainerHighest: _cardDark,
    ),
    scaffoldBackgroundColor: _surfaceDark,
    appBarTheme: AppBarTheme(
      backgroundColor: _cardDark,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: const TextStyle(
        fontFamily: 'Roboto',
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        color: Colors.white,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_borderRadius),
      ),
      color: _cardDark,
      surfaceTintColor: Colors.transparent,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 52),
        backgroundColor: _primaryDark,
        foregroundColor: const Color(0xFF1E1B4B),
        elevation: 4,
        shadowColor: _primaryDark.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_buttonRadius),
        ),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return _primaryDark;
          }
          return Colors.transparent;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const Color(0xFF1E1B4B);
          }
          return _primaryDark;
        }),
        side: WidgetStateProperty.all(
          BorderSide(color: _primaryDark.withValues(alpha: 0.5), width: 1.5),
        ),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_buttonRadius),
          ),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _elevatedDark,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.grey.shade700),
        borderRadius: BorderRadius.circular(_buttonRadius),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: _primaryDark, width: 2),
        borderRadius: BorderRadius.circular(_buttonRadius),
      ),
      errorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: _error),
        borderRadius: BorderRadius.circular(_buttonRadius),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: _error, width: 2),
        borderRadius: BorderRadius.circular(_buttonRadius),
      ),
      hintStyle: TextStyle(color: Colors.grey[500]),
      labelStyle: const TextStyle(fontWeight: FontWeight.w500),
    ),
    dividerTheme: DividerThemeData(
      color: Colors.grey.shade800,
      thickness: 1,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: _cardDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: _cardDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: _cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
    iconTheme: const IconThemeData(
      color: _primaryDark,
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.5),
      headlineMedium: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.5),
      titleLarge: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.15),
      titleMedium: TextStyle(fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(fontWeight: FontWeight.w400),
      bodyMedium: TextStyle(fontWeight: FontWeight.w400),
      labelLarge: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.5),
    ),
  );

  /// Convenience getters for custom colors not in ColorScheme.
  static Color success(BuildContext context) => _success;
  static Color warning(BuildContext context) => _warning;
  static Color accent(BuildContext context) => _accent;
}
