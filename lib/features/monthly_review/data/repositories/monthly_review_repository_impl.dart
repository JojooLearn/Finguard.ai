import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/formatters/currency_formatter.dart';
import '../../../../core/result/result.dart';
import '../../../transactions/domain/entities/category_entity.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../../transactions/domain/repositories/transaction_repository.dart';
import '../../domain/entities/monthly_review_entity.dart';
import '../../domain/repositories/monthly_review_repository.dart';

class MonthlyReviewRepositoryImpl implements MonthlyReviewRepository {
  final SupabaseClient client;
  final TransactionRepository? transactionRepository;

  MonthlyReviewRepositoryImpl(this.client, [this.transactionRepository]);

  @override
  Future<Result<MonthlyReviewEntity>> getOrGenerateMonthlyReview({
    required DateTime periodStart,
    required DateTime periodEnd,
    bool forceRegenerate = false,
  }) async {
    final startStr = DateFormat('yyyy-MM-dd').format(periodStart);
    final endStr = DateFormat('yyyy-MM-dd').format(periodEnd);

    try {
      final user = client.auth.currentUser;
      if (user != null) {
        // Fetch current period confirmed transactions to attach to entity
        List<TransactionEntity> confirmedTxs = [];
        if (transactionRepository != null) {
          final txRes = await transactionRepository!.getTransactions(
            startDate: periodStart,
            endDate: periodEnd,
          );
          txRes.fold((txs) {
            confirmedTxs = txs
                .where((t) => t.status == TransactionStatus.confirmed)
                .toList();
          }, (_) {});
        }

        // 1. Check existing saved review if not forcing regenerate
        if (!forceRegenerate) {
          final existing = await client
              .from('monthly_reviews')
              .select()
              .eq('user_id', user.id)
              .eq('period_start', startStr)
              .eq('period_end', endStr)
              .order('created_at', ascending: false)
              .maybeSingle();

          if (existing != null) {
            final snapshot =
                existing['metrics_snapshot'] as Map<String, dynamic>? ?? {};
            final totalIncome =
                (snapshot['totalIncome'] as num?)?.toDouble() ?? 0.0;
            final totalExpense =
                (snapshot['totalExpense'] as num?)?.toDouble() ?? 0.0;
            final netFlow =
                (snapshot['netCashFlow'] as num?)?.toDouble() ??
                (totalIncome - totalExpense);
            final txCount =
                (snapshot['transactionCount'] as num?)?.toInt() ?? 0;
            final incCount =
                (snapshot['incomeTransactionCount'] as num?)?.toInt() ??
                (totalIncome > 0 ? 1 : 0);
            final expCount =
                (snapshot['expenseTransactionCount'] as num?)?.toInt() ??
                (txCount > incCount ? txCount - incCount : 0);
            final savingsRate = totalIncome > 0
                ? ((netFlow / totalIncome) * 100).clamp(-100.0, 100.0)
                : 0.0;

            final rawBreakdown =
                snapshot['categoryBreakdown'] as Map<String, dynamic>? ?? {};
            final Map<String, double> categoryBreakdown = {};
            for (final entry in rawBreakdown.entries) {
              categoryBreakdown[entry.key] = (entry.value as num).toDouble();
            }

            // Always synchronize breakdown from actual confirmed transactions if empty
            if (categoryBreakdown.isEmpty && confirmedTxs.isNotEmpty) {
              for (final t in confirmedTxs) {
                if (t.transactionType == TransactionType.expense) {
                  final cat = t.category?.name ??
                      (t.note != null && t.note!.trim().isNotEmpty
                          ? t.note!.trim()
                          : 'Belanja & Kebutuhan');
                  categoryBreakdown[cat] = (categoryBreakdown[cat] ?? 0.0) + t.amount;
                }
              }
            }
            if (categoryBreakdown.isEmpty && totalExpense > 0) {
              categoryBreakdown['Belanja & Pengeluaran'] = totalExpense;
            }

            return Success(
              MonthlyReviewEntity(
                id: existing['id'],
                periodStart: existing['period_start'],
                periodEnd: existing['period_end'],
                currencyCode: existing['currency_code'] ?? 'IDR',
                metrics: MonthlyReviewMetrics(
                  totalIncome: totalIncome,
                  totalExpense: totalExpense,
                  netCashFlow: netFlow,
                  transactionCount: txCount,
                  incomeTransactionCount: incCount,
                  expenseTransactionCount: expCount,
                  savingsRate: savingsRate,
                  categoryBreakdown: categoryBreakdown,
                ),
                narrative:
                    existing['narrative'] ?? 'Belum ada narasi evaluasi.',
                calculationVersion: existing['calculation_version'] ?? 'v1',
                generatedAt: existing['generated_at'] != null
                    ? DateTime.parse(existing['generated_at']).toLocal()
                    : null,
                transactions: confirmedTxs,
              ),
            );
          }
        }

        // 2. Invoke Edge Function monthly-review with realistic timeout (12s for Gemini generation)
        try {
          final response = await client.functions
              .invoke(
                'monthly-review',
                body: {'period_start': startStr, 'period_end': endStr},
              )
              .timeout(const Duration(seconds: 12));

          if (response.data != null && response.data is Map) {
            final data = response.data as Map<String, dynamic>;
            final snapshot =
                data['metricsSnapshot'] as Map<String, dynamic>? ?? {};
            final totalIncome =
                (snapshot['totalIncome'] as num?)?.toDouble() ?? 0.0;
            final totalExpense =
                (snapshot['totalExpense'] as num?)?.toDouble() ?? 0.0;
            final netFlow =
                (snapshot['netCashFlow'] as num?)?.toDouble() ??
                (totalIncome - totalExpense);
            final txCount =
                (snapshot['transactionCount'] as num?)?.toInt() ?? 0;
            final incCount =
                (snapshot['incomeTransactionCount'] as num?)?.toInt() ??
                (totalIncome > 0 ? 1 : 0);
            final expCount =
                (snapshot['expenseTransactionCount'] as num?)?.toInt() ??
                (txCount > incCount ? txCount - incCount : 0);
            final savingsRate = totalIncome > 0
                ? ((netFlow / totalIncome) * 100).clamp(-100.0, 100.0)
                : 0.0;

            final rawBreakdown =
                snapshot['categoryBreakdown'] as Map<String, dynamic>? ?? {};
            final Map<String, double> categoryBreakdown = {};
            for (final entry in rawBreakdown.entries) {
              categoryBreakdown[entry.key] = (entry.value as num).toDouble();
            }

            // Always synchronize breakdown from actual confirmed transactions if empty
            if (categoryBreakdown.isEmpty && confirmedTxs.isNotEmpty) {
              for (final t in confirmedTxs) {
                if (t.transactionType == TransactionType.expense) {
                  final cat = t.category?.name ??
                      (t.note != null && t.note!.trim().isNotEmpty
                          ? t.note!.trim()
                          : 'Belanja & Kebutuhan');
                  categoryBreakdown[cat] = (categoryBreakdown[cat] ?? 0.0) + t.amount;
                }
              }
            }
            if (categoryBreakdown.isEmpty && totalExpense > 0) {
              categoryBreakdown['Belanja & Pengeluaran'] = totalExpense;
            }

            final narrativeText =
                data['narrative']?.toString() ?? 'Evaluasi berhasil dihasilkan.';

            // Ensure guaranteed persistence to monthly_reviews table
            try {
              await client.from('monthly_reviews').upsert(
                {
                  'user_id': user.id,
                  'period_start': startStr,
                  'period_end': endStr,
                  'currency_code': 'IDR',
                  'metrics_snapshot': {
                    'totalIncome': totalIncome,
                    'totalExpense': totalExpense,
                    'netCashFlow': netFlow,
                    'transactionCount': txCount,
                    'incomeTransactionCount': incCount,
                    'expenseTransactionCount': expCount,
                    'savingsRate': savingsRate,
                    'categoryBreakdown': categoryBreakdown,
                  },
                  'narrative': narrativeText,
                  'calculation_version': 'v1',
                  'generated_at': DateTime.now().toIso8601String(),
                },
                onConflict: 'user_id,period_start,period_end',
              );
            } catch (_) {}

            return Success(
              MonthlyReviewEntity(
                id: 'review_${DateTime.now().millisecondsSinceEpoch}',
                periodStart: startStr,
                periodEnd: endStr,
                metrics: MonthlyReviewMetrics(
                  totalIncome: totalIncome,
                  totalExpense: totalExpense,
                  netCashFlow: netFlow,
                  transactionCount: txCount,
                  incomeTransactionCount: incCount,
                  expenseTransactionCount: expCount,
                  savingsRate: savingsRate,
                  categoryBreakdown: categoryBreakdown,
                ),
                narrative: narrativeText,
                calculationVersion: data['calculation_version'] ?? 'v1',
                generatedAt: DateTime.now(),
                transactions: confirmedTxs,
              ),
            );
          }
        } catch (_) {
          // Timeout or function unreachable, seamlessly fall back to local computation
        }
      }
    } catch (_) {}

    return _generateLocalDeterministicReview(
      startStr,
      endStr,
      periodStart,
      periodEnd,
    );
  }

