import '../../../../core/result/result.dart';
import '../entities/goal_entity.dart';

abstract class GoalRepository {
  Future<Result<List<GoalEntity>>> getGoals();
  Future<Result<GoalEntity>> createGoal({
    required String name,
    required GoalType type,
    required double targetAmount,
    DateTime? targetDate,
    String? description,
    int priority = 3,
  });
  Future<Result<GoalEntity>> addContribution({
    required String goalId,
    required double amount,
    DateTime? date,
    String? note,
  });
  Future<Result<void>> updateGoalStatus(String goalId, GoalStatus status);
  Future<Result<void>> deleteGoal(String goalId);
}
