import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:finguard/core/result/result.dart';
import 'package:finguard/features/budgets/domain/entities/budget_entity.dart';
import 'package:finguard/features/budgets/domain/repositories/budget_repository.dart';
import 'package:finguard/features/coach/data/repositories/coach_repository_impl.dart';
import 'package:finguard/features/debts/domain/entities/debt_entity.dart';
import 'package:finguard/features/debts/domain/repositories/debt_repository.dart';
import 'package:finguard/features/goals/domain/entities/goal_entity.dart';
import 'package:finguard/features/goals/domain/repositories/goal_repository.dart';
import 'package:finguard/features/transactions/domain/entities/account_entity.dart';
import 'package:finguard/features/transactions/domain/entities/category_entity.dart';
import 'package:finguard/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finguard/features/transactions/domain/repositories/category_and_account_repository.dart';
import 'package:finguard/features/transactions/domain/repositories/transaction_repository.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockGoTrueClient extends Mock implements GoTrueClient {}

class _MockTxRepo extends Mock implements TransactionRepository {}

class _MockBudgetRepo extends Mock implements BudgetRepository {}

class _MockGoalRepo extends Mock implements GoalRepository {}

class _MockAccountRepo extends Mock implements AccountRepository {}

class _MockDebtRepo extends Mock implements DebtRepository {}

void main() {
  late CoachRepositoryImpl coachRepo;

  setUp(() {
    registerFallbackValue(DateTime.now());
    final mockSupabase = _MockSupabaseClient();
    final mockAuth = _MockGoTrueClient();
    when(() => mockSupabase.auth).thenReturn(mockAuth);
    when(() => mockAuth.currentUser).thenReturn(null);

    final txRepo = _MockTxRepo();
    final budgetRepo = _MockBudgetRepo();
    final goalRepo = _MockGoalRepo();
    final accountRepo = _MockAccountRepo();
    final debtRepo = _MockDebtRepo();

    final now = DateTime.now();

    when(
      () => txRepo.getTransactions(
        startDate: any(named: 'startDate'),
        endDate: any(named: 'endDate'),
        categoryId: any(named: 'categoryId'),
        accountId: any(named: 'accountId'),
        type: any(named: 'type'),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer(
      (_) async => Success([
        TransactionEntity(
          id: 'tx_1',
          userId: 'u1',
          accountId: 'acc_1',
          categoryId: 'cat_1',
          transactionType: TransactionType.income,
          amount: 1000000,
          transactionDate: now,
          status: TransactionStatus.confirmed,
          createdAt: now,
          updatedAt: now,
        ),
      ]),
    );

    when(
      () => budgetRepo.getBudgets(
        periodStart: any(named: 'periodStart'),
        periodEnd: any(named: 'periodEnd'),
      ),
    ).thenAnswer((_) async => const Success(<BudgetEntity>[]));

    when(() => goalRepo.getGoals()).thenAnswer(
      (_) async => Success([
        GoalEntity(
          id: 'g_ef',
          userId: 'u1',
          name: 'Dana Darurat',
          goalType: GoalType.emergencyFund,
          targetAmount: 1500000,
          currentAmount: 150000,
          createdAt: now,
          updatedAt: now,
        ),
        GoalEntity(
          id: 'g_lap',
          userId: 'u1',
          name: 'Beli Laptop',
          goalType: GoalType.savings,
          targetAmount: 5000000,
          currentAmount: 200000,
          createdAt: now,
          updatedAt: now,
        ),
      ]),
    );

    when(() => accountRepo.getAccounts()).thenAnswer(
      (_) async => Success([
        AccountEntity(
          id: 'acc_1',
          userId: 'u1',
          name: 'Dompet Utama',
          accountType: AccountType.cash,
          openingBalance: 0,
          isDefault: true,
          createdAt: now,
          updatedAt: now,
        ),
      ]),
    );

    when(() => debtRepo.getDebts()).thenAnswer(
      (_) async => const Success(<DebtEntity>[]),
    );

    coachRepo = CoachRepositoryImpl(
      client: mockSupabase,
      transactionRepository: txRepo,
      budgetRepository: budgetRepo,
      goalRepository: goalRepo,
      accountRepository: accountRepo,
      debtRepository: debtRepo,
    );
  });

  test(
    'Dana Darurat specific question routes directly to Dana Darurat answer rather than full balance sheet',
    () async {
      final res = await coachRepo.sendMessage(
        message: 'jadi dana darurat saya berapa sekarang, babu tolong cek',
        strictnessLevel: 5,
      );
      final msg = res.fold((m) => m, (f) => throw Exception(f.message));

      expect(msg.content, contains('Rp150.000'));
      expect(msg.content, contains('Rp1.500.000'));
      expect(msg.content, isNot(contains('Ringkasan Saldo & Duit Lu Saat Ini')));
      expect(msg.content, isNot(contains('Beli Laptop')));
    },
  );

  test(
    'Balance summary removes total savings target line and Total Duit & Tabungan while listing goals individually',
    () async {
      final res = await coachRepo.sendMessage(
        message: 'cek saldo saya sekarang',
        strictnessLevel: 5,
      );
      final msg = res.fold((m) => m, (f) => throw Exception(f.message));

      expect(msg.content, contains('Ringkasan Saldo & Duit Lu Saat Ini'));
      expect(msg.content, contains('Dana Darurat: Rp150.000'));
      expect(msg.content, contains('Beli Laptop: Rp200.000'));
      expect(msg.content, isNot(contains('Duit di Target Tabungan')));
      expect(msg.content, isNot(contains('Total Duit & Tabungan')));
      expect(msg.content, isNot(contains('- Dompet Utama: Rp0')));
    },
  );
}
