import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/user_preferences_entity.dart';
import '../../domain/repositories/user_preferences_repository.dart';

class UserPreferencesRepositoryImpl implements UserPreferencesRepository {
  final SupabaseClient client;

  UserPreferencesEntity? _cachedPreferences;

  UserPreferencesRepositoryImpl(this.client);

  @override
  Future<Result<UserPreferencesEntity>> getUserPreferences() async {
    try {
      final user = client.auth.currentUser;
      if (user != null) {
        final res = await client
            .from('user_preferences')
            .select()
            .eq('user_id', user.id)
            .maybeSingle();

        if (res != null) {
          _cachedPreferences = UserPreferencesEntity(
            userId: user.id,
            notificationsEnabled: res['notifications_enabled'] ?? true,
            budgetAlertsEnabled: res['budget_alerts_enabled'] ?? true,
            stockSignalsEnabled: res['stock_signals_enabled'] ?? true,
          );
          return Success(_cachedPreferences!);
        } else {
          // If row not created yet, create it
          await client.from('user_preferences').insert({
            'user_id': user.id,
            'notifications_enabled': true,
            'budget_alerts_enabled': true,
            'stock_signals_enabled': true,
          });
          _cachedPreferences = UserPreferencesEntity(userId: user.id);
          return Success(_cachedPreferences!);
        }
      }
    } catch (_) {}

    final defaultPrefs = _cachedPreferences ??
        UserPreferencesEntity(
          userId: client.auth.currentUser?.id ?? 'default_user',
          notificationsEnabled: true,
          budgetAlertsEnabled: true,
          stockSignalsEnabled: true,
        );
    return Success(defaultPrefs);
  }

  @override
  Future<Result<UserPreferencesEntity>> updatePreferences({
    bool? notificationsEnabled,
    bool? budgetAlertsEnabled,
    bool? stockSignalsEnabled,
  }) async {
    final user = client.auth.currentUser;
    final current = _cachedPreferences ??
        UserPreferencesEntity(
          userId: user?.id ?? 'default_user',
          notificationsEnabled: true,
          budgetAlertsEnabled: true,
          stockSignalsEnabled: true,
        );

    final updated = current.copyWith(
      notificationsEnabled: notificationsEnabled,
      budgetAlertsEnabled: budgetAlertsEnabled,
      stockSignalsEnabled: stockSignalsEnabled,
    );

    try {
      if (user != null) {
        final existing = await client
            .from('user_preferences')
            .select('user_id')
            .eq('user_id', user.id)
            .maybeSingle();

        if (existing != null) {
          await client.from('user_preferences').update({
            'notifications_enabled': updated.notificationsEnabled,
            'budget_alerts_enabled': updated.budgetAlertsEnabled,
            'stock_signals_enabled': updated.stockSignalsEnabled,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('user_id', user.id);
        } else {
          await client.from('user_preferences').insert({
            'user_id': user.id,
            'notifications_enabled': updated.notificationsEnabled,
            'budget_alerts_enabled': updated.budgetAlertsEnabled,
            'stock_signals_enabled': updated.stockSignalsEnabled,
            'updated_at': DateTime.now().toIso8601String(),
          });
        }
      }
    } catch (_) {
      // If network fails, update local cache
    }

    _cachedPreferences = updated;
    return Success(updated);
  }
}
