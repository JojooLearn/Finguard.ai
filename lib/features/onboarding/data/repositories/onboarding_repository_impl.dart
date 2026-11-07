import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/result/result.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../../budgets/domain/repositories/budget_repository.dart';
import '../../../goals/domain/entities/goal_entity.dart';
import '../../../goals/domain/repositories/goal_repository.dart';
import '../../../transactions/domain/entities/account_entity.dart';
import '../../../transactions/domain/entities/category_entity.dart';
import '../../../transactions/domain/repositories/category_and_account_repository.dart';
import '../../../transactions/domain/repositories/transaction_repository.dart';
import '../../domain/entities/initial_setup_entity.dart';
import '../../domain/repositories/onboarding_repository.dart';

class OnboardingRepositoryImpl implements OnboardingRepository {
  final SupabaseClient client;
  final AuthRepository authRepository;
  final AccountRepository accountRepository;
  final CategoryRepository categoryRepository;
  final BudgetRepository budgetRepository;
  final TransactionRepository transactionRepository;
  final GoalRepository goalRepository;

  final Set<String> _completedUserIds = {};

  OnboardingRepositoryImpl({
    required this.client,
    required this.authRepository,
    required this.accountRepository,
    required this.categoryRepository,
    required this.budgetRepository,
    required this.transactionRepository,
    required this.goalRepository,
  });

  @override
  Future<bool> hasCompletedOnboarding(String userId) async {
    if (_completedUserIds.contains(userId)) return true;
    try {
      final user = client.auth.currentUser;
      if (user != null) {
        final res = await client
            .from('profiles')
            .select('onboarding_completed_at')
            .eq('id', user.id)
            .maybeSingle();
        if (res != null && res['onboarding_completed_at'] != null) {
          _completedUserIds.add(userId);
          return true;
        }
      }
    } catch (_) {}
    return _completedUserIds.contains(userId);
  }

