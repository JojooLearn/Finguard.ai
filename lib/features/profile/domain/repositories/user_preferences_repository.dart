import '../../../../core/result/result.dart';
import '../entities/user_preferences_entity.dart';

abstract class UserPreferencesRepository {
  Future<Result<UserPreferencesEntity>> getUserPreferences();
  Future<Result<UserPreferencesEntity>> updatePreferences({
    bool? notificationsEnabled,
    bool? budgetAlertsEnabled,
    bool? stockSignalsEnabled,
  });
}

