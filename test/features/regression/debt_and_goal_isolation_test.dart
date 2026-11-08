import 'package:flutter_test/flutter_test.dart';
import 'package:finguard/features/debts/domain/entities/debt_entity.dart';

void main() {
  group('DebtEntity Smart Annual Interest Tests', () {
    test('Calculates remaining amount with zero interest correctly', () {
      final now = DateTime(2026, 1, 1);
      final debt = DebtEntity(
        id: 'debt_1',
        userId: 'user_1',
        name: 'KPR',
        totalAmount: 12000000,
        monthlyPayment: 1000000,
        remainingTenorMonths: 12,
        totalTenorMonths: 12,
        paidAmount: 0,
        annualInterestRate: 0.0,
        startDate: now,
        appliedInterestAmount: 0.0,
        appliedYears: 0,
        createdAt: now,
        updatedAt: now,
      );

      expect(debt.remainingPrincipal, 12000000);
      expect(debt.remainingAmount, 12000000);
      expect(debt.progressRatio, 0.0);
    });

    test('Calculates remaining amount with applied annual interest', () {
      final startDate = DateTime(2025, 1, 1);
      final debt = DebtEntity(
        id: 'debt_2',
        userId: 'user_1',
        name: 'Kredit Mobil',
        totalAmount: 10000000,
        monthlyPayment: 1000000,
        remainingTenorMonths: 10,
        totalTenorMonths: 12,
        paidAmount: 2000000,
        annualInterestRate: 10.0, // 10% per year
        startDate: startDate,
        appliedInterestAmount: 1000000.0, // 10% of 10jt applied after 1 year
        appliedYears: 1,
        createdAt: startDate,
        updatedAt: DateTime(2026, 1, 2),
      );

      expect(debt.remainingPrincipal, 10000000); // 10 * 1jt
      expect(debt.remainingAmount, 11000000); // 10jt + 1jt applied interest
      expect(debt.appliedYears, 1);
      expect(debt.annualInterestRate, 10.0);
    });
  });
}
