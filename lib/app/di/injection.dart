import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/network/connectivity_service.dart';
import '../../core/services/push_notification_service.dart';
import '../../features/auth/data/datasources/auth_remote_data_source.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../features/transactions/data/datasources/transaction_remote_data_source.dart';
import '../../features/transactions/data/repositories/category_and_account_repository_impl.dart';
import '../../features/transactions/data/repositories/transaction_repository_impl.dart';
import '../../features/transactions/domain/repositories/category_and_account_repository.dart';
import '../../features/transactions/domain/repositories/transaction_repository.dart';
import '../../features/transactions/presentation/cubit/transaction_cubit.dart';
import '../../features/budgets/data/repositories/budget_repository_impl.dart';
import '../../features/budgets/domain/repositories/budget_repository.dart';
import '../../features/budgets/presentation/cubit/budget_cubit.dart';
import '../../features/goals/data/repositories/goal_repository_impl.dart';
import '../../features/goals/domain/repositories/goal_repository.dart';
import '../../features/goals/presentation/cubit/goal_cubit.dart';
import '../../features/debts/domain/repositories/debt_repository.dart';
import '../../features/debts/data/repositories/debt_repository_impl.dart';
import '../../features/debts/presentation/cubit/debt_cubit.dart';
import '../../features/coach/data/repositories/coach_repository_impl.dart';
import '../../features/coach/domain/repositories/coach_repository.dart';
import '../../features/coach/presentation/cubit/coach_cubit.dart';
import '../../features/consultation/data/repositories/consultation_repository_impl.dart';
import '../../features/consultation/domain/repositories/consultation_repository.dart';
import '../../features/consultation/presentation/cubit/consultation_cubit.dart';
import '../../features/monthly_review/data/repositories/monthly_review_repository_impl.dart';
import '../../features/monthly_review/domain/repositories/monthly_review_repository.dart';
import '../../features/monthly_review/presentation/cubit/monthly_review_cubit.dart';
import '../../features/onboarding/data/repositories/onboarding_repository_impl.dart';
import '../../features/onboarding/domain/repositories/onboarding_repository.dart';
import '../../features/onboarding/presentation/cubit/onboarding_cubit.dart';
import '../../features/profile/data/repositories/user_preferences_repository_impl.dart';
import '../../features/profile/domain/repositories/user_preferences_repository.dart';
import '../../features/profile/data/repositories/profile_repository_impl.dart';
import '../../features/profile/domain/repositories/profile_repository.dart';
import '../../features/profile/presentation/cubit/profile_cubit.dart';
import '../../features/profile/presentation/cubit/user_preferences_cubit.dart';
import '../../features/stock_signals/data/datasources/stock_signal_remote_data_source.dart';
import '../../features/stock_signals/data/repositories/stock_signal_repository_impl.dart';
import '../../features/stock_signals/domain/repositories/stock_signal_repository.dart';
import '../../features/stock_signals/domain/usecases/analyze_stock.dart';
import '../../features/stock_signals/domain/usecases/get_latest_signals.dart';
import '../../features/stock_signals/presentation/cubit/stock_analysis_cubit.dart';
import '../../features/stock_signals/presentation/cubit/stock_signal_list_cubit.dart';

final sl = GetIt.instance;

