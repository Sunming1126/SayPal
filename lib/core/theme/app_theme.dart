import 'package:flutter/material.dart';

/// SayPal 儿童友好的高对比配色。
/// 玻璃只属于导航与控制层；正文卡片、图表与长文本必须使用这里的不透明表面。
abstract final class AppColors {
  static const Color primary = Color(0xFF3B6EF6);
  static const Color primaryDark = Color(0xFF2B4FC4);
  static const Color primarySoft = Color(0xFFEAF0FF);
  static const Color mint = Color(0xFFDDF4E4);
  static const Color mintStrong = Color(0xFF2F9E68);
  static const Color sun = Color(0xFFFFD66B);
  static const Color sunSoft = Color(0xFFFFF3C9);
  static const Color coral = Color(0xFFFF8A5B);
  static const Color coralSoft = Color(0xFFFFE7DD);
  static const Color lavender = Color(0xFFE9E3FF);
  static const Color accent = coral;
  static const Color success = Color(0xFF2FA36B);
  static const Color warning = Color(0xFFD98A00);
  static const Color danger = Color(0xFFD64545);

  static const Color background = Color(0xFFFFF9ED);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF5F7FC);

  static const Color textPrimary = Color(0xFF1C2333);
  static const Color textSecondary = Color(0xFF5B6472);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  static const Color bubbleAi = Color(0xFFFFFFFF);
  static const Color bubbleChild = Color(0xFF3B6EF6);
  static const Color outline = Color(0xFFE2E6F0);
  static const Color warmOutline = Color(0xFFF0E7D7);

  static const List<BoxShadow> softShadow = <BoxShadow>[
    BoxShadow(
      color: Color(0x142A3550),
      blurRadius: 20,
      offset: Offset(0, 8),
    ),
  ];
}

/// 应用主题：明亮、大字号、大触控区，适合小学阶段儿童。
ThemeData buildSayPalTheme() {
  final ColorScheme scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    primary: AppColors.primary,
    secondary: AppColors.accent,
    surface: AppColors.surface,
    error: AppColors.danger,
  );

  final ThemeData base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
  );

  return base.copyWith(
    textTheme: base.textTheme
        .apply(
          bodyColor: AppColors.textPrimary,
          displayColor: AppColors.textPrimary,
        )
        .copyWith(
          headlineSmall: const TextStyle(
            fontSize: 24,
            height: 1.2,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
          ),
          titleLarge: const TextStyle(
            fontSize: 20,
            height: 1.25,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
          bodyLarge: const TextStyle(
            fontSize: 16,
            height: 1.5,
            color: AppColors.textPrimary,
          ),
        ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: const CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(24)),
        side: BorderSide(color: AppColors.warmOutline),
      ),
      margin: EdgeInsets.zero,
    ),
    dividerTheme:
        const DividerThemeData(color: AppColors.outline, thickness: 1),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.textPrimary,
      contentTextStyle: TextStyle(color: Colors.white, fontSize: 15),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppColors.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppColors.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.primarySoft,
      height: 72,
    ),
  );
}
