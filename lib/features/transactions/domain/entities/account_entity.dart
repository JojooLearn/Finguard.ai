import 'package:equatable/equatable.dart';

enum AccountType {
  cash,
  bank,
  eWallet,
  savings,
  investment;

  static AccountType fromString(String value) {
    switch (value) {
      case 'cash':
        return AccountType.cash;
      case 'bank':
        return AccountType.bank;
      case 'e_wallet':
        return AccountType.eWallet;
      case 'savings':
        return AccountType.savings;
      case 'investment':
        return AccountType.investment;
      default:
        return AccountType.cash;
    }
  }

  String toDbString() {
    switch (this) {
      case AccountType.cash:
        return 'cash';
      case AccountType.bank:
        return 'bank';
      case AccountType.eWallet:
        return 'e_wallet';
      case AccountType.savings:
        return 'savings';
      case AccountType.investment:
        return 'investment';
    }
  }

  String get displayName {
    switch (this) {
      case AccountType.cash:
        return 'Tunai / Cash';
      case AccountType.bank:
        return 'Rekening Bank';
      case AccountType.eWallet:
        return 'E-Wallet';
      case AccountType.savings:
        return 'Tabungan Khusus';
      case AccountType.investment:
        return 'Investasi';
    }
  }
}

class AccountEntity extends Equatable {
  final String id;
  final String userId;
  final String name;
  final AccountType accountType;
  final String currencyCode;
  final double openingBalance;
  final bool isDefault;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AccountEntity({
    required this.id,
    required this.userId,
    required this.name,
    required this.accountType,
    this.currencyCode = 'IDR',
    this.openingBalance = 0.0,
    this.isDefault = false,
    this.isArchived = false,
    required this.createdAt,
    required this.updatedAt,
  });

  AccountEntity copyWith({
    String? id,
    String? userId,
    String? name,
    AccountType? accountType,
    String? currencyCode,
    double? openingBalance,
    bool? isDefault,
    bool? isArchived,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AccountEntity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      accountType: accountType ?? this.accountType,
      currencyCode: currencyCode ?? this.currencyCode,
      openingBalance: openingBalance ?? this.openingBalance,
      isDefault: isDefault ?? this.isDefault,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        name,
        accountType,
        currencyCode,
        openingBalance,
        isDefault,
        isArchived,
        createdAt,
        updatedAt,
      ];
}
