import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'di/injection.dart';
import 'router/app_router.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';
import '../features/auth/presentation/cubit/auth_cubit.dart';
import '../features/auth/presentation/cubit/auth_state.dart';
import '../features/budgets/presentation/cubit/budget_cubit.dart';
import '../features/coach/presentation/cubit/coach_cubit.dart';
import '../features/goals/presentation/cubit/goal_cubit.dart';
import '../features/profile/presentation/cubit/profile_cubit.dart';
import '../features/profile/presentation/cubit/user_preferences_cubit.dart';
import '../features/stock_signals/presentation/cubit/stock_signal_list_cubit.dart';
import '../features/transactions/presentation/cubit/transaction_cubit.dart';

class FinGuardApp extends StatelessWidget {
  const FinGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthCubit>(
          create: (_) => sl<AuthCubit>(),
        ),
        BlocProvider<TransactionCubit>(
          create: (_) => sl<TransactionCubit>()..loadTransactions(),
        ),
        BlocProvider<BudgetCubit>(
          create: (_) => sl<BudgetCubit>()..loadBudgets(),
        ),
        BlocProvider<GoalCubit>(
          create: (_) => sl<GoalCubit>()..loadGoals(),
        ),
        BlocProvider<CoachCubit>(
          create: (_) => sl<CoachCubit>(),
        ),
        BlocProvider<ProfileCubit>(
          create: (_) => sl<ProfileCubit>()..loadProfile(),
        ),
        BlocProvider<UserPreferencesCubit>(
          create: (_) => sl<UserPreferencesCubit>()..loadPreferences(),
        ),
        BlocProvider<StockSignalListCubit>(
          create: (_) => sl<StockSignalListCubit>()..loadSignals(),
        ),
      ],
      child: BlocListener<AuthCubit, AuthState>(
        listener: (context, authState) {
          if (authState is Unauthenticated) {
            context.read<CoachCubit>().reset();
            context.read<ProfileCubit>().reset();
            context.read<TransactionCubit>().reset();
            context.read<BudgetCubit>().reset();
            context.read<GoalCubit>().reset();
          } else if (authState is Authenticated) {
            context.read<CoachCubit>().reset();
            context.read<CoachCubit>().loadChatHistory();
            context.read<ProfileCubit>().loadProfile();
            context.read<TransactionCubit>().loadTransactions();
            context.read<BudgetCubit>().loadBudgets();
            context.read<GoalCubit>().loadGoals();
            context.read<UserPreferencesCubit>().loadPreferences();
          }
        },
        child: MaterialApp.router(
          title: 'FinGuard',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.theme,
          routerConfig: appRouter,
          builder: (context, child) {
            return Container(
              color: const Color(0xFFD8DCC8), // Background for wide screens
              alignment: Alignment.center,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: AppColors.screenBackground,
                  ),
                  child: ClipRect(
                    child: child ?? const SizedBox.shrink(),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

