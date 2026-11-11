import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/result/result.dart';
import '../../../../core/utils/financial_calculator.dart';
import '../../domain/entities/consultation_result_entity.dart';
import '../../domain/repositories/consultation_repository.dart';

class ConsultationRepositoryImpl implements ConsultationRepository {
  final SupabaseClient client;

  ConsultationRepositoryImpl(this.client);

  @override
  Future<Result<ConsultationResultEntity>> consultPurchase({
    required String itemName,
    required double estimatedPrice,
    String? categoryName,
  }) async {
    // Compute deterministic Golden Financial Rule metrics from DB first
    final localMetrics = await _computeGoldenRuleMetrics();

    try {
      final user = client.auth.currentUser;
      if (user != null) {
        final response = await client.functions.invoke(
          'purchase-consultation',
          body: {
            'item_name': itemName,
            'estimated_price': estimatedPrice,
            'category_name': categoryName,
          },
        );

        if (response.data != null && response.data is Map) {
          final data = Map<String, dynamic>.from(response.data as Map);
          final metrics = data['deterministic_metrics'] is Map
              ? Map<String, dynamic>.from(data['deterministic_metrics'] as Map)
              : <String, dynamic>{};

          // Enforce Golden Financial Rule on freeCash & verdict
          final serverFreeCash = (metrics['freeCash'] as num?)?.toDouble() ?? 0.0;
          final effectiveFreeCash = localMetrics.hasData
              ? localMetrics.freeCash
              : serverFreeCash;
          final effectiveRemainingCash = effectiveFreeCash - estimatedPrice;

          final serverVerdict = ConsultationVerdict.fromString(
            data['verdict']?.toString(),
          );
          ConsultationVerdict effectiveVerdict = serverVerdict;
          if (localMetrics.hasData) {
            if (estimatedPrice > effectiveFreeCash || effectiveRemainingCash < 0) {
              effectiveVerdict = ConsultationVerdict.notRecommended;
            } else if (estimatedPrice > effectiveFreeCash * 0.5) {
              effectiveVerdict = ConsultationVerdict.caution;
            } else {
              effectiveVerdict = ConsultationVerdict.affordable;
            }
          }

          String explanation =
              data['explanation']?.toString() ?? 'Tidak ada penjelasan.';
          // Prevent any badge/text mismatch if client Golden Rule verdict overrode server verdict
          if (localMetrics.hasData &&
              serverVerdict != ConsultationVerdict.insufficientData &&
              effectiveVerdict != serverVerdict) {
            final alignedLocal = await _generateLocalDeterministicAnalysis(
              itemName: itemName,
              estimatedPrice: estimatedPrice,
              categoryName: categoryName,
              metrics: localMetrics,
            );
            alignedLocal.fold(
              (localEntity) => explanation = localEntity.explanation,
              (_) {},
            );
          }

          final entity = ConsultationResultEntity(
            itemName: data['item_name']?.toString() ?? itemName,
            estimatedPrice:
                (data['estimated_price'] as num?)?.toDouble() ?? estimatedPrice,
            verdict: effectiveVerdict,
            explanation: explanation,
            opportunityCost: data['opportunity_cost']?.toString(),
            budgetWarning: data['budget_warning']?.toString(),
            freeCash: effectiveFreeCash,
            remainingCash: effectiveRemainingCash,
            priceRatioToFreeCash: effectiveFreeCash > 0
                ? (estimatedPrice / effectiveFreeCash) * 100
                : null,
            availableCash: localMetrics.hasData
                ? localMetrics.availableCash
                : ((metrics['availableCash'] as num?)?.toDouble() ?? 0.0),
          );

          return Success(entity);
        }
      }
    } catch (_) {
      // Fallback
    }

    // Local deterministic fallback complying with Golden Financial Rule (Bagian 1.2.1 & TC-16)
    return _generateLocalDeterministicAnalysis(
      itemName: itemName,
      estimatedPrice: estimatedPrice,
      categoryName: categoryName,
      metrics: localMetrics,
    );
  }

