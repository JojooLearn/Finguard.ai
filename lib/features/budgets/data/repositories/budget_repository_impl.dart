import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/budget_entity.dart';
import '../../domain/repositories/budget_repository.dart';

class BudgetRepositoryImpl implements BudgetRepository {
  final SupabaseClient client;

  // Zero-Tolerance: No dummy seed budgets. Empty store by default.
  final List<BudgetEntity> _localBudgets = [];
  String? _lastUserId;

  BudgetRepositoryImpl(this.client);

  @override
  void clearCache() {
    _localBudgets.clear();
    _lastUserId = null;
  }

  /// Normalizes category names so 'Gaya Hidup & Hiburan' and 'Hiburan'
  /// or duplicate category rows with identical names map to a single canonical key.
  String _normalizeCategoryKey(String? rawName) {
    final lower = (rawName ?? '').trim().toLowerCase();
    if (lower.isEmpty) return 'anggaran belanja';
    if (lower.contains('makan')) return 'makan & minum';
    if (lower.contains('transport')) return 'transportasi';
    if (lower.contains('tagihan') || lower.contains('utilitas')) {
      return 'tagihan & utilitas';
    }
    if (lower == 'gaya hidup & hiburan' || lower == 'hiburan') {
      return 'hiburan';
    }
    return lower;
  }

  String _canonicalDisplayName(String? rawName) {
    final key = _normalizeCategoryKey(rawName);
    switch (key) {
      case 'makan & minum':
        return 'Makan & Minum';
      case 'transportasi':
        return 'Transportasi';
      case 'tagihan & utilitas':
        return 'Tagihan & Utilitas';
      case 'hiburan':
        return 'Hiburan';
      default:
        return (rawName != null && rawName.trim().isNotEmpty)
            ? rawName.trim()
            : 'Anggaran Belanja';
    }
  }

