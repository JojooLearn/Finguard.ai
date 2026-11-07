import '../../../../core/result/result.dart';
import '../entities/budget_entity.dart';

abstract class BudgetRepository {
  Future<Result<List<BudgetEntity>>> getBudgets({
    required DateTime periodStart,
    required DateTime periodEnd,
  });

  Future<Result<BudgetEntity>> setBudget({
    required String categoryId,
    String? categoryName,
    required double limitAmount,
    required DateTime periodStart,
    required DateTime periodEnd,
  });

  Future<Result<void>> deleteBudget(String id);

  void clearCache() {}
}
