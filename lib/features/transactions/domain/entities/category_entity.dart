import 'package:equatable/equatable.dart';

enum TransactionType {
  income,
  expense;

  static TransactionType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'income':
        return TransactionType.income;
      case 'expense':
      default:
        return TransactionType.expense;
    }
  }

  String toDbString() => name;
}

enum AllocationType {
  needs,
  wants,
  savingsDebt,
  other;

  static AllocationType? fromString(String? value) {
    if (value == null) return null;
    switch (value.toLowerCase()) {
      case 'needs':
        return AllocationType.needs;
      case 'wants':
        return AllocationType.wants;
      case 'savings_debt':
        return AllocationType.savingsDebt;
      case 'other':
      default:
        return AllocationType.other;
    }
  }

  String toDbString() {
    switch (this) {
      case AllocationType.needs:
        return 'needs';
      case AllocationType.wants:
        return 'wants';
      case AllocationType.savingsDebt:
        return 'savings_debt';
      case AllocationType.other:
        return 'other';
    }
  }

  String get displayName {
    switch (this) {
      case AllocationType.needs:
        return 'Kebutuhan Pokok (Needs)';
      case AllocationType.wants:
        return 'Keinginan (Wants)';
      case AllocationType.savingsDebt:
        return 'Tabungan & Cicilan';
      case AllocationType.other:
        return 'Lainnya';
    }
  }
}

class CategoryEntity extends Equatable {
  final String id;
  final String? userId; // null for system category
  final String name;
  final TransactionType transactionType;
  final AllocationType? allocationType;
  final String? iconKey;
  final String? colorHex;
  final bool isSystem;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CategoryEntity({
    required this.id,
    this.userId,
    required this.name,
    required this.transactionType,
    this.allocationType,
    this.iconKey,
    this.colorHex,
    this.isSystem = false,
    this.isArchived = false,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [
        id,
        userId,
        name,
        transactionType,
        allocationType,
        iconKey,
        colorHex,
        isSystem,
        isArchived,
        createdAt,
        updatedAt,
      ];
}
