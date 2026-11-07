import 'package:equatable/equatable.dart';
import '../../domain/entities/debt_entity.dart';

abstract class DebtState extends Equatable {
  const DebtState();

  @override
  List<Object?> get props => [];
}

class DebtInitial extends DebtState {
  const DebtInitial();
}

class DebtLoading extends DebtState {
  const DebtLoading();
}

class DebtLoaded extends DebtState {
  final List<DebtEntity> debts;

  const DebtLoaded(this.debts);

  double get totalMonthlyDebt => debts
      .where((d) => !d.isCompleted && d.remainingTenorMonths > 0)
      .fold(0.0, (sum, d) => sum + d.monthlyPayment);

  double get totalRemainingBalance => debts
      .where((d) => !d.isCompleted && d.remainingTenorMonths > 0)
      .fold(0.0, (sum, d) => sum + d.remainingAmount);

  int get activeDebtCount =>
      debts.where((d) => !d.isCompleted && d.remainingTenorMonths > 0).length;

  @override
  List<Object?> get props => [debts];
}

class DebtError extends DebtState {
  final String message;

  const DebtError(this.message);

  @override
  List<Object?> get props => [message];
}

