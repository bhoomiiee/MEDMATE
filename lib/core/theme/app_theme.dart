import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Primary - Delicate Light Pastel Lavender & Lilac
  static const Color primary = Color(0xFFA08CF5);        // Soft, luminous pastel lavender
  static const Color primaryLight = Color(0xFFD8CCFD);   // Pastel lilac blush
  static const Color primaryDark = Color(0xFF846FE0);    // Gentle contrast lilac
  static const Color primarySurface = Color(0xFFF7F4FE); // Airy pastel whisper

  // Soft Pastel Lavender Accents
  static const Color lavenderMist = Color(0xFFFAF8FF);
  static const Color lavenderBlush = Color(0xFFEFE9FE);
  static const Color lavenderDeep = Color(0xFF907BEB);

  // Soft Pastel Periwinkle / Baby Blue (gentle accent)
  static const Color teal = Color(0xFF818CF8);
  static const Color tealLight = Color(0xFFA5B4FC);
  static const Color tealSurface = Color(0xFFEEF2FF);

  // Soft Pastel Sage / Mint Green (taken / healthy / success)
  static const Color secondary = Color(0xFF4ADE80);
  static const Color secondaryLight = Color(0xFF86EFAC);
  static const Color secondarySurface = Color(0xFFF0FDF4);

  // Soft Pastel Orchid / Violet Accent
  static const Color violet = Color(0xFFA855F7);
  static const Color violetLight = Color(0xFFD8B4FE);
  static const Color violetSurface = Color(0xFFFAF5FF);

  // Soft Pastel Peach / Warm Honey (Refill / Warning)
  static const Color warning = Color(0xFFFBBF24);
  static const Color warningSurface = Color(0xFFFFFBEB);

  // Soft Pastel Rose / Blossom Pink (Missed Dose / Alerts)
  static const Color error = Color(0xFFFB7185);
  static const Color errorSurface = Color(0xFFFFF1F2);

  // Neutral - Gentle Luminous Porcelain & Light Pastel Backgrounds
  static const Color background = Color(0xFFFCFAFF);
  static const Color backgroundSecondary = Color(0xFFF6F1FD);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFEBE3F7);
  static const Color borderSubtle = Color(0xFFF5EFFC);
  static const Color divider = Color(0xFFEFE8F7);

  // Text - Soft Deep Plum Charcoal (gentle, high-contrast readable)
  static const Color textPrimary = Color(0xFF2E243E);
  static const Color textSecondary = Color(0xFF726687);
  static const Color textMuted = Color(0xFFA89DBB);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // Dreamy Light Pastel Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF9680F2), Color(0xFFA795F7), Color(0xFFC3B4FC)],
  );

  static const LinearGradient lavenderGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFA08CF5), Color(0xFFC7B9FA)],
  );

  static const LinearGradient tealGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF818CF8), Color(0xFFA5B4FC)],
  );

  static const LinearGradient violetGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFA855F7), Color(0xFFC084FC), Color(0xFFE9D5FF)],
  );

  static const LinearGradient coralGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFB7185), Color(0xFFFDA4AF)],
  );

  static const LinearGradient amberGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFBBF24), Color(0xFFFDE68A)],
  );

  // Soft Ambient Shadows with delicate pastel aura
  static const List<BoxShadow> softShadow = [
    BoxShadow(
      color: Color(0x08422A63),
      blurRadius: 16,
      offset: Offset(0, 4),
      spreadRadius: 0,
    ),
    BoxShadow(
      color: Color(0x04422A63),
      blurRadius: 4,
      offset: Offset(0, 1),
      spreadRadius: 0,
    ),
  ];

  static const List<BoxShadow> elevatedShadow = [
    BoxShadow(
      color: Color(0x0E422A63),
      blurRadius: 20,
      offset: Offset(0, 8),
      spreadRadius: -2,
    ),
    BoxShadow(
      color: Color(0x06422A63),
      blurRadius: 6,
      offset: Offset(0, 2),
      spreadRadius: 0,
    ),
  ];

  static List<BoxShadow> glow(Color c, {double opacity = 0.22, double blur = 14}) => [
    BoxShadow(
      color: c.withValues(alpha: opacity),
      blurRadius: blur,
      offset: const Offset(0, 4),
    ),
  ];

  // Harmonious Pastel Medicine Colors
  static const List<Color> medicineColors = [
    Color(0xFFA08CF5), // Pastel Lavender
    Color(0xFF818CF8), // Pastel Periwinkle
    Color(0xFF4ADE80), // Pastel Mint
    Color(0xFFFBBF24), // Pastel Buttercup
    Color(0xFFFB7185), // Pastel Rose
    Color(0xFFA855F7), // Pastel Lilac
    Color(0xFFF472B6), // Pastel Blossom
    Color(0xFF38BDF8), // Pastel Sky
    Color(0xFFC084FC), // Pastel Orchid
  ];

  // Soft Twilight Pastel (Gentle Dark Mode, never harsh black)
  static const Color darkBackground = Color(0xFF1E182B);
  static const Color darkSurface = Color(0xFF272036);
  static const Color darkSurfaceElevated = Color(0xFF312944);
  static const Color darkBorder = Color(0xFF3D3354);
  static const Color darkTextPrimary = Color(0xFFFAF7FF);
  static const Color darkTextSecondary = Color(0xFFC7BCE0);
}