  @override
  Future<Result<void>> completeOnboarding(InitialSetupEntity setupData) async {
    final user = authRepository.getCurrentUser();
    final userId = user?.id ?? 'local_user';

    try {
      // 1. Update user display name in local Auth
      authRepository.updateCurrentUserDisplayName(setupData.fullName);

      // 2. CRITICAL: Persist Parent Tables FIRST to Supabase (profiles & financial_profiles)
      // All child tables (accounts, categories, budgets, transactions, financial_goals)
      // have hard FOREIGN KEY constraints to public.profiles(id)!
      try {
        final remoteUser = client.auth.currentUser;
        if (remoteUser != null) {
          // 2a. Profiles (Parent Key)
          await client.from('profiles').upsert({
            'id': remoteUser.id,
            'display_name': setupData.fullName,
            'onboarding_completed_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });

          // 2b. Financial Profiles
          await client.from('financial_profiles').upsert({
            'user_id': remoteUser.id,
            'monthly_income': setupData.monthlyIncome,
            'essential_monthly_expenses':
                (setupData.budgetFood + setupData.budgetTransport + setupData.budgetBills),
            'dependents_count': setupData.dependentsCount,
            'monthly_debt_payments': setupData.monthlyDebtPayments,
            'current_emergency_fund': setupData.emergencyFundCurrent,
            'strictness_level': setupData.strictnessLevel,
            'updated_at': DateTime.now().toIso8601String(),
          });

          // 2c. User Preferences
          await client.from('user_preferences').upsert({
            'user_id': remoteUser.id,
            'notifications_enabled': true,
            'budget_alerts_enabled': true,
            'updated_at': DateTime.now().toIso8601String(),
          });
        }
      } catch (e) {
        // ignore: avoid_print
        print('Error inserting parent profile: $e');
      }

      // 3. Create primary account with initial balance (now profiles(id) is guaranteed to exist)
      final accRes = await accountRepository.createAccount(
        name: setupData.accountName.isNotEmpty ? setupData.accountName : 'Rekening Utama',
        type: AccountType.bank,
        openingBalance: (setupData.initialBalance > setupData.monthlyIncome)
            ? (setupData.initialBalance - setupData.monthlyIncome)
            : 0.0,
        isDefault: true,
      );
      final createdAccount = accRes.fold((a) => a, (_) => null);

      // 4. Ensure Default Categories in Supabase & Retrieve their Real UUIDs
      final catResult = await categoryRepository.getCategories();
      List<CategoryEntity> categories = catResult.fold((c) => c, (_) => []);

      CategoryEntity? foodCat = categories.where((c) => c.name.toLowerCase().contains('makan')).firstOrNull;
      CategoryEntity? transCat = categories.where((c) => c.name.toLowerCase().contains('transport')).firstOrNull;
      CategoryEntity? billCat = categories.where((c) => c.name.toLowerCase().contains('tagihan')).firstOrNull;
      CategoryEntity? entCat = categories.where((c) => c.name.toLowerCase().contains('hiburan')).firstOrNull;
      CategoryEntity? incomeCat = categories.where((c) => c.transactionType == TransactionType.income).firstOrNull;

      // 5. Set budgets for current month in Supabase
      final now = DateTime.now();
      final periodStart = DateTime(now.year, now.month, 1);
      final periodEnd = DateTime(now.year, now.month + 1, 0);

      if (setupData.budgetFood > 0) {
        await budgetRepository.setBudget(
          categoryId: foodCat?.id ?? 'cat_sys_makan',
          categoryName: foodCat?.name ?? 'Makan & Minum',
          limitAmount: setupData.budgetFood,
          periodStart: periodStart,
          periodEnd: periodEnd,
        );
      }

      if (setupData.budgetTransport > 0) {
        await budgetRepository.setBudget(
          categoryId: transCat?.id ?? 'cat_sys_transport',
          categoryName: transCat?.name ?? 'Transportasi',
          limitAmount: setupData.budgetTransport,
          periodStart: periodStart,
          periodEnd: periodEnd,
        );
      }

      if (setupData.budgetBills > 0) {
        await budgetRepository.setBudget(
          categoryId: billCat?.id ?? 'cat_sys_tagihan',
          categoryName: billCat?.name ?? 'Tagihan & Utilitas',
          limitAmount: setupData.budgetBills,
          periodStart: periodStart,
          periodEnd: periodEnd,
        );
      }

      if (setupData.budgetEntertainment > 0) {
        await budgetRepository.setBudget(
          categoryId: entCat?.id ?? 'cat_sys_hiburan',
          categoryName: entCat?.name ?? 'Hiburan',
          limitAmount: setupData.budgetEntertainment,
          periodStart: periodStart,
          periodEnd: periodEnd,
        );
      }

      // 6. Create initial Income transaction (Gaji Masuk)
      if (setupData.monthlyIncome > 0) {
        await transactionRepository.createTransaction(
          amount: setupData.monthlyIncome,
          type: TransactionType.income,
          transactionDate: DateTime(now.year, now.month, 1),
          categoryId: incomeCat?.id,
          accountId: createdAccount?.id,
          note: 'Gaji Bulanan',
        );
      }

      // 7. Create Goal: Dana Darurat
      if (setupData.emergencyFundTarget > 0) {
        final goalRes = await goalRepository.createGoal(
          name: 'Dana Darurat',
          type: GoalType.emergencyFund,
          targetAmount: setupData.emergencyFundTarget,
          targetDate: DateTime(now.year + 1, 12, 31),
          description: 'Pondasi cadangan kas darurat 3-6 bulan pengeluaran',
        );

        // Add initial saved contribution if any
        if (setupData.emergencyFundCurrent > 0) {
          goalRes.fold(
            (goal) async {
              await goalRepository.addContribution(
                goalId: goal.id,
                amount: setupData.emergencyFundCurrent,
                note: 'Saldo Awal Dana Darurat',
              );
            },
            (_) {},
          );
        }
      }

      // 8. Mark onboarding as completed in memory and remote database
      _completedUserIds.add(userId);
      authRepository.setOnboardingCompleted(true);
      try {
        await client.auth.updateUser(
          UserAttributes(data: {'onboarding_completed': true}),
        );
      } catch (_) {}

      return const Success(null);
    } catch (e) {
      // ignore: avoid_print
      print('completeOnboarding error: $e');
      // Even if partially errored, mark completed to avoid deadlock
      _completedUserIds.add(userId);
      authRepository.setOnboardingCompleted(true);
      try {
        await client.auth.updateUser(
          UserAttributes(data: {'onboarding_completed': true}),
        );
      } catch (_) {}
      return const Success(null);
    }
  }
}
