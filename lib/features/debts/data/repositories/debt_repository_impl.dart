import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/result/result.dart';
import '../../../../core/errors/failure.dart';
import '../../domain/entities/debt_entity.dart';
import '../../domain/repositories/debt_repository.dart';

class DebtRepositoryImpl implements DebtRepository {
  final SupabaseClient client;
  final List<DebtEntity> _localDebts = [];

  DebtRepositoryImpl(this.client);

  @override
  Future<Result<List<DebtEntity>>> getDebts() async {
    try {
      final user = client.auth.currentUser;
      if (user != null) {
        final response = await client
            .from('financial_goals')
            .select()
            .eq('user_id', user.id)
            .eq('goal_type', 'debt_repayment')
            .order('created_at', ascending: false);

        final debts = (response as List).map((json) {
          int remaining = 1;
          int total = 1;
          int due = 10;
          double monthly = 0.0;

          if (json['description'] != null &&
              json['description'].toString().isNotEmpty) {
            try {
              final meta = jsonDecode(json['description']);
              if (meta is Map) {
                monthly = (meta['monthly_payment'] as num?)?.toDouble() ?? 0.0;
                remaining = (meta['remaining_tenor'] as num?)?.toInt() ?? 1;
                total = (meta['total_tenor'] as num?)?.toInt() ?? 1;
                due = (meta['due_day'] as num?)?.toInt() ?? 10;
              }
            } catch (_) {}
          }

          final totalAmt = (json['target_amount'] as num).toDouble();
          final paidAmt = (json['current_amount'] as num?)?.toDouble() ?? 0.0;
          if (monthly == 0.0 && total > 0) {
            monthly = totalAmt / total;
          }

          final statusStr = json['status'] ?? 'active';

          return DebtEntity(
            id: json['id'],
            userId: json['user_id'],
            name: json['name'],
            totalAmount: totalAmt,
            monthlyPayment: monthly,
            remainingTenorMonths: remaining,
            totalTenorMonths: total,
            dueDay: due,
            paidAmount: paidAmt,
            isCompleted: statusStr == 'completed' || remaining <= 0,
            createdAt: DateTime.parse(json['created_at']).toLocal(),
            updatedAt: DateTime.parse(json['updated_at']).toLocal(),
          );
        }).toList();

        _localDebts.clear();
        _localDebts.addAll(debts);
        await _syncProfileMonthlyDebt(user.id);
        return Success(debts);
      }
    } catch (_) {
      // Return cached/local
    }

    return Success(List.unmodifiable(_localDebts));
  }

  @override
  Future<Result<DebtEntity>> addDebt({
    required String name,
    required double monthlyPayment,
    required int remainingTenor,
    required int totalTenor,
    required int dueDay,
  }) async {
    final totalAmount = monthlyPayment * totalTenor;
    final paidAmount = (totalTenor - remainingTenor).clamp(0, totalTenor) * monthlyPayment;

    final meta = jsonEncode({
      'monthly_payment': monthlyPayment,
      'remaining_tenor': remainingTenor,
      'total_tenor': totalTenor,
      'due_day': dueDay,
    });

    final localEntity = DebtEntity(
      id: 'debt_local_${DateTime.now().millisecondsSinceEpoch}',
      userId: client.auth.currentUser?.id ?? 'demo_user',
      name: name,
      totalAmount: totalAmount,
      monthlyPayment: monthlyPayment,
      remainingTenorMonths: remainingTenor,
      totalTenorMonths: totalTenor,
      dueDay: dueDay,
      paidAmount: paidAmount,
      isCompleted: remainingTenor <= 0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    _localDebts.insert(0, localEntity);

    try {
      final user = client.auth.currentUser;
      if (user != null) {
        final inserted = await client.from('financial_goals').insert({
          'user_id': user.id,
          'name': name,
          'description': meta,
          'goal_type': 'debt_repayment',
          'target_amount': totalAmount,
          'current_amount': paidAmount,
          'currency_code': 'IDR',
          'status': remainingTenor <= 0 ? 'completed' : 'active',
        }).select().single();

        final saved = DebtEntity(
          id: inserted['id'],
          userId: inserted['user_id'],
          name: inserted['name'],
          totalAmount: totalAmount,
          monthlyPayment: monthlyPayment,
          remainingTenorMonths: remainingTenor,
          totalTenorMonths: totalTenor,
          dueDay: dueDay,
          paidAmount: paidAmount,
          isCompleted: remainingTenor <= 0,
          createdAt: DateTime.parse(inserted['created_at']).toLocal(),
          updatedAt: DateTime.parse(inserted['updated_at']).toLocal(),
        );

        final idx = _localDebts.indexWhere((d) => d.id == localEntity.id);
        if (idx != -1) {
          _localDebts[idx] = saved;
        }

        await _syncProfileMonthlyDebt(user.id);
        return Success(saved);
      }
    } catch (_) {}

    return Success(localEntity);
  }

  @override
  Future<Result<DebtEntity>> payInstallment(String debtId) async {
    final index = _localDebts.indexWhere((d) => d.id == debtId);
    if (index == -1) {
      return const ErrorResult(ServerFailure('Cicilan tidak ditemukan'));
    }

    final d = _localDebts[index];
    final newRemaining = (d.remainingTenorMonths - 1).clamp(0, d.totalTenorMonths);
    final newPaid = d.paidAmount + d.monthlyPayment;
    final isDone = newRemaining <= 0;

    final updated = d.copyWith(
      remainingTenorMonths: newRemaining,
      paidAmount: newPaid,
      isCompleted: isDone,
      updatedAt: DateTime.now(),
    );
    _localDebts[index] = updated;

    try {
      final user = client.auth.currentUser;
      if (user != null) {
        final meta = jsonEncode({
          'monthly_payment': d.monthlyPayment,
          'remaining_tenor': newRemaining,
          'total_tenor': d.totalTenorMonths,
          'due_day': d.dueDay,
        });

        // 1. Update goal record
        await client.from('financial_goals').update({
          'current_amount': newPaid,
          'description': meta,
          'status': isDone ? 'completed' : 'active',
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', debtId);

        // 2. Record expense transaction for this payment
        try {
          await client.from('transactions').insert({
            'user_id': user.id,
            'amount': d.monthlyPayment,
            'transaction_type': 'expense',
            'category_id': 'cat_sys_tagihan',
            'note': 'Bayar ${d.name} (${d.totalTenorMonths - newRemaining}/${d.totalTenorMonths})',
            'transaction_date': DateTime.now().toIso8601String().split('T')[0],
            'source': 'manual',
            'status': 'confirmed',
          });
        } catch (_) {}

        // 3. Sync profile monthly debt obligation
        await _syncProfileMonthlyDebt(user.id);
      }
    } catch (_) {}

    return Success(updated);
  }

  @override
  Future<Result<void>> deleteDebt(String debtId) async {
    _localDebts.removeWhere((d) => d.id == debtId);
    try {
      final user = client.auth.currentUser;
      if (user != null) {
        await client.from('financial_goals').delete().eq('id', debtId);
        await _syncProfileMonthlyDebt(user.id);
      }
    } catch (_) {}
    return const Success(null);
  }

  Future<void> _syncProfileMonthlyDebt(String userId) async {
    try {
      final activeDebts = _localDebts.where((d) => !d.isCompleted && d.remainingTenorMonths > 0);
      final totalMonthlyDebt = activeDebts.fold<double>(0.0, (s, d) => s + d.monthlyPayment);

      await client
          .from('financial_profiles')
          .update({'monthly_debt_payments': totalMonthlyDebt})
          .eq('user_id', userId);
    } catch (_) {}
  }
}
