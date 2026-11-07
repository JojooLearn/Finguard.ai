import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../app/di/injection.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../features/auth/presentation/cubit/auth_state.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/calculators/presentation/pages/calculators_page.dart';
import '../../features/coach/presentation/pages/chat_history_page.dart';
import '../../features/consultation/presentation/pages/purchase_consultation_page.dart';
import '../../features/dashboard/presentation/pages/main_scaffold.dart';
import '../../features/goals/presentation/pages/goals_page.dart';
import '../../features/monthly_review/presentation/pages/monthly_review_page.dart';
import '../../features/notifications/presentation/pages/notification_page.dart';
import '../../features/onboarding/presentation/cubit/onboarding_cubit.dart';
import '../../features/onboarding/presentation/pages/onboarding_page.dart';
import '../../features/profile/presentation/pages/blueprint_page.dart';
import '../../features/profile/presentation/pages/edit_profile_page.dart';
import '../../features/splash/presentation/pages/splash_page.dart';
import '../../features/stock_signals/presentation/pages/stock_analysis_page.dart';
import '../../features/walkthrough/presentation/pages/walkthrough_page.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/splash',
  redirect: (BuildContext context, GoRouterState state) async {
    final currentPath = state.uri.path;

    // Splash and Walkthrough handle their own transitions
    if (currentPath == '/splash' || currentPath == '/walkthrough') {
      return null;
    }

    // Public routes that don't require authentication
    const publicRoutes = ['/splash', '/walkthrough', '/login', '/register'];
    final isPublicRoute = publicRoutes.contains(currentPath);

    // Check auth state
    bool isAuthenticated = false;
    try {
      if (sl.isRegistered<AuthRepository>()) {
        final user = sl<AuthRepository>().getCurrentUser();
        isAuthenticated = user != null;
      }
    } catch (_) {}

    if (!isAuthenticated) {
      try {
        final authCubit = context.read<AuthCubit>();
        isAuthenticated = authCubit.state is Authenticated;
      } catch (_) {}
    }

    // If authenticated user tries to access login/register
    if (isAuthenticated && isPublicRoute) {
      if (sl.isRegistered<AuthRepository>()) {
        final authRepo = sl<AuthRepository>();
        if (!authRepo.hasCompletedOnboarding()) {
          final isDone = await authRepo.loadOnboardingStatus();
          if (!isDone) {
            return '/onboarding';
          }
        }
      }
      return '/';
    }

    // If unauthenticated user tries to access protected route, redirect to login
    if (!isAuthenticated && !isPublicRoute) {
      return '/login';
    }

    // If authenticated user has not completed onboarding and is not already on onboarding
    if (isAuthenticated && !isPublicRoute && currentPath != '/onboarding') {
      if (sl.isRegistered<AuthRepository>()) {
        final authRepo = sl<AuthRepository>();
        if (!authRepo.hasCompletedOnboarding()) {
          final isDone = await authRepo.loadOnboardingStatus();
          if (!isDone) {
            return '/onboarding';
          }
        }
      }
    }

    // No redirect needed
    return null;
  },
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const MainScaffold(initialIndex: 0),
    ),
    GoRoute(
      path: '/transactions',
      builder: (context, state) => const MainScaffold(initialIndex: 1),
    ),
    GoRoute(
      path: '/coach',
      builder: (context, state) => const MainScaffold(initialIndex: 2),
    ),
    GoRoute(
      path: '/coach/history',
      builder: (context, state) => const ChatHistoryPage(),
    ),
    GoRoute(
      path: '/budget',
      builder: (context, state) => const MainScaffold(initialIndex: 3),
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const MainScaffold(initialIndex: 4),
    ),
    GoRoute(
      path: '/goals',
      builder: (context, state) => const GoalsPage(),
    ),
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashPage(),
    ),
    GoRoute(
      path: '/walkthrough',
      builder: (context, state) => const WalkthroughPage(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterPage(),
    ),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => BlocProvider<OnboardingCubit>(
        create: (_) => sl<OnboardingCubit>(),
        child: const OnboardingPage(),
      ),
    ),
    GoRoute(
      path: '/consultation',
      builder: (context, state) => const PurchaseConsultationPage(),
    ),
    GoRoute(
      path: '/calculators',
      builder: (context, state) => const CalculatorsPage(),
    ),
    GoRoute(
      path: '/review',
      builder: (context, state) => const MonthlyReviewPage(),
    ),
    GoRoute(
      path: '/profile/edit',
      builder: (context, state) => const EditProfilePage(),
    ),
    GoRoute(
      path: '/blueprint',
      builder: (context, state) => const BlueprintPage(),
    ),
    GoRoute(
      path: '/notifications',
      builder: (context, state) => const NotificationCenterPage(),
    ),
    GoRoute(
      path: '/stock-analysis',
      builder: (context, state) {
        final ticker = state.uri.queryParameters['ticker'];
        return StockAnalysisPage(initialTicker: ticker);
      },
    ),
  ],
);
