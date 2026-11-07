import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTypography {
  AppTypography._();

  // Hierarchy as defined in finguard_design.md Bab 2.2
  static TextStyle get h1 => GoogleFonts.urbanist(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: -0.5,
      );

  static TextStyle get h2 => GoogleFonts.urbanist(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        letterSpacing: -0.3,
      );

  static TextStyle get h3 => GoogleFonts.urbanist(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      );

  static TextStyle get bigNumber => GoogleFonts.urbanist(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
        letterSpacing: -0.5,
      );

  static TextStyle get bigNumberLight => GoogleFonts.urbanist(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: AppColors.textLight,
        letterSpacing: -0.5,
      );

  static TextStyle get screenTitle => GoogleFonts.urbanist(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: -0.3,
      );

  static TextStyle get sectionLabel => h3;

  // Design.md Aliases
  static TextStyle get displayBalance => bigNumber;
  static TextStyle get pageHeader => screenTitle;
  static TextStyle get sectionTitle => h2;
  static TextStyle get itemTitle => h3;
  static TextStyle get bodyText => body;
  static TextStyle get inputLabel => buttonSmall;
  static TextStyle get captionText => caption;

  static TextStyle get body => GoogleFonts.urbanist(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
        height: 1.45,
      );

  static TextStyle get bodySecondary => GoogleFonts.urbanist(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
        height: 1.45,
      );

  static TextStyle get caption => GoogleFonts.urbanist(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
      );

  static TextStyle get smallCaption => GoogleFonts.urbanist(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
      );

  static TextStyle get cardValue => GoogleFonts.urbanist(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      );

  static TextStyle get captionLight => GoogleFonts.urbanist(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.textLightMuted,
      );

  static TextStyle get button => GoogleFonts.urbanist(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      );

  static TextStyle get buttonSmall => GoogleFonts.urbanist(
        fontSize: 13,
        fontWeight: FontWeight.w600,
      );
}
