import 'package:equatable/equatable.dart';
import '../../domain/entities/account_entity.dart';
import '../../domain/entities/category_entity.dart';
import '../../domain/entities/transaction_entity.dart';

abstract class TransactionState extends Equatable {
  const TransactionState();

  @override
  List<Object?> get props => [];
}

class TransactionInitial extends TransactionState {
  const TransactionInitial();
}

class TransactionLoading extends TransactionState {
  const TransactionLoading();
}

class TransactionLoaded extends TransactionState {
  final List<TransactionEntity> transactions;
  final List<CategoryEntity> categories;
  final List<AccountEntity> accounts;
  final TransactionType? selectedFilter;

  const TransactionLoaded({
    required this.transactions,
    this.categories = const [],
    this.accounts = const [],
    this.selectedFilter,
  });

  double get totalIncome => transactions
      .where((t) => t.transactionType == TransactionType.income && t.status == TransactionStatus.confirmed)
      .fold(0.0, (sum, t) => sum + t.amount);

  double get totalExpense => transactions
      .where((t) => t.transactionType == TransactionType.expense && t.status == TransactionStatus.confirmed)
      .fold(0.0, (sum, t) => sum + t.amount);

  double get netCashFlow => totalIncome - totalExpense;

  TransactionLoaded copyWith({
    List<TransactionEntity>? transactions,
    List<CategoryEntity>? categories,
    List<AccountEntity>? accounts,
    TransactionType? selectedFilter,
    bool clearFilter = false,
  }) {
    return TransactionLoaded(
      transactions: transactions ?? this.transactions,
      categories: categories ?? this.categories,
      accounts: accounts ?? this.accounts,
      selectedFilter: clearFilter ? null : (selectedFilter ?? this.selectedFilter),
    );
  }

  @override
  List<Object?> get props => [transactions, categories, accounts, selectedFilter];
}

class TransactionOperationSuccess extends TransactionState {
  final String message;

  const TransactionOperationSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class TransactionError extends TransactionState {
  final String message;

  const TransactionError(this.message);

  @override
  List<Object?> get props => [message];
}
