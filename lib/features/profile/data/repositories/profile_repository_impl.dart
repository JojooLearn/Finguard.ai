import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/result/result.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../../budgets/domain/repositories/budget_repository.dart';
import '../../domain/entities/profile_entity.dart';
import '../../domain/repositories/profile_repository.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final SupabaseClient client;
  final BudgetRepository budgetRepository;
  final AuthRepository authRepository;

  ProfileEntity? _cachedProfile;

  ProfileRepositoryImpl({
    required this.client,
    required this.budgetRepository,
    required this.authRepository,
  });

  @override
  Future<Result<ProfileEntity>> getProfile() async {
    try {
      final user = client.auth.currentUser;
      if (user != null) {
        final profileRes = await client
            .from('profiles')
            .select()
            .eq('id', user.id)
            .maybeSingle();

        final finRes = await client
            .from('financial_profiles')
            .select()
            .eq('user_id', user.id)
            .maybeSingle();

        final displayName = profileRes?['display_name'] as String? ??
            user.userMetadata?['full_name'] as String? ??
            user.email?.split('@').first ??
            'Pengguna FinGuard';

        final income = (finRes?['monthly_income'] as num?)?.toDouble() ?? 0.0;
        final debt = (finRes?['monthly_debt_payments'] as num?)?.toDouble() ?? 0.0;
        final strictness = (finRes?['strictness_level'] as num?)?.toInt() ?? 3;
        final essential = income > 0 ? (income * 0.50) : 0.0;

        _cachedProfile = ProfileEntity(
          id: user.id,
          displayName: displayName,
          email: user.email ?? '',
          currencyCode: profileRes?['currency_code'] ?? 'IDR',
          timezone: profileRes?['timezone'] ?? 'Asia/Jakarta',
          monthlyIncome: income,
          essentialExpenses: essential,
          monthlyDebt: debt,
          strictnessLevel: strictness,
          onboardingCompletedAt: profileRes?['onboarding_completed_at'] != null
              ? DateTime.tryParse(profileRes!['onboarding_completed_at'])?.toLocal()
              : null,
          createdAt: profileRes?['created_at'] != null
              ? DateTime.tryParse(profileRes!['created_at'])?.toLocal()
              : null,
          updatedAt: profileRes?['updated_at'] != null
              ? DateTime.tryParse(profileRes!['updated_at'])?.toLocal()
              : null,
        );

        return Success(_cachedProfile!);
      }
    } catch (_) {}

    // Fallback to cached or default
    final user = authRepository.getCurrentUser();
    final fallback = _cachedProfile ??
        ProfileEntity(
          id: user?.id ?? 'local_user',
          displayName: user?.displayName ?? 'Pengguna FinGuard',
          email: user?.email ?? 'user@finguard.id',
          monthlyIncome: 5000000.0,
          essentialExpenses: 2500000.0,
          strictnessLevel: 3,
        );
    return Success(fallback);
  }

  @override
  Future<Result<ProfileEntity>> updateProfile({
    String? displayName,
    double? monthlyIncome,
    double? essentialExpenses,
    double? monthlyDebt,
    int? strictnessLevel,
  }) async {
    try {
      final user = client.auth.currentUser;
      if (user != null) {
        final nowIso = DateTime.now().toIso8601String();

        if (displayName != null && displayName.trim().isNotEmpty) {
          await client.from('profiles').update({
            'display_name': displayName.trim(),
            'updated_at': nowIso,
          }).eq('id', user.id);
          authRepository.updateCurrentUserDisplayName(displayName.trim());
        }

        final finUpdates = <String, dynamic>{
          'updated_at': nowIso,
        };
        if (monthlyIncome != null) {
          finUpdates['monthly_income'] = monthlyIncome;
        }
        if (monthlyDebt != null) {
          finUpdates['monthly_debt_payments'] = monthlyDebt;
        }
        if (strictnessLevel != null) {
          finUpdates['strictness_level'] = strictnessLevel;
        }

        if (finUpdates.length > 1) {
          await client
              .from('financial_profiles')
              .update(finUpdates)
              .eq('user_id', user.id);
        }

        if (monthlyIncome != null && monthlyIncome > 0) {
          await _syncSalaryTransaction(user.id, monthlyIncome, nowIso);
        }

        return await getProfile();
      }
    } catch (e) {
      return ErrorResult(ServerFailure(e.toString()));
    }

    if (_cachedProfile != null) {
      _cachedProfile = _cachedProfile!.copyWith(
        displayName: displayName,
        monthlyIncome: monthlyIncome,
        essentialExpenses: essentialExpenses,
        monthlyDebt: monthlyDebt,
        strictnessLevel: strictnessLevel,
        updatedAt: DateTime.now(),
      );
      return Success(_cachedProfile!);
    }

    return await getProfile();
  }

  @override
  Future<Result<void>> recalculateBlueprintFromIncome({
    required double monthlyIncome,
    int? strictnessLevel,
  }) async {
    try {
      final user = client.auth.currentUser;
      if (user != null) {
        final now = DateTime.now();
        final nowIso = now.toIso8601String();
        final periodStart = DateTime(now.year, now.month, 1);
        final periodEnd = DateTime(now.year, now.month + 1, 0);

        // 1. Update financial profiles
        final updates = <String, dynamic>{
          'monthly_income': monthlyIncome,
          'updated_at': nowIso,
        };
        if (strictnessLevel != null) {
          updates['strictness_level'] = strictnessLevel;
        }
        await client
            .from('financial_profiles')
            .update(updates)
            .eq('user_id', user.id);

        // 2. Compute 50/30/20 proportions
        final foodLimit = (monthlyIncome * 0.30).roundToDouble();
        final transLimit = (monthlyIncome * 0.10).roundToDouble();
        final billsLimit = (monthlyIncome * 0.10).roundToDouble();
        final entLimit = (monthlyIncome * 0.30).roundToDouble();
        final essentialTotal = foodLimit + transLimit + billsLimit;
        final emergencyFundTarget = essentialTotal * 3;

        // 3. Update or set budgets in database
        final catRes = await client
            .from('categories')
            .select('id, name')
            .or('is_system.eq.true,user_id.eq.${user.id}');

        final catList = (catRes as List).cast<Map<String, dynamic>>();

        String? findCatId(String keyword) {
          for (final c in catList) {
            final name = (c['name'] as String? ?? '').toLowerCase();
            if (name.contains(keyword.toLowerCase())) {
              return c['id'] as String?;
            }
          }
          return null;
        }

        final foodId = findCatId('makan');
        final transId = findCatId('transport');
        final billsId = findCatId('tagihan');
        final entId = findCatId('hiburan');

        if (foodLimit > 0) {
          await budgetRepository.setBudget(
            categoryId: foodId ?? 'cat_sys_makan',
            categoryName: 'Makan & Minum',
            limitAmount: foodLimit,
            periodStart: periodStart,
            periodEnd: periodEnd,
          );
        }
        if (transLimit > 0) {
          await budgetRepository.setBudget(
            categoryId: transId ?? 'cat_sys_transport',
            categoryName: 'Transportasi',
            limitAmount: transLimit,
            periodStart: periodStart,
            periodEnd: periodEnd,
          );
        }
        if (billsLimit > 0) {
          await budgetRepository.setBudget(
            categoryId: billsId ?? 'cat_sys_tagihan',
            categoryName: 'Tagihan & Utilitas',
            limitAmount: billsLimit,
            periodStart: periodStart,
            periodEnd: periodEnd,
          );
        }
        if (entLimit > 0) {
          await budgetRepository.setBudget(
            categoryId: entId ?? 'cat_sys_hiburan',
            categoryName: 'Hiburan',
            limitAmount: entLimit,
            periodStart: periodStart,
            periodEnd: periodEnd,
          );
        }

        // 4. Update Dana Darurat target in financial_goals
        try {
          await client
              .from('financial_goals')
              .update({
                'target_amount': emergencyFundTarget,
                'updated_at': nowIso,
              })
              .eq('user_id', user.id)
              .ilike('name', '%dana darurat%');
        } catch (_) {}

        // 5. Sync current month's salary transaction so Home reflects new income
        if (monthlyIncome > 0) {
          await _syncSalaryTransaction(user.id, monthlyIncome, nowIso);
        }

        // Invalidate cached profile
        await getProfile();
        return const Success(null);
      }
    } catch (e) {
      return ErrorResult(ServerFailure(e.toString()));
    }
    return const Success(null);
  }

  Future<void> _syncSalaryTransaction(
    String userId,
    double monthlyIncome,
    String nowIso,
  ) async {
    try {
      final now = DateTime.now();
      final periodStart = DateTime(now.year, now.month, 1);
      final periodEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

      final existingTxsRes = await client
          .from('transactions')
          .select('id, description, note, amount, transaction_type')
          .eq('user_id', userId)
          .eq('transaction_type', 'income')
          .gte('transaction_date', periodStart.toIso8601String())
          .lte('transaction_date', periodEnd.toIso8601String());

      if (existingTxsRes.isNotEmpty) {
        final txList = (existingTxsRes as List).cast<Map<String, dynamic>>();
        final salaryTx = txList.firstWhere(
          (t) {
            final desc = ((t['description'] ?? t['note'] ?? '') as String).toLowerCase();
            return desc.contains('gaji') || desc.contains('salary') || desc.contains('pendapatan');
          },
          orElse: () => txList.first,
        );
        await client.from('transactions').update({
          'amount': monthlyIncome,
          'updated_at': nowIso,
        }).eq('id', salaryTx['id']);
      } else {
        // Query categories to find income category
        final catRes = await client
            .from('categories')
            .select('id, name')
            .or('is_system.eq.true,user_id.eq.$userId');
        final catList = (catRes as List).cast<Map<String, dynamic>>();
        final incCat = catList.where((c) {
          final name = (c['name'] as String? ?? '').toLowerCase();
          return name.contains('gaji') || name.contains('pendapatan') || name.contains('income');
        }).firstOrNull;

        await client.from('transactions').insert({
          'user_id': userId,
          'amount': monthlyIncome,
          'transaction_type': 'income',
          'transaction_date': periodStart.toIso8601String(),
          'category_id': incCat?['id'],
          'note': 'Gaji Bulanan',
          'description': 'Gaji Bulanan',
          'status': 'confirmed',
        });
      }
    } catch (_) {}
  }

  @override
  void clearCache() {
    _cachedProfile = null;
  }
}
