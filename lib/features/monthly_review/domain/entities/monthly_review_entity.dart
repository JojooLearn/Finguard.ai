import 'package:equatable/equatable.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';

class MonthlyReviewMetrics extends Equatable {
  final double totalIncome;
  final double totalExpense;
  final double netCashFlow;
  final int transactionCount;
  final int incomeTransactionCount;
  final int expenseTransactionCount;
  final double savingsRate;
  final Map<String, double> categoryBreakdown;

  const MonthlyReviewMetrics({
    required this.totalIncome,
    required this.totalExpense,
    required this.netCashFlow,
    required this.transactionCount,
    this.incomeTransactionCount = 0,
    this.expenseTransactionCount = 0,
    this.savingsRate = 0.0,
    this.categoryBreakdown = const {},
  });

  @override
  List<Object?> get props => [
        totalIncome,
        totalExpense,
        netCashFlow,
        transactionCount,
        incomeTransactionCount,
        expenseTransactionCount,
        savingsRate,
        categoryBreakdown,
      ];
}

class MonthlyReviewEntity extends Equatable {
  final String id;
  final String periodStart;
  final String periodEnd;
  final String currencyCode;
  final MonthlyReviewMetrics metrics;
  final String narrative;
  final String calculationVersion;
  final DateTime? generatedAt;
  final List<TransactionEntity> transactions;

  const MonthlyReviewEntity({
    required this.id,
    required this.periodStart,
    required this.periodEnd,
    this.currencyCode = 'IDR',
    required this.metrics,
    required this.narrative,
    this.calculationVersion = 'v1',
    this.generatedAt,
    this.transactions = const [],
  });

  @override
  List<Object?> get props => [
        id,
        periodStart,
        periodEnd,
        currencyCode,
        metrics,
        narrative,
        calculationVersion,
        generatedAt,
        transactions,
      ];
}
