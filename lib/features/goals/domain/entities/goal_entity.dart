import 'package:equatable/equatable.dart';

enum GoalType {
  emergencyFund,
  savings,
  debtRepayment,
  other;

  static GoalType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'emergency_fund':
        return GoalType.emergencyFund;
      case 'savings':
        return GoalType.savings;
      case 'debt_repayment':
        return GoalType.debtRepayment;
      case 'other':
      default:
        return GoalType.other;
    }
  }

  String toDbString() {
    switch (this) {
      case GoalType.emergencyFund:
        return 'emergency_fund';
      case GoalType.savings:
        return 'savings';
      case GoalType.debtRepayment:
        return 'debt_repayment';
      case GoalType.other:
        return 'other';
    }
  }

  String get displayName {
    switch (this) {
      case GoalType.emergencyFund:
        return 'Dana Darurat';
      case GoalType.savings:
        return 'Tabungan & Impian';
      case GoalType.debtRepayment:
        return 'Pelunasan Utang';
      case GoalType.other:
        return 'Lainnya';
    }
  }
}

enum GoalStatus {
  active,
  completed,
  paused,
  cancelled;

  static GoalStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'completed':
        return GoalStatus.completed;
      case 'paused':
        return GoalStatus.paused;
      case 'cancelled':
        return GoalStatus.cancelled;
      case 'active':
      default:
        return GoalStatus.active;
    }
  }

  String toDbString() => name;
}

class GoalEntity extends Equatable {
  final String id;
  final String userId;
  final String name;
  final String? description;
  final GoalType goalType;
  final double targetAmount;
  final double currentAmount;
  final String currencyCode;
  final DateTime? targetDate;
  final int priority;
  final GoalStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const GoalEntity({
    required this.id,
    required this.userId,
    required this.name,
    this.description,
    required this.goalType,
    required this.targetAmount,
    this.currentAmount = 0.0,
    this.currencyCode = 'IDR',
    this.targetDate,
    this.priority = 3,
    this.status = GoalStatus.active,
    required this.createdAt,
    required this.updatedAt,
  });

  double get progressPercentage =>
      targetAmount > 0 ? (currentAmount / targetAmount).clamp(0.0, 1.0) : 0.0;
  double get remainingAmount => (targetAmount - currentAmount).clamp(0.0, double.infinity);
  bool get isCompleted => currentAmount >= targetAmount;

  @override
  List<Object?> get props => [
        id,
        userId,
        name,
        description,
        goalType,
        targetAmount,
        currentAmount,
        currencyCode,
        targetDate,
        priority,
        status,
        createdAt,
        updatedAt,
      ];
}
