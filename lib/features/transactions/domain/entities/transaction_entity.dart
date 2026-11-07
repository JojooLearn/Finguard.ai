import 'package:equatable/equatable.dart';
import 'account_entity.dart';
import 'category_entity.dart';

enum TransactionSource {
  manual,
  chat,
  importSource;

  static TransactionSource fromString(String value) {
    switch (value.toLowerCase()) {
      case 'chat':
        return TransactionSource.chat;
      case 'import':
        return TransactionSource.importSource;
      case 'manual':
      default:
        return TransactionSource.manual;
    }
  }

  String toDbString() {
    switch (this) {
      case TransactionSource.chat:
        return 'chat';
      case TransactionSource.importSource:
        return 'import';
      case TransactionSource.manual:
        return 'manual';
    }
  }
}

enum TransactionStatus {
  confirmed,
  voided;

  static TransactionStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'voided':
        return TransactionStatus.voided;
      case 'confirmed':
      default:
        return TransactionStatus.confirmed;
    }
  }

  String toDbString() => name;
}

class TransactionEntity extends Equatable {
  final String id;
  final String userId;
  final String? accountId;
  final String? categoryId;
  final TransactionType transactionType;
  final double amount;
  final String currencyCode;
  final DateTime transactionDate;
  final String? note;
  final TransactionSource source;
  final TransactionStatus status;
  final String? aiIntent;
  final double? aiCategoryConfidence;
  final String? clientRequestId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  // Joined/denormalized relations for presentation convenience
  final CategoryEntity? category;
  final AccountEntity? account;

  const TransactionEntity({
    required this.id,
    required this.userId,
    this.accountId,
    this.categoryId,
    required this.transactionType,
    required this.amount,
    this.currencyCode = 'IDR',
    required this.transactionDate,
    this.note,
    this.source = TransactionSource.manual,
    this.status = TransactionStatus.confirmed,
    this.aiIntent,
    this.aiCategoryConfidence,
    this.clientRequestId,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.category,
    this.account,
  });

  TransactionEntity copyWith({
    String? id,
    String? userId,
    String? accountId,
    String? categoryId,
    TransactionType? transactionType,
    double? amount,
    String? currencyCode,
    DateTime? transactionDate,
    String? note,
    TransactionSource? source,
    TransactionStatus? status,
    String? aiIntent,
    double? aiCategoryConfidence,
    String? clientRequestId,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    CategoryEntity? category,
    AccountEntity? account,
  }) {
    return TransactionEntity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      accountId: accountId ?? this.accountId,
      categoryId: categoryId ?? this.categoryId,
      transactionType: transactionType ?? this.transactionType,
      amount: amount ?? this.amount,
      currencyCode: currencyCode ?? this.currencyCode,
      transactionDate: transactionDate ?? this.transactionDate,
      note: note ?? this.note,
      source: source ?? this.source,
      status: status ?? this.status,
      aiIntent: aiIntent ?? this.aiIntent,
      aiCategoryConfidence: aiCategoryConfidence ?? this.aiCategoryConfidence,
      clientRequestId: clientRequestId ?? this.clientRequestId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      category: category ?? this.category,
      account: account ?? this.account,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        accountId,
        categoryId,
        transactionType,
        amount,
        currencyCode,
        transactionDate,
        note,
        source,
        status,
        aiIntent,
        aiCategoryConfidence,
        clientRequestId,
        createdAt,
        updatedAt,
        deletedAt,
        category,
        account,
      ];
}
