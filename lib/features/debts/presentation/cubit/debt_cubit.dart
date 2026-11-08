import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/debt_repository.dart';
import 'debt_state.dart';

class DebtCubit extends Cubit<DebtState> {
  final DebtRepository repository;

  DebtCubit({required this.repository}) : super(const DebtInitial());

  Future<void> loadDebts() async {
    emit(const DebtLoading());
    final result = await repository.getDebts();
    result.fold(
      (debts) => emit(DebtLoaded(debts)),
      (failure) => emit(DebtError(failure.message)),
    );
  }

  Future<void> addDebt({
    required String name,
    required double monthlyPayment,
    required int remainingTenor,
    required int totalTenor,
    required int dueDay,
    double annualInterestRate = 0.0,
    DateTime? startDate,
  }) async {
    final result = await repository.addDebt(
      name: name,
      monthlyPayment: monthlyPayment,
      remainingTenor: remainingTenor,
      totalTenor: totalTenor,
      dueDay: dueDay,
      annualInterestRate: annualInterestRate,
      startDate: startDate,
    );
    result.fold(
      (_) => loadDebts(),
      (failure) => emit(DebtError(failure.message)),
    );
  }

  Future<bool> payInstallment(String debtId) async {
    final result = await repository.payInstallment(debtId);
    return result.fold(
      (_) {
        loadDebts();
        return true;
      },
      (failure) {
        emit(DebtError(failure.message));
        return false;
      },
    );
  }

  Future<void> deleteDebt(String debtId) async {
    final result = await repository.deleteDebt(debtId);
    result.fold(
      (_) => loadDebts(),
      (failure) => emit(DebtError(failure.message)),
    );
  }
}

