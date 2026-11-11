import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:finguard/features/goals/data/repositories/goal_repository_impl.dart';
import 'package:finguard/features/goals/domain/entities/goal_entity.dart';
import 'package:finguard/features/goals/presentation/cubit/goal_cubit.dart';
import 'package:finguard/features/goals/presentation/cubit/goal_state.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockGoTrueClient extends Mock implements GoTrueClient {}

void main() {
  test(
    'GoalCubit tracks monthly savings transfers cleanly and ignores initial seed notes',
    () async {
      final mockSupabase = _MockSupabaseClient();
      final mockAuth = _MockGoTrueClient();
      when(() => mockSupabase.auth).thenReturn(mockAuth);
      when(() => mockAuth.currentUser).thenReturn(null);

      final repo = GoalRepositoryImpl(mockSupabase);
      final cubit = GoalCubit(goalRepository: repo);

      await cubit.createGoal(
        name: 'Dana Darurat',
        type: GoalType.emergencyFund,
        targetAmount: 1500000,
      );

      final createdState = cubit.state as GoalLoaded;
      final goalId = createdState.goals.first.id;
      final now = DateTime.now();

      // Onboarding seed should NOT reduce monthly net cash flow
      await cubit.addContribution(
        goalId: goalId,
        amount: 500000,
        date: now,
        note: 'Saldo Awal Dana Darurat',
      );
      var loaded = cubit.state as GoalLoaded;
      expect(loaded.goals.first.currentAmount, 500000);
      expect(loaded.netSavingsForMonth(now.year, now.month), 0.0);

      // Moving Rp100.000 this month MUST update goal amount AND current month's transfer
      await cubit.addContribution(
        goalId: goalId,
        amount: 100000,
        date: now,
        note: 'Setoran Dana Darurat',
      );
      loaded = cubit.state as GoalLoaded;
      expect(loaded.goals.first.currentAmount, 600000);
      expect(loaded.netSavingsForMonth(now.year, now.month), 100000.0);

      // Unrelated month stays 0.0
      final otherMonth = now.month == 1 ? 2 : now.month - 1;
      expect(loaded.netSavingsForMonth(now.year, otherMonth), 0.0);

      await cubit.close();
    },
  );
}

