import 'dart:math' as math;

class FinancialCalculator {
  FinancialCalculator._();

  /// 10.1 Net Cash Flow (Sisa Uang Bersih di Dompet Utama)
  /// net_cash_flow = total_confirmed_income - total_confirmed_expense - net_savings_transfer
  static double calculateNetCashFlow({
    required double totalIncome,
    required double totalExpense,
    double savingsTransfer = 0.0,
  }) {
    return totalIncome - totalExpense - savingsTransfer;
  }

  /// 10.1b Available Free Cash (Uang Dingin Siap Pakai - Golden Financial Rule)
  /// Uang Dingin Siap Pakai = Pemasukan Efektif - Komitmen Kebutuhan Pokok & Konsumsi
  ///   - Kewajiban Cicilan Belum Dibayar Bulan Ini - Setoran Neto Tabungan/Dana Darurat Bulan Ini
  /// Jika [maxCashCap] diberikan (saat kas cair riil tercatat), hasil dibatasi <= maxCashCap.
  static double calculateAvailableFreeCash({
    required double totalIncome,
    required double totalConsumptionExpense,
    double unpaidMonthlyDebt = 0.0,
    double unpaidMonthlyDebtObligation = 0.0,
    double monthlySavingsContribution = 0.0,
    double monthlySavingsContributions = 0.0,
    double? maxCashCap,
  }) {
    final effectiveDebt = unpaidMonthlyDebt > 0
        ? unpaidMonthlyDebt
        : unpaidMonthlyDebtObligation;
    final effectiveSavings = monthlySavingsContribution != 0
        ? monthlySavingsContribution
        : monthlySavingsContributions;
    final raw = totalIncome -
        totalConsumptionExpense -
        effectiveDebt -
        effectiveSavings;
    final freeCash = math.max(0.0, raw);
    if (maxCashCap != null) {
      return math.min(freeCash, math.max(0.0, maxCashCap));
    }
    return freeCash;
  }

  /// Catatan kontribusi saldo awal historis dari onboarding/migrasi agar tidak memotong arus kas bulan ini.
  static bool isInitialSeedContributionNote(String? note) {
    final normalized = (note ?? '').trim().toLowerCase();
    return normalized == 'saldo awal dana darurat' ||
        normalized == 'saldo awal tercatat';
  }

  /// Klasifikasi pos kebutuhan pokok ('needs') dari allocationType atau nama kategori.
  static bool isNeedsCategory({
    String? allocationType,
    String? categoryName,
  }) {
    final alloc = (allocationType ?? '').trim().toLowerCase();
    if (alloc == 'needs') return true;
    if (alloc == 'wants' ||
        alloc == 'savings' ||
        alloc == 'savings_debt' ||
        alloc == 'savingsdebt') {
      return false;
    }
    final name = (categoryName ?? '').toLowerCase();
    return RegExp(
      r'makan|minum|food|transport|bensin|ojol|tagihan|utilitas|listrik|air|sewa|kos|kesehatan|sehat|pokok',
    ).hasMatch(name);
  }

  /// Prioritaskan pemasukan transaksi aktual bulan ini; fallback ke profil jika belum ada transaksi masuk.
  static double resolveEffectiveIncome({
    required double recordedMonthlyIncome,
    required double profileMonthlyIncome,
  }) {
    return recordedMonthlyIncome > 0
        ? recordedMonthlyIncome
        : profileMonthlyIncome;
  }

  /// Komitmen konsumsi bulanan: mencadangkan penuh kebutuhan pokok bulanan
  /// tanpa menghitung ganda pembayaran cicilan yang sudah dicatat sebagai transaksi.
  static double resolveEffectiveConsumptionExpense({
    required double monthlyEssentialCommitment,
    required double nonDebtNeedsExpense,
    double nonDebtOtherExpense = 0.0,
    double paidDebtExpense = 0.0,
  }) {
    return paidDebtExpense +
        math.max(nonDebtNeedsExpense, monthlyEssentialCommitment) +
        nonDebtOtherExpense;
  }

  /// Saldo kas cair riil di dompet utama saat ini (setelah belanja & transfer ke tabungan/dana darurat),
  /// menghindari hitung ganda opening balance yg diisi gaji awal.
  static double calculateLiquidCash({
    required double recordedMonthlyIncome,
    required double recordedMonthlyExpense,
    required double totalOpeningBalance,
    double netSavingsTransfer = 0.0,
  }) {
    var liquidCash =
        recordedMonthlyIncome - recordedMonthlyExpense - netSavingsTransfer;
    if (totalOpeningBalance > recordedMonthlyIncome) {
      liquidCash += (totalOpeningBalance - recordedMonthlyIncome);
    }
    return math.max(0.0, liquidCash);
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
