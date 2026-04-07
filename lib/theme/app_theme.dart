import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // Glassmorphism color constants
  static const Color glassLight = Color(0x26FFFFFF); // white 15% opacity
  static const Color glassDark = Color(0x26000000); // black 15% opacity
  static const Color glassBorder = Color(0x33FFFFFF); // white 20% opacity

  static Color glassColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? glassDark : glassLight;

  static TextTheme _buildTextTheme(TextTheme base) {
    return base
        .copyWith(
          displayLarge: GoogleFonts.poppins(textStyle: base.displayLarge),
          displayMedium: GoogleFonts.poppins(textStyle: base.displayMedium),
          displaySmall: GoogleFonts.poppins(textStyle: base.displaySmall),
          headlineLarge: GoogleFonts.poppins(textStyle: base.headlineLarge),
          headlineMedium: GoogleFonts.poppins(textStyle: base.headlineMedium),
          headlineSmall: GoogleFonts.poppins(textStyle: base.headlineSmall),
          titleLarge: GoogleFonts.inter(textStyle: base.titleLarge),
          titleMedium: GoogleFonts.inter(textStyle: base.titleMedium),
          titleSmall: GoogleFonts.inter(textStyle: base.titleSmall),
          bodyLarge: GoogleFonts.inter(textStyle: base.bodyLarge),
          bodyMedium: GoogleFonts.inter(textStyle: base.bodyMedium),
          bodySmall: GoogleFonts.inter(textStyle: base.bodySmall),
          labelLarge: GoogleFonts.inter(textStyle: base.labelLarge),
          labelMedium: GoogleFonts.inter(textStyle: base.labelMedium),
          labelSmall: GoogleFonts.inter(textStyle: base.labelSmall),
        );
  }

  static ThemeData light() {
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF2E7D32),
        brightness: Brightness.light,
      ),
      useMaterial3: true,
    );

    return base.copyWith(
      scaffoldBackgroundColor: const Color(0xFFF5F7FA),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      textTheme: _buildTextTheme(base.textTheme),
    );
  }

  static ThemeData dark() {
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF4CAF50),
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
    );

    return base.copyWith(
      scaffoldBackgroundColor: const Color(0xFF0D1117),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      textTheme: _buildTextTheme(base.textTheme),
    );
  }
}
