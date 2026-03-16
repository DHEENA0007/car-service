import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Common Colors
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);
  static const Color critical = Color(0xFF991B1B);

  // Light Theme Palette
  static const Color lPrimary = Color(0xFF8B5CF6); // Violet
  static const Color lPrimaryDark = Color(0xFF6D28D9); // Darker Violet
  static const Color lPrimaryLight = Color(0xFFFDF2F8); // Very Light Pink
  static const Color lAccent = Color(0xFFF472B6); // Pink
  static const Color lScaffoldBg = Color(0xFFFFF7F9); // Light Pinkish White
  static const Color lCardBg = Colors.white;
  static const Color lSurfaceBg = Color(0xFFFCE7F3); // Light Pink Surface
  static const Color lInputBg = Color(0xFFFDF2F8); // Lightest Pink Input
  static const Color lTextPrimary = Color(0xFF1E1B4B); // Dark Violet/Blue Text
  static const Color lTextSecondary = Color(0xFF4C1D95); // Violet Text
  static const Color lTextMuted = Color(0xFF9D7BB0); // Muted Violet

  // Dark Theme Palette
  static const Color dPrimary = Color(0xFF8B5CF6);
  static const Color dScaffoldBg = Color(0xFF0F172A);
  static const Color dCardBg = Color(0xFF1E293B);
  static const Color dSurfaceBg = Color(0xFF334155);
  static const Color dInputBg = Color(0xFF0F172A);
  static const Color dTextPrimary = Color(0xFFF8FAFC);
  static const Color dTextSecondary = Color(0xFFCBD5E1);
  static const Color dTextMuted = Color(0xFF64748B);

  // Static Fields (Defaulting to Light Mode for compatibility with const constructors)
  static const Color primaryColor = lPrimary;
  static const Color primaryDark = lPrimaryDark;
  static const Color primaryLight = lPrimaryLight;
  static const Color accentColor = lAccent;
  
  static const Color scaffoldBg = lScaffoldBg;
  static const Color cardBg = lCardBg;
  static const Color surfaceBg = lSurfaceBg;
  static const Color inputBg = lInputBg;

  static const Color textPrimary = lTextPrimary;
  static const Color textSecondary = lTextSecondary;
  static const Color textMuted = lTextMuted;

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF8B5CF6), Color(0xFFF472B6)], // Violet to Pink
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient lightGradient = LinearGradient(
    colors: [Color(0xFFFFF7F9), Color(0xFFFCE7F3)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient darkGradient = LinearGradient(
    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Colors.white, Color(0xFFFCE7F3)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Border Radius
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 24.0;
  static const double radiusRound = 50.0;

  // Shadows
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 20,
          offset: const Offset(0, 10),
        ),
      ];

  static List<BoxShadow> get glowShadow => [
        BoxShadow(
          color: lPrimary.withValues(alpha: 0.2),
          blurRadius: 30,
          offset: const Offset(0, 10),
        ),
      ];

  // Theme Data - LIGHT
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lScaffoldBg,
      primaryColor: lPrimary,
      colorScheme: ColorScheme.light(
        primary: lPrimary,
        secondary: lAccent,
        surface: lCardBg,
        onSurface: lTextPrimary,
        error: error,
      ),
      textTheme: GoogleFonts.outfitTextTheme(
        const TextTheme(
          displayLarge: TextStyle(color: lTextPrimary, fontWeight: FontWeight.bold),
          displayMedium: TextStyle(color: lTextPrimary, fontWeight: FontWeight.bold),
          headlineLarge: TextStyle(color: lTextPrimary, fontWeight: FontWeight.w700),
          headlineMedium: TextStyle(color: lTextPrimary, fontWeight: FontWeight.w600),
          titleLarge: TextStyle(color: lTextPrimary, fontWeight: FontWeight.w600),
          titleMedium: TextStyle(color: lTextPrimary, fontWeight: FontWeight.w500),
          bodyLarge: TextStyle(color: lTextSecondary),
          bodyMedium: TextStyle(color: lTextSecondary),
          labelLarge: TextStyle(color: lTextPrimary, fontWeight: FontWeight.w600),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: lScaffoldBg,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: lTextPrimary,
        ),
        iconTheme: const IconThemeData(color: lTextPrimary),
      ),
      cardTheme: CardThemeData(
        color: lCardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: BorderSide(color: lSurfaceBg.withValues(alpha: 0.5)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: lPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lInputBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: lSurfaceBg),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: lPrimary, width: 2),
        ),
        hintStyle: const TextStyle(color: lTextMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  // Theme Data - DARK
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: dScaffoldBg,
      primaryColor: dPrimary,
      colorScheme: ColorScheme.dark(
        primary: dPrimary,
        secondary: lAccent,
        surface: dCardBg,
        onSurface: dTextPrimary,
        error: error,
      ),
      textTheme: GoogleFonts.outfitTextTheme(
        const TextTheme(
          displayLarge: TextStyle(color: dTextPrimary, fontWeight: FontWeight.bold),
          displayMedium: TextStyle(color: dTextPrimary, fontWeight: FontWeight.bold),
          headlineLarge: TextStyle(color: dTextPrimary, fontWeight: FontWeight.w700),
          headlineMedium: TextStyle(color: dTextPrimary, fontWeight: FontWeight.w600),
          titleLarge: TextStyle(color: dTextPrimary, fontWeight: FontWeight.w600),
          titleMedium: TextStyle(color: dTextPrimary, fontWeight: FontWeight.w500),
          bodyLarge: TextStyle(color: dTextSecondary),
          bodyMedium: TextStyle(color: dTextSecondary),
          labelLarge: TextStyle(color: dTextPrimary, fontWeight: FontWeight.w600),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: dScaffoldBg,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: dTextPrimary,
        ),
        iconTheme: const IconThemeData(color: dTextPrimary),
      ),
      cardTheme: CardThemeData(
        color: dCardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: dPrimary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dInputBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: dSurfaceBg.withValues(alpha: 0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: dPrimary, width: 2),
        ),
        hintStyle: const TextStyle(color: dTextMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  // Urgency Colors
  static Color getUrgencyColor(String urgency) {
    switch (urgency.toLowerCase()) {
      case 'low':
        return success;
      case 'medium':
        return warning;
      case 'high':
        return error;
      case 'critical':
        return critical;
      default:
        return info;
    }
  }

  static String getUrgencyText(String urgency) {
    switch (urgency.toLowerCase()) {
      case 'low':
        return 'Low Priority';
      case 'medium':
        return 'Medium Priority';
      case 'high':
        return 'High Priority';
      case 'critical':
        return 'Critical - Immediate Action';
      default:
        return urgency;
    }
  }

  static IconData getUrgencyIcon(String urgency) {
    switch (urgency.toLowerCase()) {
      case 'low':
        return Icons.check_circle;
      case 'medium':
        return Icons.warning_amber;
      case 'high':
        return Icons.error;
      case 'critical':
        return Icons.dangerous;
      default:
        return Icons.info;
    }
  }
}

