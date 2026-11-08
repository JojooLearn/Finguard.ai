import 'dart:math' as math;

class FinancialCalculator {
  FinancialCalculator._();

  /// 10.1 Net Cash Flow
  /// net_cash_flow = total_confirmed_income - total_confirmed_expense
  static double calculateNetCashFlow({
    required double totalIncome,
    required double totalExpense,
  }) {
    return totalIncome - totalExpense;
  }

  /// 10.1b Available Free Cash (Uang Dingin Siap Pakai - Golden Financial Rule)
  /// Uang Dingin Siap Pakai = Total Pemasukan - Total Pengeluaran Konsumsi
  ///   - Kewajiban Cicilan Belum Dibayar Bulan Ini - Total Setoran Tabungan/Dana Darurat Bulan Ini
  static double calculateAvailableFreeCash({
    required double totalIncome,
    required double totalConsumptionExpense,
    double unpaidMonthlyDebt = 0.0,
    double unpaidMonthlyDebtObligation = 0.0,
    double monthlySavingsContribution = 0.0,
    double monthlySavingsContributions = 0.0,
  }) {
    final effectiveDebt = unpaidMonthlyDebt > 0
        ? unpaidMonthlyDebt
        : unpaidMonthlyDebtObligation;
    final effectiveSavings = monthlySavingsContribution > 0
        ? monthlySavingsContribution
        : monthlySavingsContributions;
    final raw = totalIncome -
        totalConsumptionExpense -
        effectiveDebt -
        effectiveSavings;
    return math.max(0.0, raw);
  }

  /// 10.2 Budget Usage Percentage
  /// budget_usage_percent = (actual_expense / budget_limit) * 100
  /// Returns null if limit <= 0 to avoid division by zero
  static double? calculateBudgetUsage({
    required double actualExpense,
    required double budgetLimit,
  }) {
    if (budgetLimit <= 0) return null;
    return (actualExpense / budgetLimit) * 100;
  }

  /// 10.3 Emergency Fund
  /// target = essential_monthly_expenses * target_months
  /// remaining = max(0, target - current_fund)
  /// estimated_months = ceil(remaining / monthly_contribution)
  static Map<String, dynamic> calculateEmergencyFund({
    required double essentialMonthlyExpenses,
    required int targetMonths,
    required double currentFund,
    double monthlyContribution = 0,
  }) {
    final target = essentialMonthlyExpenses * targetMonths;
    final remaining = math.max(0.0, target - currentFund);

    int? estimatedMonths;
    if (monthlyContribution > 0) {
      estimatedMonths = (remaining / monthlyContribution).ceil();
    }

    final progressPercent = target > 0 ? (currentFund / target) * 100 : 0.0;

    return {
      'target': target,
      'current': currentFund,
      'remaining': remaining,
      'estimatedMonths': estimatedMonths,
      'progressPercent': progressPercent.clamp(0.0, 100.0),
    };
  }

  /// 10.4 Compound Growth
  /// FV = P0 * (1 + i)^n + C * (((1 + i)^n - 1) / i)
  /// When i = 0, FV = P0 + C * n
  static double calculateCompoundGrowth({
    required double initialPrincipal,
    required double periodicContribution,
    required double periodicRate, // e.g. 0.06 / 12
    required int totalPeriods,    // e.g. years * 12
  }) {
    if (periodicRate <= 0) {
      return initialPrincipal + (periodicContribution * totalPeriods);
    }

    final principalFV = initialPrincipal * math.pow(1 + periodicRate, totalPeriods);
    final contributionsFV = periodicContribution * ((math.pow(1 + periodicRate, totalPeriods) - 1) / periodicRate);

    return principalFV + contributionsFV;
  }

  /// 10.5 Debt-to-Income (DTI) / Cicilan Ratio
  /// ratio_percent = (monthly_debt_payments / monthly_income) * 100
  static double? calculateDebtRatio({
    required double monthlyDebtPayments,
    required double monthlyIncome,
  }) {
    if (monthlyIncome <= 0) return null;
    return (monthlyDebtPayments / monthlyIncome) * 100;
  }

  /// 10.7 Opportunity Cost
  /// future_value = amount * (1 + annual_return)^years
  static Map<String, double> calculateOpportunityCost({
    required double amount,
    double annualReturn = 0.06,
    int years = 10,
  }) {
    final fv = amount * math.pow(1 + annualReturn, years);
    final gain = fv - amount;
    return {
      'futureValue': fv,
      'potentialGain': gain,
    };
  }
}
