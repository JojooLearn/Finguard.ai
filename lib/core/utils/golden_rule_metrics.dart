import 'dart:convert';
import 'dart:math' as math;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'financial_calculator.dart';

/// Snapshot Golden Financial Rule yang sinkron dengan Edge Function `_shared/financial_context.ts`.
class GoldenRuleMetrics {
  final bool hasData;
  final double income;
  final double consumptionExpense;
  final double unpaidDebt;
  final double savingsContribution;
  final double freeCash;
  final double availableCash;

  const GoldenRuleMetrics({
    required this.hasData,
    required this.income,
    required this.consumptionExpense,
    required this.unpaidDebt,
    required this.savingsContribution,
    required this.freeCash,
    required this.availableCash,
  });
}

Future<dynamic> _safeQuery(Future<dynamic> future, dynamic fallback) async {
  try {
    return await future;
  } catch (_) {
    return fallback;
  }
}

/// Mengambil metrik Golden Financial Rule langsung dari Supabase secara paralel.
Future<GoldenRuleMetrics> fetchGoldenRuleMetrics(
  SupabaseClient client, {
  double fallbackIncomeWhenUnauthenticated = 0.0,
}) async {
  double profileIncome = 0.0;
  double profileEssential = 0.0;
  double profileDebt = 0.0;
  double txIncome = 0.0;
  double txExpense = 0.0;
  double totalOpeningBalance = 0.0;
  double activeNeedsBudgetTotal = 0.0;
  double paidDebtTxExpense = 0.0;
  double nonDebtNeedsExpense = 0.0;
  double nonDebtOtherExpense = 0.0;
  double unpaidActiveDebt = 0.0;
  double monthlySavings = 0.0;
  bool hasData = false;

  final user = client.auth.currentUser;
  if (user != null) {
    try {
      final now = DateTime.now();
      final monthStart =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-01';
      final lastDay = DateTime(now.year, now.month + 1, 0).day;
      final monthEnd =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${lastDay.toString().padLeft(2, '0')}';

      final results = await Future.wait<dynamic>([
        _safeQuery(
          client
              .from('financial_profiles')
              .select(
                'monthly_income, essential_monthly_expenses, monthly_debt_payments',
              )
              .eq('user_id', user.id)
              .maybeSingle(),
          null,
        ),
        _safeQuery(
          client
              .from('transactions')
              .select(
                'amount, transaction_type, transaction_date, note, status, categories(name, allocation_type)',
              )
              .eq('user_id', user.id)
              .gte('transaction_date', monthStart)
              .lte('transaction_date', '${monthEnd}T23:59:59.999'),
          const <dynamic>[],
        ),
        _safeQuery(
          client
              .from('financial_goals')
              .select('name, goal_type, target_amount, description, status')
              .eq('user_id', user.id),
          const <dynamic>[],
        ),
        _safeQuery(
          client
              .from('goal_contributions')
              .select('amount, contribution_date, note')
              .eq('user_id', user.id)
              .gte('contribution_date', monthStart)
              .lte('contribution_date', monthEnd),
          const <dynamic>[],
        ),
        _safeQuery(
          client
              .from('accounts')
              .select('opening_balance')
              .eq('user_id', user.id)
              .eq('is_archived', false),
          const <dynamic>[],
        ),
        _safeQuery(
          client
              .from('budgets')
              .select(
                'limit_amount, period_start, period_end, categories(name, allocation_type)',
              )
              .eq('user_id', user.id),
          const <dynamic>[],
        ),
      ]);

      final finRes = results[0] as Map<String, dynamic>?;
      if (finRes != null) {
        profileIncome = (finRes['monthly_income'] as num?)?.toDouble() ?? 0.0;
        profileEssential =
            (finRes['essential_monthly_expenses'] as num?)?.toDouble() ?? 0.0;
        profileDebt =
            (finRes['monthly_debt_payments'] as num?)?.toDouble() ?? 0.0;
      }

      for (final acc in (results[4] as List?) ?? const []) {
        totalOpeningBalance +=
            (acc['opening_balance'] as num?)?.toDouble() ?? 0.0;
      }

      for (final b in (results[5] as List?) ?? const []) {
        final pStart = b['period_start']?.toString().split('T').first;
        final pEnd = b['period_end']?.toString().split('T').first;
        if (pStart != null && pEnd != null) {
          if (pStart.compareTo(monthEnd) > 0 ||
              pEnd.compareTo(monthStart) < 0) {
            continue;
          }
        }
        final cat = b['categories'] as Map<String, dynamic>?;
        final catName = cat?['name'] as String?;
        final allocType = cat?['allocation_type'] as String?;
        if (FinancialCalculator.isNeedsCategory(
          allocationType: allocType,
          categoryName: catName,
        )) {
          activeNeedsBudgetTotal +=
              (b['limit_amount'] as num?)?.toDouble() ?? 0.0;
        }
      }

      final goalRows = (results[2] as List?) ?? const [];
      final debtNamesLower = <String>[];
      final paidDebtNotes = <String>[];
      final txRows = (results[1] as List?) ?? const [];

      for (final r in txRows) {
        if (r['status'] != null && r['status'] != 'confirmed') continue;
        final type = r['transaction_type'] as String? ?? 'expense';
        if (type == 'expense') {
          final note = (r['note'] as String? ?? '').toLowerCase();
          if (note.startsWith('bayar ')) {
            paidDebtNotes.add(note);
          }
        }
      }

      int totalDebtRows = 0;
      int activeDebtCount = 0;
      for (final g in goalRows) {
        final gType = g['goal_type'] as String? ?? 'savings';
        if (gType != 'debt_repayment') continue;
        totalDebtRows++;
        final dName = (g['name'] as String? ?? '').toLowerCase();
        if (dName.isNotEmpty) {
          debtNamesLower.add(dName);
        }

        final gStatus = g['status'] as String? ?? 'active';
        if (gStatus == 'completed') continue;

        double monthlyPayment = 0.0;
        int remainingTenor = 1;
        final desc = g['description'] as String?;
        if (desc != null && desc.isNotEmpty) {
          try {
            final meta = jsonDecode(desc) as Map<String, dynamic>;
            monthlyPayment =
                (meta['monthly_payment'] as num?)?.toDouble() ?? 0.0;
            remainingTenor = (meta['remaining_tenor'] as num?)?.toInt() ?? 1;
          } catch (_) {}
        }
        if (remainingTenor > 0 && monthlyPayment > 0) {
          activeDebtCount++;
          final alreadyPaid = paidDebtNotes.any(
            (n) => dName.isNotEmpty && n.contains('bayar $dName'),
          );
          if (!alreadyPaid) {
            unpaidActiveDebt += monthlyPayment;
          }
        }
      }
      if (activeDebtCount == 0 && totalDebtRows == 0 && unpaidActiveDebt == 0) {
        unpaidActiveDebt = profileDebt;
      }

      for (final r in txRows) {
        if (r['status'] != null && r['status'] != 'confirmed') continue;
        final amt = (r['amount'] as num?)?.toDouble() ?? 0.0;
        final type = r['transaction_type'] as String? ?? 'expense';
        if (type == 'income') {
          txIncome += amt;
        } else if (type == 'expense') {
          txExpense += amt;
          final noteLower = (r['note'] as String? ?? '').toLowerCase();
          final isPaidDebt = debtNamesLower.any(
            (dName) => dName.isNotEmpty && noteLower.contains('bayar $dName'),
          );
          if (isPaidDebt) {
            paidDebtTxExpense += amt;
          } else {
            final cat = r['categories'] as Map<String, dynamic>?;
            final isNeeds = FinancialCalculator.isNeedsCategory(
              allocationType: cat?['allocation_type'] as String?,
              categoryName: cat?['name'] as String?,
            );
            if (isNeeds) {
              nonDebtNeedsExpense += amt;
            } else {
              nonDebtOtherExpense += amt;
            }
          }
        }
      }

      double contribSum = 0.0;
      for (final c in (results[3] as List?) ?? const []) {
        final note = c['note']?.toString();
        if (FinancialCalculator.isInitialSeedContributionNote(note)) continue;
        contribSum += (c['amount'] as num?)?.toDouble() ?? 0.0;
      }
      monthlySavings = contribSum;

      hasData = profileIncome > 0 || txIncome > 0;
    } catch (_) {}
  }

  final effectiveIncome = user == null && !hasData
      ? fallbackIncomeWhenUnauthenticated
      : FinancialCalculator.resolveEffectiveIncome(
          recordedMonthlyIncome: txIncome,
          profileMonthlyIncome: profileIncome,
        );

  final monthlyEssentialCommitment = activeNeedsBudgetTotal > 0
      ? activeNeedsBudgetTotal
      : profileEssential;

  final effectiveExpense =
      FinancialCalculator.resolveEffectiveConsumptionExpense(
    monthlyEssentialCommitment: monthlyEssentialCommitment,
    nonDebtNeedsExpense: nonDebtNeedsExpense,
    nonDebtOtherExpense: nonDebtOtherExpense,
    paidDebtExpense: paidDebtTxExpense,
  );

  final liquidCash = FinancialCalculator.calculateLiquidCash(
    recordedMonthlyIncome: txIncome,
    recordedMonthlyExpense: txExpense,
    totalOpeningBalance: totalOpeningBalance,
    netSavingsTransfer: monthlySavings,
  );

  final hasRealCashTracking =
      txIncome > 0 || txExpense > 0 || totalOpeningBalance > 0;

  final freeCash = FinancialCalculator.calculateAvailableFreeCash(
    totalIncome: effectiveIncome,
    totalConsumptionExpense: effectiveExpense,
    unpaidMonthlyDebt: unpaidActiveDebt,
    monthlySavingsContribution: monthlySavings,
    maxCashCap: hasRealCashTracking ? liquidCash : null,
  );

  return GoldenRuleMetrics(
    hasData: hasData,
    income: effectiveIncome,
    consumptionExpense: effectiveExpense,
    unpaidDebt: unpaidActiveDebt,
    savingsContribution: math.max(0.0, monthlySavings),
    freeCash: freeCash,
    availableCash: hasRealCashTracking
        ? liquidCash
        : math.max(0.0, effectiveIncome - effectiveExpense - monthlySavings),
  );
}

