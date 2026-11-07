import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/account_entity.dart';
import '../../domain/entities/category_entity.dart';
import '../../domain/entities/transaction_entity.dart';

abstract class TransactionRemoteDataSource {
  Future<List<TransactionEntity>> getTransactions({
    DateTime? startDate,
    DateTime? endDate,
    String? categoryId,
    String? accountId,
    TransactionType? type,
    int limit = 50,
    int offset = 0,
  });

  Future<TransactionEntity> getTransactionById(String id);

  Future<TransactionEntity> createTransaction({
    required double amount,
    required TransactionType type,
    required DateTime transactionDate,
    String? categoryId,
    String? accountId,
    String? note,
    TransactionSource source = TransactionSource.manual,
    String? clientRequestId,
  });

  Future<TransactionEntity> updateTransaction(TransactionEntity transaction);

  Future<void> deleteTransaction(String id);
}

/// Database-backed transactions. Every method throws on failure so callers can
/// surface the error; nothing is ever kept in an in-memory fallback.
class TransactionRemoteDataSourceImpl implements TransactionRemoteDataSource {
  final SupabaseClient client;

  TransactionRemoteDataSourceImpl(this.client);

  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  static const String _select = '*, categories(*), accounts(*)';

  static String _date(DateTime d) => d.toIso8601String().split('T').first;

  User get _user {
    final user = client.auth.currentUser;
    if (user == null) {
      throw const AuthException('Sesi berakhir tod, silakan masuk lagi');
    }
    return user;
  }

  @override
  Future<List<TransactionEntity>> getTransactions({
    DateTime? startDate,
    DateTime? endDate,
    String? categoryId,
    String? accountId,
    TransactionType? type,
    int limit = 50,
    int offset = 0,
  }) async {
    final user = _user;
    var query = client
        .from('transactions')
        .select(_select)
        .eq('user_id', user.id)
        .isFilter('deleted_at', null);

    if (startDate != null) {
      query = query.gte('transaction_date', _date(startDate));
    }
    if (endDate != null) {
      query = query.lte('transaction_date', _date(endDate));
    }
    if (categoryId != null) query = query.eq('category_id', categoryId);
    if (accountId != null) query = query.eq('account_id', accountId);
    if (type != null) query = query.eq('transaction_type', type.toDbString());

    final response = await query
        .order('transaction_date', ascending: false)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return (response as List)
        .map((json) => _mapJsonToTransaction(json))
        .toList();
  }

  @override
  Future<TransactionEntity> getTransactionById(String id) async {
    final response = await client
        .from('transactions')
        .select(_select)
        .eq('id', id)
        .eq('user_id', _user.id)
        .isFilter('deleted_at', null)
        .single();
    return _mapJsonToTransaction(response);
  }

  @override
  Future<TransactionEntity> createTransaction({
    required double amount,
    required TransactionType type,
    required DateTime transactionDate,
    String? categoryId,
    String? accountId,
    String? note,
    TransactionSource source = TransactionSource.manual,
    String? clientRequestId,
  }) async {
    final user = _user;
    if (amount <= 0) throw ArgumentError('Nominal harus lebih dari 0 mbut');

    final validClientId =
        (clientRequestId != null && _uuidRegex.hasMatch(clientRequestId))
        ? clientRequestId
        : null;

    // Idempotency: a retry with the same request id returns the stored row.
    if (validClientId != null) {
      final existing = await client
          .from('transactions')
          .select(_select)
          .eq('user_id', user.id)
          .eq('client_request_id', validClientId)
          .maybeSingle();
      if (existing != null) return _mapJsonToTransaction(existing);
    }

    String? resolvedAccountId =
        (accountId != null && _uuidRegex.hasMatch(accountId))
        ? accountId
        : null;
    if (resolvedAccountId == null) {
      final rows = await client
          .from('accounts')
          .select('id')
          .eq('user_id', user.id)
          .eq('is_archived', false)
          .order('is_default', ascending: false)
          .limit(1);
      if ((rows as List).isEmpty) {
        // Auto-create default account if none exists
        final newAcc = await client
            .from('accounts')
            .insert({
              'user_id': user.id,
              'name': 'Dompet Utama',
              'account_type': 'cash',
              'opening_balance': 0.0,
              'is_default': true,
            })
            .select('id')
            .single();
        resolvedAccountId = newAcc['id'] as String;
      } else {
        resolvedAccountId = rows.first['id'] as String;
      }
    }

    String? resolvedCategoryId =
        (categoryId != null && _uuidRegex.hasMatch(categoryId))
        ? categoryId
        : null;
    if (resolvedCategoryId == null) {
      final defaultName = type == TransactionType.income
          ? 'Gaji & Upah'
          : 'Lainnya';
      final rows = await client
          .from('categories')
          .select('id')
          .eq('user_id', user.id)
          .ilike('name', '%$defaultName%')
          .limit(1);
      if ((rows as List).isNotEmpty) {
        resolvedCategoryId = rows.first['id'] as String;
      } else {
        final anyCat = await client
            .from('categories')
            .select('id')
            .eq('user_id', user.id)
            .limit(1);
        if ((anyCat as List).isNotEmpty) {
          resolvedCategoryId = anyCat.first['id'] as String;
        } else {
          final newCat = await client
              .from('categories')
              .insert({
                'user_id': user.id,
                'name': defaultName,
                'transaction_type': type.toDbString(),
                'allocation_type': 'other',
                'is_system': false,
              })
              .select('id')
              .single();
          resolvedCategoryId = newCat['id'] as String;
        }
      }
    }

    final insertPayload = <String, dynamic>{
      'user_id': user.id,
      'amount': amount,
      'transaction_type': type.toDbString(),
      'transaction_date': _date(transactionDate),
      'category_id': resolvedCategoryId,
      'account_id': resolvedAccountId,
      'note': note,
      'source': source.toDbString(),
    };
    if (validClientId != null) {
      insertPayload['client_request_id'] = validClientId;
    }

    final response = await client
        .from('transactions')
        .insert(insertPayload)
        .select(_select)
        .single();

    return _mapJsonToTransaction(response);
  }

