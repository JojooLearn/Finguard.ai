import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/account_entity.dart';
import '../../domain/entities/category_entity.dart';
import '../../domain/repositories/category_and_account_repository.dart';

class CategoryRepositoryImpl implements CategoryRepository {
  final SupabaseClient client;

  // Master system categories only (Zero-Tolerance: is_system = true, userId = null)
  final List<CategoryEntity> _localCategories = [
    CategoryEntity(
      id: 'cat_sys_makan',
      userId: null,
      name: 'Makan & Minum',
      transactionType: TransactionType.expense,
      allocationType: AllocationType.needs,
      iconKey: 'utensils',
      colorHex: '#E0A100',
      isSystem: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    CategoryEntity(
      id: 'cat_sys_transport',
      userId: null,
      name: 'Transportasi',
      transactionType: TransactionType.expense,
      allocationType: AllocationType.needs,
      iconKey: 'car',
      colorHex: '#263202',
      isSystem: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    CategoryEntity(
      id: 'cat_sys_tagihan',
      userId: null,
      name: 'Tagihan & Utilitas',
      transactionType: TransactionType.expense,
      allocationType: AllocationType.needs,
      iconKey: 'receipt',
      colorHex: '#D64545',
      isSystem: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    CategoryEntity(
      id: 'cat_sys_belanja',
      userId: null,
      name: 'Belanja Harian',
      transactionType: TransactionType.expense,
      allocationType: AllocationType.needs,
      iconKey: 'shopping_cart',
      colorHex: '#B3CA2D',
      isSystem: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    CategoryEntity(
      id: 'cat_sys_kesehatan',
      userId: null,
      name: 'Kesehatan',
      transactionType: TransactionType.expense,
      allocationType: AllocationType.needs,
      iconKey: 'heart_pulse',
      colorHex: '#4A7C10',
      isSystem: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    CategoryEntity(
      id: 'cat_sys_hiburan',
      userId: null,
      name: 'Hiburan',
      transactionType: TransactionType.expense,
      allocationType: AllocationType.wants,
      iconKey: 'ticket',
      colorHex: '#8B5CF6',
      isSystem: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    CategoryEntity(
      id: 'cat_sys_gaya_hidup',
      userId: null,
      name: 'Gaya Hidup & Hobi',
      transactionType: TransactionType.expense,
      allocationType: AllocationType.wants,
      iconKey: 'coffee',
      colorHex: '#EC4899',
      isSystem: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    CategoryEntity(
      id: 'cat_sys_gaji',
      userId: null,
      name: 'Gaji & Upah',
      transactionType: TransactionType.income,
      allocationType: AllocationType.savingsDebt,
      iconKey: 'wallet',
      colorHex: '#4A7C10',
      isSystem: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  ];

  CategoryRepositoryImpl(this.client);

  @override
  Future<Result<List<CategoryEntity>>> getCategories({TransactionType? type}) async {
    try {
      final user = client.auth.currentUser;
      if (user != null) {
        var query = client
            .from('categories')
            .select()
            .eq('is_archived', false)
            .or('user_id.eq.${user.id},is_system.eq.true,user_id.is.null');

        if (type != null) {
          query = query.eq('transaction_type', type.toDbString());
        }
        final response = await query.order('name', ascending: true);

        final categories = (response as List).map((json) {
          return CategoryEntity(
            id: json['id'],
            userId: json['user_id'],
            name: json['name'],
            transactionType: TransactionType.fromString(
                json['transaction_type'] ?? 'expense'),
            allocationType: AllocationType.fromString(json['allocation_type']),
            iconKey: json['icon_key'],
            colorHex: json['color_hex'],
            isSystem: json['is_system'] ?? false,
            isArchived: json['is_archived'] ?? false,
            createdAt: DateTime.parse(json['created_at']).toLocal(),
            updatedAt: DateTime.parse(json['updated_at']).toLocal(),
          );
        }).toList();

        if (categories.isNotEmpty) {
          // Deduplicate by name to prevent multiple instances of identical categories
          final Map<String, CategoryEntity> uniqueByName = {};
          for (final cat in categories) {
            final key = cat.name.trim().toLowerCase();
            if (!uniqueByName.containsKey(key) ||
                (cat.userId == user.id && uniqueByName[key]?.userId != user.id)) {
              uniqueByName[key] = cat;
            }
          }
          return Success(uniqueByName.values.toList());
        }

        // Auto-seed categories into Supabase if categories table is empty
        // Must use user_id = user.id and is_system = false to satisfy Supabase RLS policy
        try {
          final seedData = [
            {'user_id': user.id, 'name': 'Makan & Minum', 'transaction_type': 'expense', 'allocation_type': 'needs', 'icon_key': 'utensils', 'color_hex': '#E0A100', 'is_system': false},
            {'user_id': user.id, 'name': 'Transportasi', 'transaction_type': 'expense', 'allocation_type': 'needs', 'icon_key': 'car', 'color_hex': '#263202', 'is_system': false},
            {'user_id': user.id, 'name': 'Tagihan & Utilitas', 'transaction_type': 'expense', 'allocation_type': 'needs', 'icon_key': 'receipt', 'color_hex': '#D64545', 'is_system': false},
            {'user_id': user.id, 'name': 'Belanja Harian', 'transaction_type': 'expense', 'allocation_type': 'needs', 'icon_key': 'shopping-cart', 'color_hex': '#B3CA2D', 'is_system': false},
            {'user_id': user.id, 'name': 'Kesehatan', 'transaction_type': 'expense', 'allocation_type': 'needs', 'icon_key': 'heart-pulse', 'color_hex': '#4A7C10', 'is_system': false},
            {'user_id': user.id, 'name': 'Hiburan', 'transaction_type': 'expense', 'allocation_type': 'wants', 'icon_key': 'ticket', 'color_hex': '#8B5CF6', 'is_system': false},
            {'user_id': user.id, 'name': 'Gaya Hidup & Hobi', 'transaction_type': 'expense', 'allocation_type': 'wants', 'icon_key': 'coffee', 'color_hex': '#EC4899', 'is_system': false},
            {'user_id': user.id, 'name': 'Gaji & Upah', 'transaction_type': 'income', 'allocation_type': 'other', 'icon_key': 'wallet', 'color_hex': '#4A7C10', 'is_system': false},
            {'user_id': user.id, 'name': 'Bonus & THR', 'transaction_type': 'income', 'allocation_type': 'other', 'icon_key': 'gift', 'color_hex': '#B3CA2D', 'is_system': false},
            {'user_id': user.id, 'name': 'Penjualan & Usaha', 'transaction_type': 'income', 'allocation_type': 'other', 'icon_key': 'store', 'color_hex': '#3B82F6', 'is_system': false},
            {'user_id': user.id, 'name': 'Investasi & Dividen', 'transaction_type': 'income', 'allocation_type': 'savings_debt', 'icon_key': 'trending-up', 'color_hex': '#10B981', 'is_system': false},
            {'user_id': user.id, 'name': 'Lainnya', 'transaction_type': 'expense', 'allocation_type': 'other', 'icon_key': 'more-horizontal', 'color_hex': '#64748B', 'is_system': false},
          ];
          final inserted = await client.from('categories').insert(seedData).select();
          if ((inserted as List).isNotEmpty) {
            return getCategories(type: type);
          }
        } catch (_) {}
      }
    } catch (_) {}

    final filtered = type == null
        ? _localCategories
        : _localCategories.where((c) => c.transactionType == type).toList();

    return Success(List.unmodifiable(filtered));
  }

  @override
  Future<Result<CategoryEntity>> createCategory({
    required String name,
    required TransactionType type,
    AllocationType? allocationType,
    String? iconKey,
    String? colorHex,
  }) async {
    final newCat = CategoryEntity(
      id: 'cat_local_${DateTime.now().millisecondsSinceEpoch}',
      userId: client.auth.currentUser?.id ?? 'demo_user_anna',
      name: name,
      transactionType: type,
      allocationType: allocationType ?? AllocationType.needs,
      iconKey: iconKey,
      colorHex: colorHex,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _localCategories.add(newCat);

    try {
      final user = client.auth.currentUser;
      if (user != null) {
        final data = {
          'user_id': user.id,
          'name': name,
          'transaction_type': type.toDbString(),
          'allocation_type': allocationType?.toDbString(),
          'icon_key': iconKey,
          'color_hex': colorHex,
          'is_system': false,
          'is_archived': false,
        };

        final response =
            await client.from('categories').insert(data).select().single();

        return Success(CategoryEntity(
          id: response['id'],
          userId: response['user_id'],
          name: response['name'],
          transactionType:
              TransactionType.fromString(response['transaction_type']),
          allocationType: AllocationType.fromString(response['allocation_type']),
          iconKey: response['icon_key'],
          colorHex: response['color_hex'],
          isSystem: response['is_system'] ?? false,
          isArchived: response['is_archived'] ?? false,
          createdAt: DateTime.parse(response['created_at']).toLocal(),
          updatedAt: DateTime.parse(response['updated_at']).toLocal(),
        ));
      }
    } catch (_) {}

    return Success(newCat);
  }
}

class AccountRepositoryImpl implements AccountRepository {
  final SupabaseClient client;

  // Zero-Tolerance: No dummy accounts. Accounts are populated strictly from user onboarding.
  final List<AccountEntity> _localAccounts = [];

  AccountRepositoryImpl(this.client);

  @override
  Future<Result<List<AccountEntity>>> getAccounts() async {
    try {
      final user = client.auth.currentUser;
      if (user != null) {
        final response = await client
            .from('accounts')
            .select()
            .eq('is_archived', false)
            .order('is_default', ascending: false)
            .order('name', ascending: true);

        final accounts = (response as List).map((json) {
          return AccountEntity(
            id: json['id'],
            userId: json['user_id'],
            name: json['name'],
            accountType: AccountType.fromString(json['account_type'] ?? 'cash'),
            currencyCode: json['currency_code'] ?? 'IDR',
            openingBalance: (json['opening_balance'] as num?)?.toDouble() ?? 0.0,
            isDefault: json['is_default'] ?? false,
            isArchived: json['is_archived'] ?? false,
            createdAt: DateTime.parse(json['created_at']).toLocal(),
            updatedAt: DateTime.parse(json['updated_at']).toLocal(),
          );
        }).toList();

        if (accounts.isNotEmpty) return Success(accounts);
      }
    } catch (_) {}

    return Success(List.unmodifiable(_localAccounts));
  }

  @override
  Future<Result<AccountEntity>> createAccount({
    required String name,
    required AccountType type,
    double openingBalance = 0.0,
    bool isDefault = false,
  }) async {
    final newAcc = AccountEntity(
      id: 'acc_local_${DateTime.now().millisecondsSinceEpoch}',
      userId: client.auth.currentUser?.id ?? 'demo_user_anna',
      name: name,
      accountType: type,
      currencyCode: 'IDR',
      openingBalance: openingBalance,
      isDefault: isDefault,
      isArchived: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _localAccounts.add(newAcc);

    try {
      final user = client.auth.currentUser;
      if (user != null) {
        final data = {
          'user_id': user.id,
          'name': name,
          'account_type': type.toDbString(),
          'currency_code': 'IDR',
          'opening_balance': openingBalance,
          'is_default': isDefault,
          'is_archived': false,
        };

        final response =
            await client.from('accounts').insert(data).select().single();

        return Success(AccountEntity(
          id: response['id'],
          userId: response['user_id'],
          name: response['name'],
          accountType: AccountType.fromString(response['account_type']),
          currencyCode: response['currency_code'] ?? 'IDR',
          openingBalance:
              (response['opening_balance'] as num?)?.toDouble() ?? 0.0,
          isDefault: response['is_default'] ?? false,
          isArchived: response['is_archived'] ?? false,
          createdAt: DateTime.parse(response['created_at']).toLocal(),
          updatedAt: DateTime.parse(response['updated_at']).toLocal(),
        ));
      }
    } catch (_) {}

    return Success(newAcc);
  }
}
