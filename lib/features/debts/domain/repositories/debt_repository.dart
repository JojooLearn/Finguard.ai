import '../../../../core/result/result.dart';
import '../entities/debt_entity.dart';

abstract class DebtRepository {
  Future<Result<List<DebtEntity>>> getDebts();
  Future<Result<DebtEntity>> addDebt({
    required String name,
    required double monthlyPayment,
    required int remainingTenor,
    required int totalTenor,
    required int dueDay,
    double annualInterestRate = 0.0,
    DateTime? startDate,
  });
  Future<Result<DebtEntity>> payInstallment(String debtId);
  Future<Result<void>> deleteDebt(String debtId);
}
