import 'package:equatable/equatable.dart';

class BudgetEntity extends Equatable {
  final String id;
  final String userId;
  final String categoryId;
  final DateTime periodStart;
  final DateTime periodEnd;
  final double limitAmount;
  final String currencyCode;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined calculation fields
  final double spentAmount;
  final String? categoryName;
  final String? categoryIcon;
  final String? categoryColor;

  const BudgetEntity({
    required this.id,
    required this.userId,
    required this.categoryId,
    required this.periodStart,
    required this.periodEnd,
    required this.limitAmount,
    this.currencyCode = 'IDR',
    required this.createdAt,
    required this.updatedAt,
    this.spentAmount = 0.0,
    this.categoryName,
    this.categoryIcon,
    this.categoryColor,
  });

  double get remainingAmount => limitAmount - spentAmount;
  double get usagePercentage =>
      limitAmount > 0 ? (spentAmount / limitAmount) : 0.0;
  bool get isExceeded => spentAmount > limitAmount;

  @override
  List<Object?> get props => [
        id,
        userId,
        categoryId,
        periodStart,
        periodEnd,
        limitAmount,
        currencyCode,
        createdAt,
        updatedAt,
        spentAmount,
        categoryName,
        categoryIcon,
        categoryColor,
      ];
}