  Future<_GoldenRuleSnapshot> _computeGoldenRuleMetrics() async {
    double profileIncome = 0.0;
    double profileEssential = 0.0;
    double profileDebt = 0.0;
    double txIncome = 0.0;
    double txExpense = 0.0;
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
            '${now.year}-${now.month.toString().padLeft(2, '0')}-${lastDay.toString().padLeft(2, '0')}T23:59:59.999';

        final results = await Future.wait<dynamic>([
          client
              .from('financial_profiles')
              .select(
                'monthly_income, essential_monthly_expenses, monthly_debt_payments',
              )
              .eq('user_id', user.id)
              .maybeSingle(),
          client
              .from('transactions')
              .select('amount, transaction_type, transaction_date, note, status')
              .eq('user_id', user.id)
              .gte('transaction_date', monthStart)
              .lte('transaction_date', monthEnd),
          client
              .from('financial_goals')
              .select('name, goal_type, target_amount, current_amount, description, status')
              .eq('user_id', user.id),
          client
              .from('goal_contributions')
              .select('amount, contribution_date')
              .eq('user_id', user.id)
              .gte('contribution_date', monthStart)
              .lte('contribution_date', monthEnd),
        ]);

        final finRes = results[0] as Map<String, dynamic>?;
        if (finRes != null) {
          profileIncome = (finRes['monthly_income'] as num?)?.toDouble() ?? 0.0;
          profileEssential =
              (finRes['essential_monthly_expenses'] as num?)?.toDouble() ?? 0.0;
          profileDebt =
              (finRes['monthly_debt_payments'] as num?)?.toDouble() ?? 0.0;
        }

        final txRows = (results[1] as List?) ?? [];
        final paidDebtNotes = <String>[];
        for (final r in txRows) {
          if (r['status'] != null && r['status'] != 'confirmed') continue;
          final amt = (r['amount'] as num?)?.toDouble() ?? 0.0;
          final type = r['transaction_type'] as String? ?? 'expense';
          if (type == 'income') {
            txIncome += amt;
          } else if (type == 'expense') {
            txExpense += amt;
            final note = (r['note'] as String? ?? '').toLowerCase();
            if (note.startsWith('bayar ')) {
              paidDebtNotes.add(note);
            }
          }
        }

        final goalRows = (results[2] as List?) ?? [];
        double totalGoalCurrent = 0.0;
        int activeDebtCount = 0;
        for (final g in goalRows) {
          final gType = g['goal_type'] as String? ?? 'savings';
          final gStatus = g['status'] as String? ?? 'active';
          if (gType == 'debt_repayment') {
            if (gStatus == 'completed') continue;
            double monthlyPayment = 0.0;
            int remainingTenor = 1;
            final desc = g['description'] as String?;
            if (desc != null && desc.isNotEmpty) {
              try {
                final meta = jsonDecode(desc) as Map<String, dynamic>;
                monthlyPayment =
                    (meta['monthly_payment'] as num?)?.toDouble() ?? 0.0;
                remainingTenor =
                    (meta['remaining_tenor'] as num?)?.toInt() ?? 1;
              } catch (_) {}
            }
            if (remainingTenor > 0 && monthlyPayment > 0) {
              activeDebtCount++;
              final dName = (g['name'] as String? ?? '').toLowerCase();
              final alreadyPaid = paidDebtNotes.any(
                (n) => dName.isNotEmpty && n.contains('bayar $dName'),
              );
              if (!alreadyPaid) {
                unpaidActiveDebt += monthlyPayment;
              }
            }
          } else {
            totalGoalCurrent += (g['current_amount'] as num?)?.toDouble() ?? 0.0;
          }
        }
        if (activeDebtCount == 0 && unpaidActiveDebt == 0) {
          unpaidActiveDebt = profileDebt;
        }

        final contribRows = (results[3] as List?) ?? [];
        double contribSum = 0.0;
        for (final c in contribRows) {
          contribSum += (c['amount'] as num?)?.toDouble() ?? 0.0;
        }
        monthlySavings = contribSum > 0 ? contribSum : totalGoalCurrent;

        hasData = (profileIncome > 0 || txIncome > 0);
      } catch (_) {}
    }

    final effectiveIncome =
        txIncome > profileIncome ? txIncome : (profileIncome > 0 ? profileIncome : 5000000.0);
    final effectiveExpense =
        txExpense > 0 ? txExpense : (profileEssential > 0 ? profileEssential : 0.0);

    final freeCash = FinancialCalculator.calculateAvailableFreeCash(
      totalIncome: effectiveIncome,
      totalConsumptionExpense: effectiveExpense,
      unpaidMonthlyDebt: unpaidActiveDebt,
      monthlySavingsContribution: monthlySavings,
    );

    return _GoldenRuleSnapshot(
      hasData: hasData,
      income: effectiveIncome,
      consumptionExpense: effectiveExpense,
      unpaidDebt: unpaidActiveDebt,
      savingsContribution: monthlySavings,
      freeCash: freeCash,
      availableCash: (effectiveIncome - effectiveExpense).clamp(0.0, double.infinity),
    );
  }

  /// Safe local fallback using deterministic Golden Financial Rule figures
  Future<Result<ConsultationResultEntity>> _generateLocalDeterministicAnalysis({
    required String itemName,
    required double estimatedPrice,
    String? categoryName,
    required _GoldenRuleSnapshot metrics,
  }) async {
    final freeCash = metrics.freeCash;
    final remainingCash = freeCash - estimatedPrice;

    ConsultationVerdict verdict;
    String explanation;
    String? opportunityCost;
    String? budgetWarning;

    if (estimatedPrice > freeCash) {
      verdict = ConsultationVerdict.notRecommended;
      explanation =
          'Saran Coach: Tahan dulu rencana beli "$itemName" (Rp${_fmt(estimatedPrice)}). Berdasarkan Golden Financial Rule, uang dingin siap pakaimu bulan ini adalah Rp${_fmt(freeCash)} (Pemasukan Rp${_fmt(metrics.income)} dikurangi pengeluaran Rp${_fmt(metrics.consumptionExpense)}, kewajiban cicilan Rp${_fmt(metrics.unpaidDebt)}, dan tabungan/dana darurat Rp${_fmt(metrics.savingsContribution)}). Kalau dipaksakan beli sekarang, arus kasmu akan defisit Rp${_fmt(remainingCash.abs())}.';
      opportunityCost =
          'Dana sebesar Rp${_fmt(estimatedPrice)} setara dengan ${(estimatedPrice / 2000000).toStringAsFixed(1)} bulan alokasi celengan dana daruratmu.';
      budgetWarning =
          'Arus kas bebas akan defisit Rp${_fmt(remainingCash.abs())} jika pembelian ini dipaksakan bulan ini.';
    } else if (estimatedPrice > freeCash * 0.5) {
      verdict = ConsultationVerdict.caution;
      explanation =
          'Pertimbangkan kembali sebelum membeli "$itemName". Barang ini akan menyerap ${(estimatedPrice / freeCash * 100).toInt()}% dari uang dingin siap pakaimu bulan ini (Rp${_fmt(freeCash)}). Terapkan jeda 48 jam agar tidak mengganggu ruang kas darurat.';
      opportunityCost =
          'Pengeluaran ini bisa memperlambat pencapaian target tabungan impianmu sekitar 1 bulan.';
      budgetWarning =
          'Sisa uang dingin siap pakai tinggal Rp${_fmt(remainingCash)} untuk cadangan bulan ini.';
    } else {
      verdict = ConsultationVerdict.affordable;
      explanation =
          'Pembelian "$itemName" masih aman di kantong. Harganya hanya mengambil ${freeCash > 0 ? (estimatedPrice / freeCash * 100).toInt() : 0}% dari uang dingin siap pakaimu (Rp${_fmt(freeCash)}), dan kamu masih memiliki sisa uang dingin Rp${_fmt(remainingCash)}.';
    }

    return Success(
      ConsultationResultEntity(
        itemName: itemName,
        estimatedPrice: estimatedPrice,
        verdict: verdict,
        explanation: explanation,
        opportunityCost: opportunityCost,
        budgetWarning: budgetWarning,
        freeCash: freeCash,
        remainingCash: remainingCash,
        priceRatioToFreeCash: freeCash > 0
            ? (estimatedPrice / freeCash) * 100
            : null,
        availableCash: metrics.availableCash,
      ),
    );
  }

  String _fmt(double num) {
    return num.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
  }
}

class _GoldenRuleSnapshot {
  final bool hasData;
  final double income;
  final double consumptionExpense;
  final double unpaidDebt;
  final double savingsContribution;
  final double freeCash;
  final double availableCash;

  const _GoldenRuleSnapshot({
    required this.hasData,
    required this.income,
    required this.consumptionExpense,
    required this.unpaidDebt,
    required this.savingsContribution,
    required this.freeCash,
    required this.availableCash,
  });
}
