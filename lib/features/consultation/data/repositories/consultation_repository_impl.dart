import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/result/result.dart';
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
          final data = response.data as Map<String, dynamic>;
          final metrics =
              (data['deterministic_metrics'] as Map<String, dynamic>?) ?? {};

          final entity = ConsultationResultEntity(
            itemName: data['item_name']?.toString() ?? itemName,
            estimatedPrice:
                (data['estimated_price'] as num?)?.toDouble() ?? estimatedPrice,
            verdict: ConsultationVerdict.fromString(
              data['verdict']?.toString(),
            ),
            explanation:
                data['explanation']?.toString() ?? 'Tidak ada penjelasan.',
            opportunityCost: data['opportunity_cost']?.toString(),
            budgetWarning: data['budget_warning']?.toString(),
            freeCash: (metrics['freeCash'] as num?)?.toDouble() ?? 0.0,
            remainingCash:
                (metrics['remainingCash'] as num?)?.toDouble() ?? 0.0,
            priceRatioToFreeCash: (metrics['priceRatioToFreeCash'] as num?)
                ?.toDouble(),
            availableCash:
                (metrics['availableCash'] as num?)?.toDouble() ?? 0.0,
          );

          return Success(entity);
        }
      }
    } catch (_) {
      // Fallback
    }

    // Local deterministic fallback complying with PRD Section 15.4 & Phase 4
    return _generateLocalDeterministicAnalysis(
      itemName: itemName,
      estimatedPrice: estimatedPrice,
      categoryName: categoryName,
    );
  }

  /// Safe local fallback using realistic deterministic profile figures
  Future<Result<ConsultationResultEntity>> _generateLocalDeterministicAnalysis({
    required String itemName,
    required double estimatedPrice,
    String? categoryName,
  }) async {
    double income = 5000000.0;
    double essential = 2500000.0;
    double debt = 0.0;

    final user = client.auth.currentUser;
    if (user != null) {
      try {
        final finRes = await client
            .from('financial_profiles')
            .select('monthly_income, monthly_debt_payments')
            .eq('user_id', user.id)
            .maybeSingle();
        if (finRes != null) {
          final inc = (finRes['monthly_income'] as num?)?.toDouble() ?? 0.0;
          if (inc > 0) {
            income = inc;
            essential = (income * 0.50);
          }
          debt = (finRes['monthly_debt_payments'] as num?)?.toDouble() ?? 0.0;
        }
      } catch (_) {}
    }

    final freeCash = income - essential - debt;
    final remainingCash = freeCash - estimatedPrice;

    ConsultationVerdict verdict;
    String explanation;
    String? opportunityCost;
    String? budgetWarning;

    if (estimatedPrice > freeCash) {
      verdict = ConsultationVerdict.notRecommended;
      explanation =
          'Saran Coach: Mending tahan dulu tod, beli "$itemName" (Rp${_fmt(estimatedPrice)}). Harganya melebihi uang dingin bulananmu cok (Rp${_fmt(freeCash)}). Kalau dipaksakan, dompetmu bakal langsung boncos tekor Rp${_fmt(remainingCash.abs())}!';
      opportunityCost =
          'Duit segini setara dengan ${(estimatedPrice / 2000000).toStringAsFixed(1)} bulan alokasi celengan dana daruratmu.';
      budgetWarning =
          'Dompet bakal tekor sebesar Rp${_fmt(remainingCash.abs())} kalau kamu checkout bulan ini.';
    } else if (estimatedPrice > freeCash * 0.5) {
      verdict = ConsultationVerdict.caution;
      explanation =
          'Pikir-pikir dulu mbut! Barang ini bakal nguras ${(estimatedPrice / freeCash * 100).toInt()}% dari uang dingin bulananmu njing. Terapkan jeda 48 jam biar ga nyesel beli barang impulsif.';
      opportunityCost =
          'Pengeluaran ini bisa memperlambat pencapaian target tabungan impianmu sekitar 1 bulan.';
      budgetWarning =
          'Sisa uang dingin kamu tinggal Rp${_fmt(remainingCash)} buat jaga-jaga keperluan mendadak ya mbut.';
    } else {
      verdict = ConsultationVerdict.affordable;
      explanation =
          'Gas beli tod! Pembelian "$itemName" aman banget di kantong. Beban belanja cuma makan ${(estimatedPrice / freeCash * 100).toInt()}% dari uang dinginmu, dan masih nyisa Rp${_fmt(remainingCash)} buat tabungan.';
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
