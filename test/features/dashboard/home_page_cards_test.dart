import 'package:bloc_test/bloc_test.dart';
import 'package:finguard/core/widgets/explanation_sheet.dart';
import 'package:finguard/features/auth/domain/entities/user_entity.dart';
import 'package:finguard/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:finguard/features/auth/presentation/cubit/auth_state.dart';
import 'package:finguard/features/budgets/domain/entities/budget_entity.dart';
import 'package:finguard/features/budgets/presentation/cubit/budget_cubit.dart';
import 'package:finguard/features/budgets/presentation/cubit/budget_state.dart';
import 'package:finguard/features/dashboard/presentation/pages/home_page.dart';
import 'package:finguard/features/goals/domain/entities/goal_entity.dart';
import 'package:finguard/features/goals/presentation/cubit/goal_cubit.dart';
import 'package:finguard/features/goals/presentation/cubit/goal_state.dart';
import 'package:finguard/features/profile/domain/entities/profile_entity.dart';
import 'package:finguard/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:finguard/features/profile/presentation/cubit/profile_state.dart';
import 'package:finguard/features/stock_signals/presentation/cubit/stock_signal_list_cubit.dart';
import 'package:finguard/features/stock_signals/presentation/cubit/stock_signal_list_state.dart';
import 'package:finguard/features/transactions/domain/entities/category_entity.dart';
import 'package:finguard/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finguard/features/transactions/presentation/cubit/transaction_cubit.dart';
import 'package:finguard/features/transactions/presentation/cubit/transaction_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAuthCubit extends MockCubit<AuthState> implements AuthCubit {}

class _MockProfileCubit extends MockCubit<ProfileState>
    implements ProfileCubit {}

class _MockTransactionCubit extends MockCubit<TransactionState>
    implements TransactionCubit {}

class _MockBudgetCubit extends MockCubit<BudgetState> implements BudgetCubit {}

class _MockGoalCubit extends MockCubit<GoalState> implements GoalCubit {}

class _MockStockSignalListCubit extends MockCubit<StockSignalListState>
    implements StockSignalListCubit {}