class AppTheme {
  static ThemeData get lightTheme {
    final textTheme = GoogleFonts.plusJakartaSansTextTheme().copyWith(
      displayLarge: GoogleFonts.plusJakartaSans(
          fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.5),
      displayMedium: GoogleFonts.plusJakartaSans(
          fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: -0.5),
      headlineLarge: GoogleFonts.plusJakartaSans(
          fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: -0.3),
      headlineMedium: GoogleFonts.plusJakartaSans(
          fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: -0.2),
      headlineSmall: GoogleFonts.plusJakartaSans(
          fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
      titleLarge: GoogleFonts.plusJakartaSans(
          fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
      titleMedium: GoogleFonts.plusJakartaSans(
          fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
      titleSmall: GoogleFonts.plusJakartaSans(
          fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
      bodyLarge: GoogleFonts.plusJakartaSans(
          fontSize: 15, fontWeight: FontWeight.w400, color: AppColors.textPrimary, height: 1.4),
      bodyMedium: GoogleFonts.plusJakartaSans(
          fontSize: 13, fontWeight: FontWeight.w400, color: AppColors.textPrimary, height: 1.4),
      bodySmall: GoogleFonts.plusJakartaSans(
          fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.textSecondary),
      labelLarge: GoogleFonts.plusJakartaSans(
          fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.surface,
        error: AppColors.error,
      ),
      scaffoldBackgroundColor: AppColors.background,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: -0.2),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textOnPrimary,
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
          shadowColor: AppColors.primary.withValues(alpha: 0.22),
          textStyle: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryDark,
          minimumSize: const Size(double.infinity, 54),
          side: const BorderSide(color: AppColors.border, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryDark,
          textStyle: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        hintStyle: GoogleFonts.plusJakartaSans(
            fontSize: 14, color: AppColors.textMuted, fontWeight: FontWeight.w400),
        labelStyle: GoogleFonts.plusJakartaSans(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.borderSubtle),
        ),
        margin: EdgeInsets.zero,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.primarySurface,
        labelStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.primaryDark, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        selectedItemColor: AppColors.primaryDark,
        unselectedItemColor: AppColors.textMuted,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        space: 1,
        thickness: 1,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: StadiumBorder(),
      ),
    );
  }

  static ThemeData get darkTheme {
    final textTheme = GoogleFonts.plusJakartaSansTextTheme(ThemeData.dark().textTheme);
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.dark,
        primary: AppColors.primaryLight,
        secondary: AppColors.secondary,
        surface: AppColors.darkSurface,
        error: AppColors.error,
      ),
      scaffoldBackgroundColor: AppColors.darkBackground,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.darkBackground,
        foregroundColor: AppColors.darkTextPrimary,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.darkTextPrimary),
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.darkTextPrimary),
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.darkBorder),
        ),
        margin: EdgeInsets.zero,
      ),
    );
  }
}
