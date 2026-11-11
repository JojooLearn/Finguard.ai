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
import 'package:finguard/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finguard/features/transactions/domain/repositories/transaction_repository.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockGoTrueClient extends Mock implements GoTrueClient {}

class _MockTxRepo extends Mock implements TransactionRepository {}

class _MockBudgetRepo extends Mock implements BudgetRepository {}

class _MockGoalRepo extends Mock implements GoalRepository {}

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
    final debtRepo = _MockDebtRepo();

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
    ).thenAnswer((_) async => const Success(<TransactionEntity>[]));
    when(
      () => budgetRepo.getBudgets(
        periodStart: any(named: 'periodStart'),
        periodEnd: any(named: 'periodEnd'),
      ),
    ).thenAnswer((_) async => const Success(<BudgetEntity>[]));
    when(() => goalRepo.getGoals()).thenAnswer(
      (_) async => const Success(<GoalEntity>[]),
    );
    when(() => debtRepo.getDebts()).thenAnswer(
      (_) async => const Success(<DebtEntity>[]),
    );

    coachRepo = CoachRepositoryImpl(
      client: mockSupabase,
      transactionRepository: txRepo,
      budgetRepository: budgetRepo,
      goalRepository: goalRepo,
      debtRepository: debtRepo,
    );
  });

  group('CoachRepositoryImpl Dana Darurat deposit move/transfer keywords', () {
    final depositCommands = <String>[
      'pindahin uang dingin saya 100k ke dana darurat',
      'tolong pindahkan 100rb dari uang dingin ke tabungan dana darurat',
      'transfer 150k ke dana darurat',
      'geser 200rb ke celengan dana darurat',
      'sisihin 100rb buat dana darurat',
      'sisihkan 100k untuk pos dana darurat',
      'pindahin saldo 100k ke dana darurat',
    ];

    for (final cmd in depositCommands) {
      test('routes "$cmd" as goal_deposit / emergency_fund_deposit', () async {
        final res = await coachRepo.sendMessage(message: cmd);
        final msg = res.fold((m) => m, (f) => throw Exception(f.message));

        expect(msg.structuredPayload, isNotNull);
        expect(msg.structuredPayload!['type'], 'goal_deposit');
        expect(
          msg.structuredPayload!['funding_source'],
          'emergency_fund_deposit',
        );
        expect(
          msg.structuredPayload!['category_suggestion'],
          'Dana Darurat',
        );
      });
    }

    test('does NOT misclassify withdrawal from dana darurat as deposit', () async {
      final res = await coachRepo.sendMessage(
        message: 'pindahin 50rb dari dana darurat ke jajan makan',
      );
      final msg = res.fold((m) => m, (f) => throw Exception(f.message));

      expect(msg.structuredPayload, isNotNull);
      expect(msg.structuredPayload!['type'], 'expense');
      expect(msg.structuredPayload!['funding_source'], isNot('emergency_fund_deposit'));
    });
  });
}
