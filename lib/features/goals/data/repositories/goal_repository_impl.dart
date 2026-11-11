import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/goal_entity.dart';
import '../../domain/repositories/goal_repository.dart';

class GoalRepositoryImpl implements GoalRepository {
  final SupabaseClient client;

  // Zero-Tolerance: No dummy seed goals. Goals are created strictly by the user.
  final List<GoalEntity> _localGoals = [];

  GoalRepositoryImpl(this.client);

  @override
  Future<Result<List<GoalEntity>>> getGoals() async {
    try {
      final user = client.auth.currentUser;
      if (user != null) {
        final response = await client
            .from('financial_goals')
            .select()
            .eq('user_id', user.id)
            .neq('goal_type', 'debt_repayment')
            .order('created_at', ascending: false);

        final goals = (response as List).map((json) {
          return GoalEntity(
            id: json['id'],
            userId: json['user_id'],
            name: json['name'],
            description: json['description'],
            goalType: GoalType.fromString(json['goal_type'] ?? 'emergency_fund'),
            targetAmount: (json['target_amount'] as num).toDouble(),
            currentAmount: (json['current_amount'] as num?)?.toDouble() ?? 0.0,
            currencyCode: json['currency_code'] ?? 'IDR',
            targetDate: json['target_date'] != null
                ? DateTime.parse(json['target_date'])
                : null,
            priority: json['priority'] ?? 3,
            status: GoalStatus.fromString(json['status'] ?? 'active'),
            createdAt: DateTime.parse(json['created_at']).toLocal(),
            updatedAt: DateTime.parse(json['updated_at']).toLocal(),
          );
        }).toList();

        if (goals.isNotEmpty) {
          _localGoals.clear();
          _localGoals.addAll(goals);
          return Success(goals);
        } else if (_localGoals.isNotEmpty) {
          // Auto-heal: Sync local goals created during onboarding to Supabase
          for (final g in List<GoalEntity>.from(_localGoals)) {
            await createGoal(
              name: g.name,
              type: g.goalType,
              targetAmount: g.targetAmount,
              targetDate: g.targetDate,
              description: g.description,
              priority: g.priority,
            );
          }
        }
      }
    } catch (_) {
      // Fallback to local goals
    }

    return Success(List.unmodifiable(_localGoals));
  }