  @override
  Future<Result<List<BudgetEntity>>> getBudgets({
    required DateTime periodStart,
    required DateTime periodEnd,
  }) async {
    try {
      final user = client.auth.currentUser;
      if (user != null) {
        if (_lastUserId != user.id) {
          _localBudgets.clear();
          _lastUserId = user.id;
        }

        final startStr = periodStart.toIso8601String().split('T').first;
        final endStr = periodEnd.toIso8601String().split('T').first;

        // 1. Fetch budgets for user and period (overlapping period query)
        List<dynamic> budgetResponse = [];
        try {
          final res = await client
              .from('budgets')
              .select('*, categories(*)')
              .eq('user_id', user.id)
              .lte('period_start', endStr)
              .gte('period_end', startStr);
          budgetResponse = res as List;
        } catch (_) {
          try {
            final res = await client
                .from('budgets')
                .select('*')
                .eq('user_id', user.id)
                .lte('period_start', endStr)
                .gte('period_end', startStr);
            budgetResponse = res as List;
          } catch (_) {}
        }

        // 2. Fetch all expenses in this period to compute actual spent per category ID and category name
        final Map<String, double> categorySpentById = {};
        final Map<String, double> categorySpentByNameKey = {};
        try {
          final txResponse = await client
              .from('transactions')
              .select('category_id, amount, categories(name)')
              .eq('user_id', user.id)
              .eq('transaction_type', 'expense')
              .isFilter('deleted_at', null)
              .gte('transaction_date', startStr)
              .lte('transaction_date', endStr);

          for (final tx in (txResponse as List)) {
            final catId = tx['category_id'] as String?;
            final amt = (tx['amount'] as num).toDouble();
            if (catId != null) {
              categorySpentById[catId] = (categorySpentById[catId] ?? 0.0) + amt;
            }
            final catObj = tx['categories'];
            String? txCatName;
            if (catObj is Map) {
              txCatName = catObj['name'] as String?;
            } else if (catObj is List && catObj.isNotEmpty) {
              txCatName = catObj.first['name'] as String?;
            }
            if (txCatName != null && txCatName.isNotEmpty) {
              final normKey = _normalizeCategoryKey(txCatName);
              categorySpentByNameKey[normKey] =
                  (categorySpentByNameKey[normKey] ?? 0.0) + amt;
            }
          }
        } catch (_) {}

        final rawBudgets = budgetResponse.map((json) {
          final catId = json['category_id'] as String;
          final cat = json['categories'];
          String? resolvedCatName;
          if (cat is Map) {
            resolvedCatName = cat['name'] as String?;
          } else if (cat is List && cat.isNotEmpty) {
            resolvedCatName = cat.first['name'] as String?;
          }
          final uuidRegex = RegExp(
              r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
          if (resolvedCatName == null || uuidRegex.hasMatch(resolvedCatName)) {
            final localMatch =
                _localBudgets.where((b) => b.categoryId == catId).firstOrNull;
            resolvedCatName = localMatch?.categoryName ?? 'Anggaran Belanja';
          }

          final canonicalName = _canonicalDisplayName(resolvedCatName);
          final normKey = _normalizeCategoryKey(canonicalName);
          final spentById = categorySpentById[catId] ?? 0.0;
          final spentByName = categorySpentByNameKey[normKey] ?? 0.0;
          final effectiveSpent = spentByName > spentById ? spentByName : spentById;

          return BudgetEntity(
            id: json['id'],
            userId: json['user_id'],
            categoryId: catId,
            periodStart: DateTime.parse(json['period_start']),
            periodEnd: DateTime.parse(json['period_end']),
            limitAmount: (json['limit_amount'] as num).toDouble(),
            currencyCode: json['currency_code'] ?? 'IDR',
            createdAt: DateTime.parse(json['created_at']).toLocal(),
            updatedAt: DateTime.parse(json['updated_at']).toLocal(),
            spentAmount: effectiveSpent,
            categoryName: canonicalName,
            categoryIcon: cat is Map ? cat['icon_key'] : null,
            categoryColor: cat is Map ? cat['color_hex'] : null,
          );
        }).toList();

        // 3. Deduplicate budgets by canonical category key and auto-clean duplicate rows in Supabase
        final Map<String, BudgetEntity> uniqueBudgetsByKey = {};
        final List<String> duplicateBudgetIdsToDelete = [];

        for (final b in rawBudgets) {
          final key = _normalizeCategoryKey(b.categoryName);
          if (!uniqueBudgetsByKey.containsKey(key)) {
            uniqueBudgetsByKey[key] = b;
          } else {
            final existing = uniqueBudgetsByKey[key]!;
            // Keep the row that has spentAmount > 0 or was updated more recently
            if (b.spentAmount > existing.spentAmount) {
              duplicateBudgetIdsToDelete.add(existing.id);
              uniqueBudgetsByKey[key] = b;
            } else {
              duplicateBudgetIdsToDelete.add(b.id);
            }
          }
        }

        if (duplicateBudgetIdsToDelete.isNotEmpty) {
          try {
            await client
                .from('budgets')
                .delete()
                .inFilter('id', duplicateBudgetIdsToDelete);
          } catch (_) {}
        }

        final budgets = uniqueBudgetsByKey.values.toList();

        if (budgets.isNotEmpty) {
          _localBudgets.clear();
          _localBudgets.addAll(budgets);
          return Success(budgets);
        } else {
          // Only auto-heal if the user has already completed onboarding
          // (Prevents race condition with OnboardingRepositoryImpl.completeOnboarding!)
          bool onboardingDone = false;
          double income = 0;
          try {
            final prof = await client
                .from('profiles')
                .select('onboarding_completed_at')
                .eq('id', user.id)
                .maybeSingle();
            onboardingDone =
                prof != null && prof['onboarding_completed_at'] != null;

            if (onboardingDone) {
              final fp = await client
                  .from('financial_profiles')
                  .select('monthly_income')
                  .eq('user_id', user.id)
                  .maybeSingle();
              if (fp != null && fp['monthly_income'] != null) {
                income = (fp['monthly_income'] as num).toDouble();
              }
            }
          } catch (_) {}

          if (onboardingDone && income > 0) {
            final food = (income * 0.30).roundToDouble();
            final trans = (income * 0.10).roundToDouble();
            final bills = (income * 0.10).roundToDouble();
            final ent = (income * 0.30).roundToDouble();

            await setBudget(
              categoryId: 'cat_sys_makan',
              categoryName: 'Makan & Minum',
              limitAmount: food,
              periodStart: periodStart,
              periodEnd: periodEnd,
            );
            await setBudget(
              categoryId: 'cat_sys_transport',
              categoryName: 'Transportasi',
              limitAmount: trans,
              periodStart: periodStart,
              periodEnd: periodEnd,
            );
            await setBudget(
              categoryId: 'cat_sys_tagihan',
              categoryName: 'Tagihan & Utilitas',
              limitAmount: bills,
              periodStart: periodStart,
              periodEnd: periodEnd,
            );
            await setBudget(
              categoryId: 'cat_sys_hiburan',
              categoryName: 'Hiburan',
              limitAmount: ent,
              periodStart: periodStart,
              periodEnd: periodEnd,
            );
          }

          if (_localBudgets.isNotEmpty) {
            return Success(List.unmodifiable(_localBudgets));
          }
        }
      }
    } catch (_) {
      // Fallback seamlessly to local budgets
    }

    return Success(List.unmodifiable(_localBudgets));
  }

  @override
  Future<Result<BudgetEntity>> setBudget({
    required String categoryId,
    String? categoryName,
    required double limitAmount,
    required DateTime periodStart,
    required DateTime periodEnd,
  }) async {
    final uuidRegex = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    String humanName = _canonicalDisplayName(categoryName);
    if (uuidRegex.hasMatch(humanName)) {
      humanName = 'Anggaran Belanja';
    }
    final targetKey = _normalizeCategoryKey(humanName);

    // Update local store (match by categoryId or normalized category name)
    final index = _localBudgets.indexWhere((b) =>
        b.categoryId == categoryId ||
        _normalizeCategoryKey(b.categoryName) == targetKey);

    BudgetEntity updatedEntity;
    if (index != -1) {
      final existing = _localBudgets[index];
      final finalName = (existing.categoryName != null &&
              !uuidRegex.hasMatch(existing.categoryName!))
          ? _canonicalDisplayName(existing.categoryName!)
          : humanName;
      updatedEntity = BudgetEntity(
        id: existing.id,
        userId: existing.userId,
        categoryId: existing.categoryId,
        categoryName: finalName,
        periodStart: periodStart,
        periodEnd: periodEnd,
        limitAmount: limitAmount,
        spentAmount: existing.spentAmount,
        currencyCode: 'IDR',
        createdAt: existing.createdAt,
        updatedAt: DateTime.now(),
      );
      _localBudgets[index] = updatedEntity;
    } else {
      updatedEntity = BudgetEntity(
        id: 'budget_local_${DateTime.now().millisecondsSinceEpoch}',
        userId: client.auth.currentUser?.id ?? 'demo_user_anna',
        categoryId: categoryId,
        categoryName: humanName,
        periodStart: periodStart,
        periodEnd: periodEnd,
        limitAmount: limitAmount,
        spentAmount: 0,
        currencyCode: 'IDR',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      _localBudgets.add(updatedEntity);
    }

    // Attempt remote save if user authenticated
    try {
      final user = client.auth.currentUser;
      if (user != null) {
        final startStr = periodStart.toIso8601String().split('T').first;
        final endStr = periodEnd.toIso8601String().split('T').first;

        String validCatId = categoryId;
        if (!uuidRegex.hasMatch(validCatId)) {
          final searchTerm = humanName.isNotEmpty
              ? humanName
              : validCatId.replaceAll('cat_sys_', '').replaceAll('_', ' ');

          // Scoped strictly to current user's categories or system categories!
          final catRes = await client
              .from('categories')
              .select('id, name, user_id')
              .or('user_id.eq.${user.id},is_system.eq.true')
              .ilike('name', '%$searchTerm%');

          final catList = (catRes as List).cast<Map<String, dynamic>>();
          if (catList.isNotEmpty) {
            // Prefer category owned by current user
            final userCat =
                catList.where((c) => c['user_id'] == user.id).firstOrNull;
            validCatId = (userCat ?? catList.first)['id'] as String;
          } else {
            // Category doesn't exist yet for this user in Supabase! Create it once.
            try {
              final newCat = await client
                  .from('categories')
                  .insert({
                    'user_id': user.id,
                    'name': humanName,
                    'transaction_type': 'expense',
                    'allocation_type':
                        targetKey == 'hiburan' ? 'wants' : 'needs',
                    'is_system': false,
                  })
                  .select('id')
                  .single();
              validCatId = newCat['id'] as String;
            } catch (_) {
              final anyCat = await client
                  .from('categories')
                  .select('id')
                  .or('user_id.eq.${user.id},is_system.eq.true')
                  .eq('transaction_type', 'expense')
                  .limit(1);
              if ((anyCat as List).isNotEmpty) {
                validCatId = anyCat.first['id'] as String;
              }
            }
          }
        }

        if (!uuidRegex.hasMatch(validCatId)) {
          return Success(updatedEntity);
        }

        // Check existing budgets for this user & period (by category_id OR normalized category name)
        String? existingBudgetId;
        try {
          final periodBudgets = await client
              .from('budgets')
              .select('id, category_id, categories(name)')
              .eq('user_id', user.id)
              .eq('period_start', startStr)
              .eq('period_end', endStr);

          for (final row in (periodBudgets as List)) {
            final rowCatId = row['category_id'] as String?;
            final catObj = row['categories'];
            String? rowCatName;
            if (catObj is Map) {
              rowCatName = catObj['name'] as String?;
            } else if (catObj is List && catObj.isNotEmpty) {
              rowCatName = catObj.first['name'] as String?;
            }
            if (rowCatId == validCatId ||
                (rowCatName != null &&
                    _normalizeCategoryKey(rowCatName) == targetKey)) {
              existingBudgetId = row['id'] as String?;
              break;
            }
          }
        } catch (_) {}

        Map<String, dynamic> row;
        if (existingBudgetId != null) {
          final updateRes = await client
              .from('budgets')
              .update({
                'category_id': validCatId,
                'limit_amount': limitAmount,
                'currency_code': 'IDR',
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', existingBudgetId)
              .select();
          row = (updateRes as List).first as Map<String, dynamic>;
        } else {
          final insertData = {
            'user_id': user.id,
            'category_id': validCatId,
            'limit_amount': limitAmount,
            'period_start': startStr,
            'period_end': endStr,
            'currency_code': 'IDR',
          };
          final insertRes = await client
              .from('budgets')
              .insert(insertData)
              .select();
          row = (insertRes as List).first as Map<String, dynamic>;
        }

        final savedEntity = BudgetEntity(
          id: row['id'],
          userId: row['user_id'],
          categoryId: row['category_id'],
          periodStart: DateTime.parse(row['period_start']),
          periodEnd: DateTime.parse(row['period_end']),
          limitAmount: (row['limit_amount'] as num).toDouble(),
          currencyCode: row['currency_code'] ?? 'IDR',
          createdAt: DateTime.parse(row['created_at']).toLocal(),
          updatedAt: DateTime.parse(row['updated_at']).toLocal(),
          spentAmount: updatedEntity.spentAmount,
          categoryName: updatedEntity.categoryName,
          categoryIcon: updatedEntity.categoryIcon,
          categoryColor: updatedEntity.categoryColor,
        );

        final localIdx = _localBudgets.indexWhere((b) =>
            b.categoryId == categoryId ||
            b.id == updatedEntity.id ||
            _normalizeCategoryKey(b.categoryName) == targetKey);
        if (localIdx != -1) {
          _localBudgets[localIdx] = savedEntity;
        }

        return Success(savedEntity);
      }
    } catch (_) {
      // Return local entity
    }

    return Success(updatedEntity);
  }

  @override
  Future<Result<void>> deleteBudget(String id) async {
    _localBudgets.removeWhere((b) => b.id == id);
    try {
      await client.from('budgets').delete().eq('id', id);
    } catch (_) {}
    return const Success(null);
  }
}
