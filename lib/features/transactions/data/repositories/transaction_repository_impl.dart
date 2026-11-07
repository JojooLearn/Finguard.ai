import '../../../../core/errors/failure.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/category_entity.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../datasources/transaction_remote_data_source.dart';

class TransactionRepositoryImpl implements TransactionRepository {
  final TransactionRemoteDataSource remoteDataSource;

  TransactionRepositoryImpl(this.remoteDataSource);

  @override
  Future<Result<List<TransactionEntity>>> getTransactions({
    DateTime? startDate,
    DateTime? endDate,
    String? categoryId,
    String? accountId,
    TransactionType? type,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final transactions = await remoteDataSource.getTransactions(
        startDate: startDate,
        endDate: endDate,
        categoryId: categoryId,
        accountId: accountId,
        type: type,
        limit: limit,
        offset: offset,
      );
      return Success(transactions);
    } catch (e) {
      return ErrorResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<TransactionEntity>> getTransactionById(String id) async {
    try {
      final transaction = await remoteDataSource.getTransactionById(id);
      return Success(transaction);
    } catch (e) {
      return ErrorResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<TransactionEntity>> createTransaction({
    required double amount,
    required TransactionType type,
    required DateTime transactionDate,
    String? categoryId,
    String? accountId,
    String? note,
    TransactionSource source = TransactionSource.manual,
    String? clientRequestId,
  }) async {
    try {
      final transaction = await remoteDataSource.createTransaction(
        amount: amount,
        type: type,
        transactionDate: transactionDate,
        categoryId: categoryId,
        accountId: accountId,
        note: note,
        source: source,
        clientRequestId: clientRequestId,
      );
      return Success(transaction);
    } catch (e) {
      return ErrorResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<TransactionEntity>> updateTransaction(TransactionEntity transaction) async {
    try {
      final updated = await remoteDataSource.updateTransaction(transaction);
      return Success(updated);
    } catch (e) {
      return ErrorResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> deleteTransaction(String id) async {
    try {
      await remoteDataSource.deleteTransaction(id);
      return const Success(null);
    } catch (e) {
      return ErrorResult(ServerFailure(e.toString()));
    }
  }
}