  @override
  Future<TransactionEntity> updateTransaction(
    TransactionEntity transaction,
  ) async {
    final response = await client
        .from('transactions')
        .update({
          'amount': transaction.amount,
          'transaction_type': transaction.transactionType.toDbString(),
          'transaction_date': _date(transaction.transactionDate),
          'category_id': transaction.categoryId,
          'account_id': transaction.accountId,
          'note': transaction.note,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', transaction.id)
        .eq('user_id', _user.id)
        .select(_select)
        .single();
    return _mapJsonToTransaction(response);
  }

  @override
  Future<void> deleteTransaction(String id) async {
    await client
        .from('transactions')
        .update({'deleted_at': DateTime.now().toIso8601String()})
        .eq('id', id)
        .eq('user_id', _user.id);
  }

  TransactionEntity _mapJsonToTransaction(Map<String, dynamic> json) {
    CategoryEntity? category;
    if (json['categories'] != null) {
      final cat = json['categories'];
      category = CategoryEntity(
        id: cat['id'],
        userId: cat['user_id'],
        name: cat['name'],
        transactionType: TransactionType.fromString(
          cat['transaction_type'] ?? 'expense',
        ),
        allocationType: AllocationType.fromString(cat['allocation_type']),
        iconKey: cat['icon_key'],
        colorHex: cat['color_hex'],
        isSystem: cat['is_system'] ?? false,
        isArchived: cat['is_archived'] ?? false,
        createdAt: DateTime.parse(cat['created_at']).toLocal(),
        updatedAt: DateTime.parse(cat['updated_at']).toLocal(),
      );
    }

    AccountEntity? account;
    if (json['accounts'] != null) {
      final acc = json['accounts'];
      account = AccountEntity(
        id: acc['id'],
        userId: acc['user_id'],
        name: acc['name'],
        accountType: AccountType.fromString(acc['account_type'] ?? 'cash'),
        currencyCode: acc['currency_code'] ?? 'IDR',
        openingBalance: (acc['opening_balance'] as num?)?.toDouble() ?? 0.0,
        isDefault: acc['is_default'] ?? false,
        isArchived: acc['is_archived'] ?? false,
        createdAt: DateTime.parse(acc['created_at']).toLocal(),
        updatedAt: DateTime.parse(acc['updated_at']).toLocal(),
      );
    }

    return TransactionEntity(
      id: json['id'],
      userId: json['user_id'],
      accountId: json['account_id'],
      categoryId: json['category_id'],
      transactionType: TransactionType.fromString(
        json['transaction_type'] ?? 'expense',
      ),
      amount: (json['amount'] as num).toDouble(),
      currencyCode: json['currency_code'] ?? 'IDR',
      transactionDate: DateTime.parse(json['transaction_date']),
      note: json['note'],
      source: TransactionSource.fromString(json['source'] ?? 'manual'),
      status: TransactionStatus.fromString(json['status'] ?? 'confirmed'),
      aiIntent: json['ai_intent'],
      aiCategoryConfidence: (json['ai_category_confidence'] as num?)
          ?.toDouble(),
      clientRequestId: json['client_request_id'],
      createdAt: DateTime.parse(json['created_at']).toLocal(),
      updatedAt: DateTime.parse(json['updated_at']).toLocal(),
      deletedAt: json['deleted_at'] != null
          ? DateTime.parse(json['deleted_at']).toLocal()
          : null,
      category: category,
      account: account,
    );
  }
}
