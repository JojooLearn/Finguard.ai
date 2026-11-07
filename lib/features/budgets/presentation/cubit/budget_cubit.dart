import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/budget_repository.dart';
import 'budget_state.dart';

class BudgetCubit extends Cubit<BudgetState> {
  final BudgetRepository budgetRepository;

  BudgetCubit({required this.budgetRepository}) : super(const BudgetInitial());

  Future<void> loadBudgets({DateTime? start, DateTime? end}) async {
    emit(const BudgetLoading());

    final now = DateTime.now();
    final periodStart = start ?? DateTime(now.year, now.month, 1);
    final periodEnd = end ?? DateTime(now.year, now.month + 1, 0);

    final result = await budgetRepository.getBudgets(
      periodStart: periodStart,
      periodEnd: periodEnd,
    );

    result.fold(
      (budgets) => emit(BudgetLoaded(
        budgets: budgets,
        periodStart: periodStart,
        periodEnd: periodEnd,
      )),
      (failure) => emit(BudgetError(failure.message)),
    );
  }

  Future<void> setBudget({
    required String categoryId,
    String? categoryName,
    required double limitAmount,
    DateTime? start,
    DateTime? end,
  }) async {
    final now = DateTime.now();
    final periodStart = start ?? DateTime(now.year, now.month, 1);
    final periodEnd = end ?? DateTime(now.year, now.month + 1, 0);

    final result = await budgetRepository.setBudget(
      categoryId: categoryId,
      categoryName: categoryName,
      limitAmount: limitAmount,
      periodStart: periodStart,
      periodEnd: periodEnd,
    );

    result.fold(
      (_) => loadBudgets(start: periodStart, end: periodEnd),
      (failure) => emit(BudgetError(failure.message)),
    );
  }

  Future<void> deleteBudget(String id) async {
    await budgetRepository.deleteBudget(id);
    await loadBudgets();
  }

  void reset() {
    budgetRepository.clearCache();
    emit(const BudgetInitial());
  }
}