  @override
  Future<Result<GoalEntity>> createGoal({
    required String name,
    required GoalType type,
    required double targetAmount,
    DateTime? targetDate,
    String? description,
    int priority = 3,
  }) async {
    final newGoal = GoalEntity(
      id: 'goal_local_${DateTime.now().millisecondsSinceEpoch}',
      userId: client.auth.currentUser?.id ?? 'demo_user_anna',
      name: name,
      description: description,
      goalType: type,
      targetAmount: targetAmount,
      currentAmount: 0.0,
      currencyCode: 'IDR',
      targetDate: targetDate,
      priority: priority,
      status: GoalStatus.active,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    _localGoals.add(newGoal);

    try {
      final user = client.auth.currentUser;
      if (user != null) {
        final data = {
          'user_id': user.id,
          'name': name,
          'description': description,
          'goal_type': type.toDbString(),
          'target_amount': targetAmount,
          'current_amount': 0.0,
          'currency_code': 'IDR',
          if (targetDate != null)
            'target_date': targetDate.toIso8601String().split('T').first,
          'status': 'active',
        };
        final response = await client.from('financial_goals').insert(data).select().single();

        final savedEntity = GoalEntity(
          id: response['id'],
          userId: response['user_id'],
          name: response['name'],
          description: response['description'],
          goalType: GoalType.fromString(response['goal_type'] ?? type.toDbString()),
          targetAmount: (response['target_amount'] as num).toDouble(),
          currentAmount:
              (response['current_amount'] as num?)?.toDouble() ?? 0.0,
          currencyCode: response['currency_code'] ?? 'IDR',
          targetDate: response['target_date'] != null
              ? DateTime.parse(response['target_date'])
              : null,
          priority: response['priority'] ?? priority,
          status: GoalStatus.fromString(response['status'] ?? 'active'),
          createdAt: DateTime.parse(response['created_at']).toLocal(),
          updatedAt: DateTime.parse(response['updated_at']).toLocal(),
        );

        final localIdx = _localGoals.indexWhere((g) => g.id == newGoal.id);
        if (localIdx != -1) {
          _localGoals[localIdx] = savedEntity;
        }

        return Success(savedEntity);
      }
    } catch (_) {
      // Return local entity
    }

    return Success(newGoal);
  }

  @override
  Future<Result<GoalEntity>> addContribution({
    required String goalId,
    required double amount,
    DateTime? date,
    String? note,
  }) async {
    if (amount == 0) {
      return const ErrorResult(
        ServerFailure('Nominal mutasi tabungan tidak boleh nol.'),
      );
    }

    final index = _localGoals.indexWhere((g) => g.id == goalId);
    GoalEntity updatedGoal;

    if (index != -1) {
      final existing = _localGoals[index];
      if (amount < 0 && existing.currentAmount + amount < -0.01) {
        return const ErrorResult(
          ServerFailure(
            'Saldo target tabungan tidak mencukupi untuk penarikan ini.',
          ),
        );
      }
      final newCurrent =
          (existing.currentAmount + amount).clamp(0.0, double.infinity);
      final updatedStatus = newCurrent >= existing.targetAmount
          ? GoalStatus.completed
          : (existing.status == GoalStatus.completed
                ? GoalStatus.active
                : existing.status);
      updatedGoal = GoalEntity(
        id: existing.id,
        userId: existing.userId,
        name: existing.name,
        description: existing.description,
        goalType: existing.goalType,
        targetAmount: existing.targetAmount,
        currentAmount: newCurrent,
        currencyCode: existing.currencyCode,
        targetDate: existing.targetDate,
        priority: existing.priority,
        status: updatedStatus,
        createdAt: existing.createdAt,
        updatedAt: DateTime.now(),
      );
      _localGoals[index] = updatedGoal;
    } else if (_localGoals.isNotEmpty) {
      updatedGoal = _localGoals.first;
    } else {
      updatedGoal = GoalEntity(
        id: goalId,
        userId: 'local_user',
        name: 'Target Tabungan',
        goalType: GoalType.savings,
        targetAmount: amount.abs(),
        currentAmount: amount > 0 ? amount : 0.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    try {
      final user = client.auth.currentUser;
      if (user != null) {
        String validGoalId = goalId;
        final uuidRegex = RegExp(
            r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
        if (!uuidRegex.hasMatch(validGoalId)) {
          final gRes = await client
              .from('financial_goals')
              .select('id')
              .eq('user_id', user.id)
              .neq('goal_type', 'debt_repayment')
              .order('created_at', ascending: false)
              .limit(1)
              .maybeSingle();
          if (gRes != null) {
            validGoalId = gRes['id'] as String;
          }
        }

        final goalBefore = await client
            .from('financial_goals')
            .select()
            .eq('id', validGoalId)
            .single();
        final beforeCurrent =
            (goalBefore['current_amount'] as num?)?.toDouble() ?? 0.0;

        if (amount < 0 && beforeCurrent + amount < -0.01) {
          return const ErrorResult(
            ServerFailure(
              'Saldo Dana Darurat di database tidak mencukupi untuk penarikan ini.',
            ),
          );
        }

        final txDateStr =
            (date ?? DateTime.now()).toIso8601String().split('T')[0];

        // If withdrawing from a goal whose balance had no ledger rows yet,
        // seed an opening ledger entry first so SUM(amount) remains accurate.
        if (amount < 0 && beforeCurrent > 0) {
          final existingRows = await client
              .from('goal_contributions')
              .select('id')
              .eq('goal_id', validGoalId)
              .limit(1);
          if ((existingRows as List).isEmpty) {
            await client.from('goal_contributions').insert({
              'user_id': user.id,
              'goal_id': validGoalId,
              'amount': beforeCurrent,
              'contribution_date': txDateStr,
              'note': 'Saldo awal tercatat',
            });
          }
        }

        await client.from('goal_contributions').insert({
          'user_id': user.id,
          'goal_id': validGoalId,
          'amount': amount,
          'contribution_date': txDateStr,
          'note': note,
        });

        final goalAfter = await client
            .from('financial_goals')
            .select()
            .eq('id', validGoalId)
            .single();
        final afterCurrent =
            (goalAfter['current_amount'] as num?)?.toDouble() ?? 0.0;

        // Postgres trigger `trg_goal_contributions_update_amount` already updates `current_amount`;
        // only fall back to direct update if trigger did not adjust it.
        Map<String, dynamic> updated = goalAfter;
        if ((afterCurrent - beforeCurrent).abs() < 0.01) {
          final newCurrent =
              (beforeCurrent + amount).clamp(0.0, double.infinity);
          updated = await client
              .from('financial_goals')
              .update({'current_amount': newCurrent})
              .eq('id', validGoalId)
              .select()
              .single();
        }

        final syncedGoal = GoalEntity(
          id: updated['id'],
          userId: updated['user_id'],
          name: updated['name'],
          description: updated['description'],
          goalType: GoalType.fromString(updated['goal_type'] ?? 'emergency_fund'),
          targetAmount: (updated['target_amount'] as num).toDouble(),
          currentAmount:
              (updated['current_amount'] as num?)?.toDouble() ?? 0.0,
          currencyCode: updated['currency_code'] ?? 'IDR',
          targetDate: updated['target_date'] != null
              ? DateTime.parse(updated['target_date'])
              : null,
          priority: updated['priority'] ?? 3,
          status: GoalStatus.fromString(updated['status'] ?? 'active'),
          createdAt: DateTime.parse(updated['created_at']).toLocal(),
          updatedAt: DateTime.parse(updated['updated_at']).toLocal(),
        );
        if (index != -1 && index < _localGoals.length) {
          _localGoals[index] = syncedGoal;
        }
        return Success(syncedGoal);
      }
    } catch (_) {
      // Return local entity
    }

    return Success(updatedGoal);
  }

  @override
  Future<Result<void>> updateGoalStatus(
      String goalId, GoalStatus status) async {
    final index = _localGoals.indexWhere((g) => g.id == goalId);
    if (index != -1) {
      final g = _localGoals[index];
      _localGoals[index] = GoalEntity(
        id: g.id,
        userId: g.userId,
        name: g.name,
        description: g.description,
        goalType: g.goalType,
        targetAmount: g.targetAmount,
        currentAmount: g.currentAmount,
        currencyCode: g.currencyCode,
        targetDate: g.targetDate,
        priority: g.priority,
        status: status,
        createdAt: g.createdAt,
        updatedAt: DateTime.now(),
      );
    }
    try {
      await client
          .from('financial_goals')
          .update({'status': status.toDbString()}).eq('id', goalId);
    } catch (_) {}
    return const Success(null);
  }

  @override
  Future<Result<void>> deleteGoal(String goalId) async {
    _localGoals.removeWhere((g) => g.id == goalId);
    try {
      await client.from('financial_goals').delete().eq('id', goalId);
    } catch (_) {}
    return const Success(null);
  }
}
