import '../../../../core/result/result.dart';
import '../entities/category_entity.dart';
import '../entities/transaction_entity.dart';

abstract class TransactionRepository {
  Future<Result<List<TransactionEntity>>> getTransactions({
    DateTime? startDate,
    DateTime? endDate,
    String? categoryId,
    String? accountId,
    TransactionType? type,
    int limit = 50,
    int offset = 0,
  });

  Future<Result<TransactionEntity>> getTransactionById(String id);

  Future<Result<TransactionEntity>> createTransaction({
    required double amount,
    required TransactionType type,
    required DateTime transactionDate,
    String? categoryId,
    String? accountId,
    String? note,
    TransactionSource source = TransactionSource.manual,
    String? clientRequestId,
  });

  Future<Result<TransactionEntity>> updateTransaction(TransactionEntity transaction);

  Future<Result<void>> deleteTransaction(String id);
}
