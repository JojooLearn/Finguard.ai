import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Core Brand Colors (finguard_desig.md Bab 2.1)
  static const Color primary = Color(0xFF6C5DD3); // Ungu FinGuard
  static const Color primaryLight = Color(0xFFE8E6F8);
  static const Color primaryDark = Color(0xFF4B3E99);
  static const Color background = Color(0xFFF8F9FA); // Off-white dasar
  static const Color surface = Color(0xFFFFFFFF); // Pure white cards

  // Surface Tonal Layering
  static const Color surfaceFieldFill = Color(0xFFF1F3F5); // Level 2 Surface / Field Fill
  static const Color surfaceFieldFocus = Color(0xFFE8E6F8); // Focused Field Fill

  // Aliases for backwards compatibility
  static const Color primaryLime = Color(0xFF6C5DD3);
  static const Color surfaceCard = surface;
  static const Color surfaceCardMuted = Color(0xF2FFFFFF);

  // Neutral Grayscale Tokens
  static const Color neutral100 = Color(0xFFF3F4F6);
  static const Color neutral200 = Color(0xFFE5E7EB);
  static const Color neutral300 = Color(0xFFD1D5DB);

  // Semantic Status Colors
  static const Color income = Color(0xFF22C55E); // Success / Green
  static const Color expense = Color(0xFFEF4444); // Danger / Red
  static const Color incomeGreen = income;
  static const Color expenseRed = expense;
  static const Color success = income;
  static const Color danger = expense;
  static const Color error = expense;
  static const Color warning = Color(0xFFF59E0B); // Orange
  static const Color warningOrange = warning;
  static const Color roastRed = Color(0xFFDC2626); // Roast Mode 🔥

  // Semantic Tints
  static const Color successTint = Color(0x1F22C55E);
  static const Color warningTint = Color(0x1FF59E0B);
  static const Color dangerTint = Color(0x1FEF4444);
  static const Color errorTint = dangerTint;
  static const Color primaryTint = Color(0x1F6C5DD3);

  // Typography Colors
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color textDisabled = Color(0xFF9CA3AF);
  static const Color textPlaceholder = Color(0xFF9CA3AF);
  static const Color textLight = Color(0xFFFFFFFF);
  static const Color textLightMuted = Color(0xB3FFFFFF);
  static const Color bgGradientTop = Color(0xFFF8F9FA);
  static const Color bgGradientBottom = Color(0xFFF1F3F5);

  // Design doc Canvas tokens
  static const Color bgCanvasTop = Color(0xFFE8E6F8);
  static const Color bgCanvasMain = Color(0xFFF8F9FA);
  static const Color incomeGreenBg = Color(0xFFDCFCE7);
  static const Color expenseRedBg = Color(0xFFFEE2E2);
  static const Color warningOrangeBg = Color(0xFFFEF3C7);

  // AI Accent Gradient (finguard_desig.md)
  static const LinearGradient aiAccentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6C5DD3), Color(0xFFD946EF)],
  );

  static const LinearGradient screenBackground = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFF8F9FA), Color(0xFFF1F3F5)],
  );

  static const LinearGradient limeCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE8E6F8), Color(0xFFD9D5F7)],
  );

  static const LinearGradient darkCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6C5DD3), Color(0xFF5544BE)],
  );
}
