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

    test('resolveEffectiveIncome prioritizes recorded income over stale higher profile income', () {
      expect(
        FinancialCalculator.resolveEffectiveIncome(
          recordedMonthlyIncome: 3600000,
          profileMonthlyIncome: 4500000,
        ),
        3600000,
      );
      expect(
        FinancialCalculator.resolveEffectiveIncome(
          recordedMonthlyIncome: 0,
          profileMonthlyIncome: 4500000,
        ),
        4500000,
      );
    });

    test('Golden Financial Rule locks monthly needs commitment and keeps Uang Dingin <= Kas Cair', () {
      // Skenario 10jt: Kebutuhan Pokok 4.5jt, Cicilan 2jt, Tabungan & Darurat 2jt -> Uang Dingin 1.5jt
      final income = FinancialCalculator.resolveEffectiveIncome(
        recordedMonthlyIncome: 10000000,
        profileMonthlyIncome: 10000000,
      );

      // Awal bulan baru keluar makan Rp38.000 (sisa jatah kebutuhan pokok wajib tetap terkunci)
      final earlyMonthConsumption =
          FinancialCalculator.resolveEffectiveConsumptionExpense(
        monthlyEssentialCommitment: 4500000,
        nonDebtNeedsExpense: 38000,
      );
      expect(earlyMonthConsumption, 4500000);

      final earlyLiquidCash = FinancialCalculator.calculateLiquidCash(
        recordedMonthlyIncome: 10000000,
        recordedMonthlyExpense: 38000,
        totalOpeningBalance: 0,
      );

      final earlyFreeCash = FinancialCalculator.calculateAvailableFreeCash(
        totalIncome: income,
        totalConsumptionExpense: earlyMonthConsumption,
        unpaidMonthlyDebt: 2000000,
        monthlySavingsContribution: 2000000,
        maxCashCap: earlyLiquidCash,
      );
      expect(earlyFreeCash, 1500000);
      expect(earlyFreeCash <= earlyLiquidCash, isTrue);

      // Setelah bayar cicilan 2jt via transaksi & jajan Hiburan (wants) 500rb:
      final midMonthConsumption =
          FinancialCalculator.resolveEffectiveConsumptionExpense(
        monthlyEssentialCommitment: 4500000,
        nonDebtNeedsExpense: 38000,
        nonDebtOtherExpense: 500000,
        paidDebtExpense: 2000000,
      );
      expect(midMonthConsumption, 7000000);

      final midLiquidCash = FinancialCalculator.calculateLiquidCash(
        recordedMonthlyIncome: 10000000,
        recordedMonthlyExpense: 2538000,
        totalOpeningBalance: 0,
      );

      final midFreeCash = FinancialCalculator.calculateAvailableFreeCash(
        totalIncome: income,
        totalConsumptionExpense: midMonthConsumption,
        unpaidMonthlyDebt: 0,
        monthlySavingsContribution: 2000000,
        maxCashCap: midLiquidCash,
      );
      expect(midFreeCash, 1000000);
      expect(midFreeCash <= midLiquidCash, isTrue);
    });
  });
}
