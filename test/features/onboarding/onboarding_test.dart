import 'package:flutter_test/flutter_test.dart';
import 'package:finguard/features/onboarding/domain/entities/initial_setup_entity.dart';

void main() {
  group('InitialSetupEntity', () {
    test('computes totalBudgetExpense, netFreeCashflow, and ratios accurately', () {
      const setup = InitialSetupEntity(
        fullName: 'Budi Santoso',
        occupation: 'Software Engineer',
        monthlyIncome: 8000000,
        accountName: 'Bank BCA',
        initialBalance: 5000000,
        budgetFood: 2000000,
        budgetTransport: 800000,
        budgetBills: 1200000,
        budgetEntertainment: 1000000,
        emergencyFundTarget: 15000000,
        emergencyFundCurrent: 3000000,
        monthlySavingsTarget: 1500000,
      );

      // Total Budgeted Expense = 2jt + 800rb + 1.2jt + 1jt = 5.000.000
      expect(setup.totalBudgetExpense, 5000000.0);

      // Net Free Cashflow = 8jt - 5jt - 1.5jt = 1.500.000
      expect(setup.netFreeCashflow, 1500000.0);
      expect(setup.isSurplus, isTrue);

      // Needs Ratio = (2jt + 800rb + 1.2jt) / 8jt = 4.000.000 / 8.000.000 = 50%
      expect(setup.needsRatio, 50.0);

      // Wants Ratio = 1.000.000 / 8.000.000 = 12.5%
      expect(setup.wantsRatio, 12.5);

      // Savings Ratio = 1.500.000 / 8.000.000 = 18.75%
      expect(setup.savingsRatio, 18.75);
    });

    test('detects deficit when expenses and savings exceed income', () {
      const deficitSetup = InitialSetupEntity(
        fullName: 'Andi',
        occupation: 'Freelancer',
        monthlyIncome: 4000000,
        accountName: 'Dompet Tunai',
        initialBalance: 500000,
        budgetFood: 2500000,
        budgetTransport: 1000000,
        budgetBills: 1000000,
        budgetEntertainment: 500000,
        emergencyFundTarget: 10000000,
        emergencyFundCurrent: 0,
        monthlySavingsTarget: 500000,
      );

      // Total Budgeted = 5.000.000
      expect(deficitSetup.totalBudgetExpense, 5000000.0);
      // Net Cashflow = 4jt - 5jt - 500rb = -1.500.000
      expect(deficitSetup.netFreeCashflow, -1500000.0);
      expect(deficitSetup.isSurplus, isFalse);
    });
  });
}

