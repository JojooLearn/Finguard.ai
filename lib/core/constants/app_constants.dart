class AppConstants {
  AppConstants._();

  // Storage Keys
  static const String sessionKey = 'finguard_session';
  static const String onboardingCompletedKey = 'onboarding_completed';

  // Strictness Levels
  static const int defaultStrictness = 3;
  static const int minStrictness = 1;
  static const int maxStrictness = 5;

  // Thresholds
  static const double budgetWarningThreshold = 0.70; // 70% (Perhatian)
  static const double budgetDangerThreshold = 0.90;  // 90% (Hampir Habis)
  static const double budgetExceededThreshold = 1.00; // 100% (Melebihi)
}
