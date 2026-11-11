import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:finguard/core/result/result.dart';
import 'package:finguard/features/budgets/domain/entities/budget_entity.dart';
import 'package:finguard/features/budgets/domain/repositories/budget_repository.dart';
import 'package:finguard/features/budgets/presentation/cubit/budget_cubit.dart';
import 'package:finguard/features/budgets/presentation/pages/budget_page.dart';
import 'package:finguard/features/profile/domain/repositories/profile_repository.dart';
import 'package:finguard/features/profile/presentation/cubit/profile_cubit.dart';

class _MockBudgetRepository extends Mock implements BudgetRepository {}

class _MockProfileRepository extends Mock implements ProfileRepository {}

void main() {
  testWidgets(
    'BudgetPage header displays title without month pill or add button icons',
    (tester) async {
      registerFallbackValue(DateTime.now());
      final mockRepo = _MockBudgetRepository();
      final now = DateTime.now();
      when(
        () => mockRepo.getBudgets(
          periodStart: any(named: 'periodStart'),
          periodEnd: any(named: 'periodEnd'),
        ),
      ).thenAnswer(
        (_) async => Success([
          BudgetEntity(
            id: 'b1',
            userId: 'u1',
            categoryId: 'c1',
            categoryName: 'Makan & Minum',
            periodStart: DateTime(now.year, now.month, 1),
            periodEnd: DateTime(now.year, now.month + 1, 0),
            limitAmount: 300000,
            spentAmount: 0,
            createdAt: now,
            updatedAt: now,
          ),
        ]),
      );

      final cubit = BudgetCubit(budgetRepository: mockRepo);
      final profileCubit = ProfileCubit(repository: _MockProfileRepository());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MultiBlocProvider(
              providers: [
                BlocProvider<BudgetCubit>.value(value: cubit),
                BlocProvider<ProfileCubit>.value(value: profileCubit),
              ],
              child: const BudgetPage(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Atur Jatah Belanja'), findsOneWidget);
      expect(find.byIcon(PhosphorIcons.plus()), findsNothing);
      expect(find.byIcon(PhosphorIcons.calendarBlank()), findsNothing);

      await cubit.close();
      await profileCubit.close();
    },
  );
}

