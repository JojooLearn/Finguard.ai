import 'package:equatable/equatable.dart';
import '../../domain/entities/budget_entity.dart';

abstract class BudgetState extends Equatable {
  const BudgetState();

  @override
  List<Object?> get props => [];
}

class BudgetInitial extends BudgetState {
  const BudgetInitial();
}

class BudgetLoading extends BudgetState {
  const BudgetLoading();
}

class BudgetLoaded extends BudgetState {
  final List<BudgetEntity> budgets;
  final DateTime periodStart;
  final DateTime periodEnd;

  const BudgetLoaded({
    required this.budgets,
    required this.periodStart,
    required this.periodEnd,
  });

  double get totalLimit => budgets.fold(0.0, (sum, b) => sum + b.limitAmount);
  double get totalSpent => budgets.fold(0.0, (sum, b) => sum + b.spentAmount);
  double get totalRemaining => (totalLimit - totalSpent).clamp(0.0, double.infinity);
  double get overallUsage => totalLimit > 0 ? (totalSpent / totalLimit) : 0.0;

  @override
  List<Object?> get props => [budgets, periodStart, periodEnd];
}

class BudgetError extends BudgetState {
  final String message;

  const BudgetError(this.message);

  @override
  List<Object?> get props => [message];
}