void main() {
  late _MockAuthCubit authCubit;
  late _MockProfileCubit profileCubit;
  late _MockTransactionCubit transactionCubit;
  late _MockBudgetCubit budgetCubit;
  late _MockGoalCubit goalCubit;
  late _MockStockSignalListCubit stockSignalListCubit;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    authCubit = _MockAuthCubit();
    profileCubit = _MockProfileCubit();
    transactionCubit = _MockTransactionCubit();
    budgetCubit = _MockBudgetCubit();
    goalCubit = _MockGoalCubit();
    stockSignalListCubit = _MockStockSignalListCubit();

    when(() => stockSignalListCubit.loadSignals()).thenAnswer((_) async {});
    when(() => authCubit.state).thenReturn(
      const Authenticated(
        UserEntity(id: 'u1', email: 'test@finguard.id', displayName: 'Budi'),
      ),
    );
    when(() => profileCubit.state).thenReturn(
      const ProfileLoaded(
        ProfileEntity(
          id: 'u1',
          displayName: 'Budi',
          email: 'test@finguard.id',
          monthlyIncome: 1000000,
        ),
      ),
    );
    when(() => stockSignalListCubit.state)
        .thenReturn(const StockSignalLoaded([]));
  });

  Widget buildSubject() {
    return MaterialApp(
      home: Scaffold(
        body: MultiBlocProvider(
          providers: [
            BlocProvider<AuthCubit>.value(value: authCubit),
            BlocProvider<ProfileCubit>.value(value: profileCubit),
            BlocProvider<TransactionCubit>.value(value: transactionCubit),
            BlocProvider<BudgetCubit>.value(value: budgetCubit),
            BlocProvider<GoalCubit>.value(value: goalCubit),
            BlocProvider<StockSignalListCubit>.value(
              value: stockSignalListCubit,
            ),
          ],
          child: const HomePage(),
        ),
      ),
    );
  }

  testWidgets(
    'renders 3-card Bento layout without redundant Budget metric card and shows Dana Darurat progress banner',
    (tester) async {
      final now = DateTime.now();

      when(() => transactionCubit.state).thenReturn(
        TransactionLoaded(
          transactions: [
            TransactionEntity(
              id: 't1',
              userId: 'u1',
              transactionType: TransactionType.income,
              amount: 1000000,
              transactionDate: now,
              note: 'Gaji',
              createdAt: now,
              updatedAt: now,
            ),
            TransactionEntity(
              id: 't2',
              userId: 'u1',
              transactionType: TransactionType.expense,
              amount: 250000,
              transactionDate: now,
              note: 'Tagihan listrik',
              createdAt: now,
              updatedAt: now,
            ),
          ],
        ),
      );

      when(() => budgetCubit.state).thenReturn(
        BudgetLoaded(
          budgets: [
            BudgetEntity(
              id: 'b1',
              userId: 'u1',
              categoryId: 'c1',
              categoryName: 'Tagihan & Utilitas',
              periodStart: DateTime(now.year, now.month, 1),
              periodEnd: DateTime(now.year, now.month + 1, 0),
              limitAmount: 100000,
              spentAmount: 50000,
              createdAt: now,
              updatedAt: now,
            ),
          ],
          periodStart: DateTime(now.year, now.month, 1),
          periodEnd: DateTime(now.year, now.month + 1, 0),
        ),
      );

      when(() => goalCubit.state).thenReturn(
        GoalLoaded([
          GoalEntity(
            id: 'g1',
            userId: 'u1',
            name: 'Dana Darurat',
            goalType: GoalType.emergencyFund,
            targetAmount: 1500000,
            currentAmount: 150000,
            createdAt: now,
            updatedAt: now,
          ),
        ]),
      );

      await tester.pumpWidget(buildSubject());
      await tester.pump(const Duration(milliseconds: 600));

      // Row 1 cards: Income & Expense + burn ratio progress caption
      expect(find.text('Total Pemasukan'), findsOneWidget);
      expect(find.text('Total Pengeluaran'), findsOneWidget);
      expect(find.text('25% dari pemasukan'), findsOneWidget);

      // Redundant 4th Budget stat card removed from Home bento section
      expect(find.text('Sisa jatah: Rp50.000'), findsNothing);
      expect(find.text('Jatah Belanja'), findsNothing);

      // Row 2 elongated Dana Darurat banner card with animated progress bar
      expect(find.text('Dana Darurat'), findsOneWidget);
      expect(find.text('10%'), findsOneWidget);
      expect(find.text('Terus Pupuk'), findsOneWidget);
      expect(find.text('Target: Rp1.500.000'), findsOneWidget);
      expect(find.text('Setor'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label == 'Progress Dana Darurat' &&
              w.properties.value == '10%',
        ),
        findsOneWidget,
      );

      // Tap Dana Darurat banner opens ExplanationSheet without exceptions
      await tester.ensureVisible(find.text('Dana Darurat'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dana Darurat'));
      await tester.pumpAndSettle();
      expect(find.byType(ExplanationSheet), findsOneWidget);
      expect(
        find.textContaining('Terkumpul Rp150.000 / Target Rp1.500.000 (10%)'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Dana Darurat banner displays completed status when target is 100% funded even before monthly cashflow',
    (tester) async {
      final now = DateTime.now();

      when(() => transactionCubit.state)
          .thenReturn(const TransactionLoaded(transactions: []));
      when(() => budgetCubit.state).thenReturn(
        BudgetLoaded(
          budgets: const [],
          periodStart: DateTime(now.year, now.month, 1),
          periodEnd: DateTime(now.year, now.month + 1, 0),
        ),
      );
      when(() => goalCubit.state).thenReturn(
        GoalLoaded([
          GoalEntity(
            id: 'g1',
            userId: 'u1',
            name: 'Dana Darurat',
            goalType: GoalType.emergencyFund,
            targetAmount: 1000000,
            currentAmount: 1000000,
            createdAt: now,
            updatedAt: now,
          ),
        ]),
      );

      await tester.pumpWidget(buildSubject());
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('100%'), findsOneWidget);
      expect(find.text('Aman Tercapai'), findsOneWidget);
      expect(
        find.text('Target penuh tercapai — dana aman siap siaga'),
        findsOneWidget,
      );
    },
  );
}