Future<void> initDependencies() async {
  // Core Services
  sl.registerLazySingleton<ConnectivityService>(() => ConnectivityService());
  sl.registerLazySingleton<PushNotificationService>(() => PushNotificationService());

  // Supabase Client
  sl.registerLazySingleton<SupabaseClient>(() => Supabase.instance.client);

  // Auth Feature
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(sl<SupabaseClient>()),
  );
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(sl<AuthRemoteDataSource>()),
  );
  sl.registerFactory<AuthCubit>(
    () => AuthCubit(
      authRepository: sl<AuthRepository>(),
      pushNotificationService: sl<PushNotificationService>(),
    ),
  );

  // Transactions, Categories & Accounts
  sl.registerLazySingleton<TransactionRemoteDataSource>(
    () => TransactionRemoteDataSourceImpl(sl<SupabaseClient>()),
  );
  sl.registerLazySingleton<TransactionRepository>(
    () => TransactionRepositoryImpl(sl<TransactionRemoteDataSource>()),
  );
  sl.registerLazySingleton<CategoryRepository>(
    () => CategoryRepositoryImpl(sl<SupabaseClient>()),
  );
  sl.registerLazySingleton<AccountRepository>(
    () => AccountRepositoryImpl(sl<SupabaseClient>()),
  );
  sl.registerFactory<TransactionCubit>(
    () => TransactionCubit(
      transactionRepository: sl<TransactionRepository>(),
      categoryRepository: sl<CategoryRepository>(),
      accountRepository: sl<AccountRepository>(),
    ),
  );

  // Budgets
  sl.registerLazySingleton<BudgetRepository>(
    () => BudgetRepositoryImpl(sl<SupabaseClient>()),
  );
  sl.registerFactory<BudgetCubit>(
    () => BudgetCubit(budgetRepository: sl<BudgetRepository>()),
  );

  // Goals
  sl.registerLazySingleton<GoalRepository>(
    () => GoalRepositoryImpl(sl<SupabaseClient>()),
  );
  sl.registerFactory<GoalCubit>(
    () => GoalCubit(goalRepository: sl<GoalRepository>()),
  );

  // Debts & Installments Tracker
  sl.registerLazySingleton<DebtRepository>(
    () => DebtRepositoryImpl(sl<SupabaseClient>()),
  );
  sl.registerFactory<DebtCubit>(
    () => DebtCubit(repository: sl<DebtRepository>()),
  );

  // Coach AI
  sl.registerLazySingleton<CoachRepository>(
    () => CoachRepositoryImpl(
      client: sl<SupabaseClient>(),
      transactionRepository: sl<TransactionRepository>(),
      budgetRepository: sl<BudgetRepository>(),
      goalRepository: sl<GoalRepository>(),
      accountRepository: sl<AccountRepository>(),
    ),
  );
  sl.registerFactory<CoachCubit>(
    () => CoachCubit(
      coachRepository: sl<CoachRepository>(),
      transactionRepository: sl<TransactionRepository>(),
      categoryRepository: sl<CategoryRepository>(),
    ),
  );

  // Onboarding & Initial Financial Setup
  sl.registerLazySingleton<OnboardingRepository>(
    () => OnboardingRepositoryImpl(
      client: sl<SupabaseClient>(),
      authRepository: sl<AuthRepository>(),
      accountRepository: sl<AccountRepository>(),
      categoryRepository: sl<CategoryRepository>(),
      budgetRepository: sl<BudgetRepository>(),
      transactionRepository: sl<TransactionRepository>(),
      goalRepository: sl<GoalRepository>(),
    ),
  );
  sl.registerFactory<OnboardingCubit>(
    () => OnboardingCubit(onboardingRepository: sl<OnboardingRepository>()),
  );

  // Purchase Consultation
  sl.registerLazySingleton<ConsultationRepository>(
    () => ConsultationRepositoryImpl(sl<SupabaseClient>()),
  );
  sl.registerFactory<ConsultationCubit>(
    () => ConsultationCubit(consultationRepository: sl<ConsultationRepository>()),
  );

  // Monthly Review
  sl.registerLazySingleton<MonthlyReviewRepository>(
    () => MonthlyReviewRepositoryImpl(
      sl<SupabaseClient>(),
      sl<TransactionRepository>(),
    ),
  );
  sl.registerFactory<MonthlyReviewCubit>(
    () => MonthlyReviewCubit(monthlyReviewRepository: sl<MonthlyReviewRepository>()),
  );

  // User Preferences
  sl.registerLazySingleton<UserPreferencesRepository>(
    () => UserPreferencesRepositoryImpl(sl<SupabaseClient>()),
  );
  sl.registerFactory<UserPreferencesCubit>(
    () => UserPreferencesCubit(repository: sl<UserPreferencesRepository>()),
  );

  // Profile (identity + financial profile)
  sl.registerLazySingleton<ProfileRepository>(
    () => ProfileRepositoryImpl(
      client: sl<SupabaseClient>(),
      budgetRepository: sl<BudgetRepository>(),
      authRepository: sl<AuthRepository>(),
    ),
  );
  sl.registerFactory<ProfileCubit>(
    () => ProfileCubit(repository: sl<ProfileRepository>()),
  );

  // Stock Signals (TradingView Alerts)
  sl.registerLazySingleton<StockSignalRemoteDataSource>(
    () => StockSignalRemoteDataSourceImpl(sl<SupabaseClient>()),
  );
  sl.registerLazySingleton<StockSignalRepository>(
    () => StockSignalRepositoryImpl(sl<StockSignalRemoteDataSource>()),
  );
  sl.registerLazySingleton<GetLatestSignals>(
    () => GetLatestSignals(sl<StockSignalRepository>()),
  );
  sl.registerLazySingleton<AnalyzeStock>(
    () => AnalyzeStock(sl<StockSignalRepository>()),
  );
  sl.registerFactory<StockSignalListCubit>(
    () => StockSignalListCubit(sl<GetLatestSignals>()),
  );
  sl.registerFactory<StockAnalysisCubit>(
    () => StockAnalysisCubit(sl<AnalyzeStock>()),
  );
}