  Future<Result<MonthlyReviewEntity>> _generateLocalDeterministicReview(
    String startStr,
    String endStr,
    DateTime periodStart,
    DateTime periodEnd,
  ) async {
    double totalIncome = 0.0;
    double totalExpense = 0.0;
    int transactionCount = 0;
    int incomeTransactionCount = 0;
    int expenseTransactionCount = 0;
    final Map<String, double> categoryExpense = {};
    List<TransactionEntity> confirmedTxs = [];

    if (transactionRepository != null) {
      final txRes = await transactionRepository!.getTransactions(
        startDate: periodStart,
        endDate: periodEnd,
      );
      txRes.fold((txs) {
        confirmedTxs = txs
            .where((t) => t.status == TransactionStatus.confirmed)
            .toList();
        transactionCount = confirmedTxs.length;
        for (final t in confirmedTxs) {
          if (t.transactionType == TransactionType.income) {
            totalIncome += t.amount;
            incomeTransactionCount++;
          } else {
            totalExpense += t.amount;
            expenseTransactionCount++;
            final cat = t.category?.name ??
                (t.note != null && t.note!.trim().isNotEmpty
                    ? t.note!.trim()
                    : 'Belanja & Kebutuhan');
            categoryExpense[cat] = (categoryExpense[cat] ?? 0.0) + t.amount;
          }
        }
      }, (_) {});
    }

    if (transactionCount == 0) {
      // Zero-Tolerance: No fake transactions if user has no data yet
      final user = client.auth.currentUser;
      if (user != null) {
        try {
          final fp = await client
              .from('financial_profiles')
              .select('monthly_income')
              .eq('user_id', user.id)
              .maybeSingle();
          if (fp != null && fp['monthly_income'] != null) {
            totalIncome = (fp['monthly_income'] as num).toDouble();
          }
        } catch (_) {}
      }
    }

    final netFlow = totalIncome - totalExpense;
    final savingsRate = totalIncome > 0
        ? ((netFlow / totalIncome) * 100).clamp(-100.0, 100.0)
        : 0.0;

    String topCategoryStr = '';
    if (categoryExpense.isNotEmpty) {
      final sorted = categoryExpense.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final top = sorted.first;
      topCategoryStr =
          ' Pengeluaran terbesar berada pada pos ${top.key} (${CurrencyFormatter.format(top.value)}).';
    }

    final isSurplus = netFlow >= 0;
    final narrative = transactionCount == 0
        ? 'Belum ada transaksi sama sekali njir! Dompet lu sepi amat kayak kuburan, catat buruan biar ketauan borosnya!'
        : expenseTransactionCount == 0
        ? 'Anjayy, pemasukan lu masih utuh 100% belum kepake belanja sama sekali njir! Pertahankan njing, atau langsung alokasikan jatahnya ke Dana Darurat biar aman terkendali!'
        : isSurplus
        ? 'Gokil, tumben lu kaga dongo! Masih nyisa duit dingin ${CurrencyFormatter.format(netFlow)} (${savingsRate.toStringAsFixed(0)}%).$topCategoryStr Langsung lempar ke Dana Darurat tod, jangan diabisin buat flexing!'
        : 'Goblok boncos anjir! Pengeluaran lu jebol tekor blok ${CurrencyFormatter.format(netFlow.abs())}.$topCategoryStr Sadar diri tod, rem gaya hidup lu sebelum jadi beban keluarga!';

    final user = client.auth.currentUser;
    if (user != null) {
      try {
        final existingReview = await client
            .from('monthly_reviews')
            .select('id')
            .eq('user_id', user.id)
            .eq('period_start', startStr)
            .eq('period_end', endStr)
            .maybeSingle();

        Map<String, dynamic> saved;
        if (existingReview != null) {
          saved = await client
              .from('monthly_reviews')
              .update({
                'currency_code': 'IDR',
                'metrics_snapshot': {
                  'totalIncome': totalIncome,
                  'totalExpense': totalExpense,
                  'netCashFlow': netFlow,
                  'transactionCount': transactionCount,
                  'incomeTransactionCount': incomeTransactionCount,
                  'expenseTransactionCount': expenseTransactionCount,
                  'savingsRate': savingsRate,
                  'categoryBreakdown': categoryExpense,
                },
                'narrative': narrative,
                'calculation_version': 'v1',
                'generated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', existingReview['id'])
              .select()
              .single();
        } else {
          final insertData = {
            'user_id': user.id,
            'period_start': startStr,
            'period_end': endStr,
            'currency_code': 'IDR',
            'metrics_snapshot': {
              'totalIncome': totalIncome,
              'totalExpense': totalExpense,
              'netCashFlow': netFlow,
              'transactionCount': transactionCount,
              'incomeTransactionCount': incomeTransactionCount,
              'expenseTransactionCount': expenseTransactionCount,
              'savingsRate': savingsRate,
              'categoryBreakdown': categoryExpense,
            },
            'narrative': narrative,
            'calculation_version': 'v1',
            'generated_at': DateTime.now().toIso8601String(),
          };
          saved = await client
              .from('monthly_reviews')
              .insert(insertData)
              .select()
              .single();
        }

        return Success(
          MonthlyReviewEntity(
            id: saved['id'],
            periodStart: saved['period_start'],
            periodEnd: saved['period_end'],
            currencyCode: saved['currency_code'] ?? 'IDR',
            metrics: MonthlyReviewMetrics(
              totalIncome: totalIncome,
              totalExpense: totalExpense,
              netCashFlow: netFlow,
              transactionCount: transactionCount,
              incomeTransactionCount: incomeTransactionCount,
              expenseTransactionCount: expenseTransactionCount,
              savingsRate: savingsRate,
              categoryBreakdown: categoryExpense,
            ),
            narrative: saved['narrative'],
            calculationVersion: saved['calculation_version'] ?? 'v1',
            generatedAt: DateTime.parse(saved['generated_at']).toLocal(),
            transactions: confirmedTxs,
          ),
        );
      } catch (_) {
        // Fallback to local entity if database upsert fails
      }
    }

    return Success(
      MonthlyReviewEntity(
        id: 'local_review_${startStr}_$endStr',
        periodStart: startStr,
        periodEnd: endStr,
        metrics: MonthlyReviewMetrics(
          totalIncome: totalIncome,
          totalExpense: totalExpense,
          netCashFlow: netFlow,
          transactionCount: transactionCount,
          incomeTransactionCount: incomeTransactionCount,
          expenseTransactionCount: expenseTransactionCount,
          savingsRate: savingsRate,
          categoryBreakdown: categoryExpense,
        ),
        narrative: narrative,
        calculationVersion: 'v1',
        generatedAt: DateTime.now(),
        transactions: confirmedTxs,
      ),
    );
  }
}
