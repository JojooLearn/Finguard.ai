import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../app/di/injection.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../auth/domain/repositories/auth_repository.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _handleNavigation();
  }

  Future<void> _handleNavigation() async {
    // Play splash animation for at least 2.2 seconds
    await Future.delayed(const Duration(milliseconds: 2200));
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final hasSeenWalkthrough = prefs.getBool('has_seen_walkthrough') ?? false;

    if (!hasSeenWalkthrough) {
      if (mounted) context.go('/walkthrough');
      return;
    }

    // Check authentication
    bool isAuthenticated = false;
    try {
      if (sl.isRegistered<AuthRepository>()) {
        final user = sl<AuthRepository>().getCurrentUser();
        isAuthenticated = user != null;
      }
    } catch (_) {}

    if (!mounted) return;

    if (isAuthenticated) {
      if (sl.isRegistered<AuthRepository>()) {
        final authRepo = sl<AuthRepository>();
        final isDone = await authRepo.loadOnboardingStatus();
        if (!mounted) return;
        if (!isDone) {
          context.go('/onboarding');
          return;
        }
      }
      context.go('/');
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgGradientBottom,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppColors.screenBackground,
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              // Lottie Splash Animation (scr01_splash_initial_loading.json)
              SizedBox(
                width: 220,
                height: 220,
                child: Lottie.asset(
                  'assets/animations/scr01_splash_initial_loading.json',
                  fit: BoxFit.contain,
                  repeat: false,
                ),
              ),
              const SizedBox(height: 24),
              // App Title & Tagline
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      'assets/icons/app_logo.png',
                      width: 32,
                      height: 32,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'FinGuard',
                    style: AppTypography.screenTitle.copyWith(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'AI Financial Coach Tongkrongan',
                style: AppTypography.caption.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              // Subtle Loading indicator / version
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Text(
                  'v1.0 • Navigasi Keuangan Cerdas',
                  style: AppTypography.smallCaption.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
