import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/result/result.dart';
import '../../../../core/utils/golden_rule_metrics.dart';
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
    final localMetrics = await fetchGoldenRuleMetrics(
      client,
      fallbackIncomeWhenUnauthenticated: 5000000.0,
    );

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

  /// Safe local fallback using deterministic Golden Financial Rule figures
  Future<Result<ConsultationResultEntity>> _generateLocalDeterministicAnalysis({
    required String itemName,
    required double estimatedPrice,
    String? categoryName,
    required GoldenRuleMetrics metrics,
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
