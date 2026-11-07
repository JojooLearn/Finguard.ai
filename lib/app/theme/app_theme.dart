import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'app_typography.dart';
import 'app_spacing.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.bgGradientBottom,
      fontFamily: GoogleFonts.urbanist().fontFamily,
      textTheme: GoogleFonts.urbanistTextTheme(
        ThemeData.light().textTheme.apply(
          bodyColor: AppColors.textPrimary,
          displayColor: AppColors.textPrimary,
        ),
      ),
      colorScheme: const ColorScheme.light(
        primary: AppColors.primaryDark,
        secondary: AppColors.primaryLime,
        surface: AppColors.surfaceCard,
        error: AppColors.danger,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarBrightness: Brightness.light,
          statusBarIconBrightness: Brightness.dark,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: AppColors.primaryDark,
          foregroundColor: AppColors.surfaceCard,
          minimumSize: const Size.fromHeight(AppSpacing.buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
          ),
          textStyle: AppTypography.sectionLabel.copyWith(
            color: AppColors.surfaceCard,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        ),
        margin: EdgeInsets.zero,
      ),
    );
  }
}
