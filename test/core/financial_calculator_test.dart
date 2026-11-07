import 'package:flutter_test/flutter_test.dart';
import 'package:finguard/core/utils/financial_calculator.dart';

void main() {
  group('FinancialCalculator', () {
    test('calculateNetCashFlow calculates positive and negative flows accurately', () {
      final positiveFlow = FinancialCalculator.calculateNetCashFlow(
        totalIncome: 8000000,
        totalExpense: 3750000,
      );
      expect(positiveFlow, 4250000);

      final negativeFlow = FinancialCalculator.calculateNetCashFlow(
        totalIncome: 3000000,
        totalExpense: 4500000,
      );
      expect(negativeFlow, -1500000);
    });

    test('calculateBudgetUsage safely handles limits and zero cases', () {
      final usage = FinancialCalculator.calculateBudgetUsage(
        actualExpense: 1050000,
        budgetLimit: 1500000,
      );
      expect(usage, closeTo(70.0, 0.01));

      // Over budget (112.5%)
      final overUsage = FinancialCalculator.calculateBudgetUsage(
        actualExpense: 450000,
        budgetLimit: 400000,
      );
      expect(overUsage, closeTo(112.5, 0.01));

      // Limit <= 0 returns null safely
      expect(FinancialCalculator.calculateBudgetUsage(actualExpense: 100, budgetLimit: 0), isNull);
    });

    test('calculateEmergencyFund computes target, remaining and estimated months', () {
      final result = FinancialCalculator.calculateEmergencyFund(
        essentialMonthlyExpenses: 4000000,
        targetMonths: 6,
        currentFund: 9600000,
        monthlyContribution: 2400000,
      );

      expect(result['target'], 24000000);
      expect(result['current'], 9600000);
      expect(result['remaining'], 14400000);
      expect(result['estimatedMonths'], 6);
      expect(result['progressPercent'], closeTo(40.0, 0.01));
    });

    test('calculateCompoundGrowth handles zero interest and normal compounding', () {
      // Zero interest rate
      final zeroGrowth = FinancialCalculator.calculateCompoundGrowth(
        initialPrincipal: 1000000,
        periodicContribution: 100000,
        periodicRate: 0,
        totalPeriods: 12,
      );
      expect(zeroGrowth, 2200000);

      // Positive interest
      final positiveGrowth = FinancialCalculator.calculateCompoundGrowth(
        initialPrincipal: 1000000,
        periodicContribution: 0,
        periodicRate: 0.10,
        totalPeriods: 2,
      );
      expect(positiveGrowth, closeTo(1210000, 0.01));
    });

    test('calculateDebtRatio returns null for non-positive income', () {
      final ratio = FinancialCalculator.calculateDebtRatio(
        monthlyDebtPayments: 1500000,
        monthlyIncome: 6000000,
      );
      expect(ratio, closeTo(25.0, 0.01));

      expect(FinancialCalculator.calculateDebtRatio(monthlyDebtPayments: 500, monthlyIncome: 0), isNull);
    });
  });
}
