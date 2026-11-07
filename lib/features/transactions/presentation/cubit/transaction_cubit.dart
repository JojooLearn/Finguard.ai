import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/account_entity.dart';
import '../../domain/entities/category_entity.dart';
import '../../domain/repositories/category_and_account_repository.dart';
import '../../domain/repositories/transaction_repository.dart';
import 'transaction_state.dart';

class TransactionCubit extends Cubit<TransactionState> {
  final TransactionRepository transactionRepository;
  final CategoryRepository categoryRepository;
  final AccountRepository accountRepository;

  TransactionCubit({
    required this.transactionRepository,
    required this.categoryRepository,
    required this.accountRepository,
  }) : super(const TransactionInitial());

  Future<void> loadTransactions({TransactionType? filterType}) async {
    emit(const TransactionLoading());

    final txResult = await transactionRepository.getTransactions(type: filterType);
    final catResult = await categoryRepository.getCategories();
    final accResult = await accountRepository.getAccounts();

    txResult.fold(
      (transactions) {
        final categories = catResult.fold((c) => c, (_) => <CategoryEntity>[]);
        final accounts = accResult.fold((a) => a, (_) => <AccountEntity>[]);

        emit(TransactionLoaded(
          transactions: transactions,
          categories: categories,
          accounts: accounts,
          selectedFilter: filterType,
        ));
      },
      (failure) => emit(TransactionError(failure.message)),
    );
  }

  Future<void> addTransaction({
    required double amount,
    required TransactionType type,
    required DateTime transactionDate,
    String? categoryId,
    String? accountId,
    String? note,
  }) async {
    final result = await transactionRepository.createTransaction(
      amount: amount,
      type: type,
      transactionDate: transactionDate,
      categoryId: categoryId,
      accountId: accountId,
      note: note,
    );

    result.fold(
      (created) async {
        // Reload transactions to refresh view and totals
        final currentFilter = (state is TransactionLoaded)
            ? (state as TransactionLoaded).selectedFilter
            : null;
        await loadTransactions(filterType: currentFilter);
      },
      (failure) => emit(TransactionError(failure.message)),
    );
  }

  Future<void> deleteTransaction(String id) async {
    final result = await transactionRepository.deleteTransaction(id);

    result.fold(
      (_) async {
        final currentFilter = (state is TransactionLoaded)
            ? (state as TransactionLoaded).selectedFilter
            : null;
        await loadTransactions(filterType: currentFilter);
      },
      (failure) => emit(TransactionError(failure.message)),
    );
  }

  void reset() {
    emit(const TransactionInitial());
  }
}
