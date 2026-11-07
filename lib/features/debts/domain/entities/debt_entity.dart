import 'package:equatable/equatable.dart';

class DebtEntity extends Equatable {
  final String id;
  final String userId;
  final String name;
  final double totalAmount;
  final double monthlyPayment;
  final int remainingTenorMonths;
  final int totalTenorMonths;
  final int dueDay;
  final double paidAmount;
  final bool isCompleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DebtEntity({
    required this.id,
    required this.userId,
    required this.name,
    required this.totalAmount,
    required this.monthlyPayment,
    required this.remainingTenorMonths,
    required this.totalTenorMonths,
    this.dueDay = 10,
    required this.paidAmount,
    this.isCompleted = false,
    required this.createdAt,
    required this.updatedAt,
  });

  double get remainingAmount =>
      (remainingTenorMonths * monthlyPayment).clamp(0.0, double.infinity);

  double get progressRatio {
    if (totalTenorMonths <= 0) return 1.0;
    final paidTenors = totalTenorMonths - remainingTenorMonths;
    return (paidTenors / totalTenorMonths).clamp(0.0, 1.0);
  }

  DebtEntity copyWith({
    String? id,
    String? userId,
    String? name,
    double? totalAmount,
    double? monthlyPayment,
    int? remainingTenorMonths,
    int? totalTenorMonths,
    int? dueDay,
    double? paidAmount,
    bool? isCompleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DebtEntity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      totalAmount: totalAmount ?? this.totalAmount,
      monthlyPayment: monthlyPayment ?? this.monthlyPayment,
      remainingTenorMonths:
          remainingTenorMonths ?? this.remainingTenorMonths,
      totalTenorMonths: totalTenorMonths ?? this.totalTenorMonths,
      dueDay: dueDay ?? this.dueDay,
      paidAmount: paidAmount ?? this.paidAmount,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        name,
        totalAmount,
        monthlyPayment,
        remainingTenorMonths,
        totalTenorMonths,
        dueDay,
        paidAmount,
        isCompleted,
        createdAt,
        updatedAt,
      ];
}
