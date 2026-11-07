class InitialSetupEntity {
  final String fullName;
  final String occupation;
  final double monthlyIncome;
  final int dependentsCount;
  final double monthlyDebtPayments;
  final int strictnessLevel; // 1-5 (PRD v3.0 Bab 5)
  final String accountName;
  final double initialBalance;

  // Monthly Budgets
  final double budgetFood;
  final double budgetTransport;
  final double budgetBills;
  final double budgetEntertainment;

  // Goals & Emergency Fund
  final double emergencyFundTarget;
  final double emergencyFundCurrent;
  final double monthlySavingsTarget;

  const InitialSetupEntity({
    required this.fullName,
    required this.occupation,
    required this.monthlyIncome,
    this.dependentsCount = 0,
    this.monthlyDebtPayments = 0,
    this.strictnessLevel = 3,
    required this.accountName,
    required this.initialBalance,
    required this.budgetFood,
    required this.budgetTransport,
    required this.budgetBills,
    required this.budgetEntertainment,
    required this.emergencyFundTarget,
    required this.emergencyFundCurrent,
    required this.monthlySavingsTarget,
  });

  double get totalBudgetExpense =>
      budgetFood + budgetTransport + budgetBills + budgetEntertainment;

  double get netFreeCashflow =>
      monthlyIncome - totalBudgetExpense - monthlySavingsTarget - monthlyDebtPayments;

  bool get isSurplus => netFreeCashflow >= 0;

  double get needsRatio =>
      monthlyIncome > 0 ? ((budgetFood + budgetTransport + budgetBills) / monthlyIncome * 100) : 0.0;

  double get wantsRatio =>
      monthlyIncome > 0 ? (budgetEntertainment / monthlyIncome * 100) : 0.0;

  double get savingsRatio =>
      monthlyIncome > 0 ? (monthlySavingsTarget / monthlyIncome * 100) : 0.0;
}
