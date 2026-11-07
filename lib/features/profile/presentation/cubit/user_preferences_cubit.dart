import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/services/push_notification_service.dart';
import '../../domain/repositories/user_preferences_repository.dart';
import 'user_preferences_state.dart';

class UserPreferencesCubit extends Cubit<UserPreferencesState> {
  final UserPreferencesRepository repository;

  UserPreferencesCubit({required this.repository})
      : super(const UserPreferencesInitial());

  Future<void> loadPreferences() async {
    emit(const UserPreferencesLoading());
    final result = await repository.getUserPreferences();
    result.fold(
      (prefs) {
        PushNotificationService().setPushEnabled(prefs.notificationsEnabled);
        emit(UserPreferencesLoaded(prefs));
      },
      (failure) => emit(UserPreferencesError(failure.message)),
    );
  }

  Future<void> toggleNotifications(bool enabled) async {
    await PushNotificationService().setPushEnabled(enabled);
    final result = await repository.updatePreferences(notificationsEnabled: enabled);
    result.fold(
      (prefs) => emit(UserPreferencesLoaded(prefs)),
      (failure) => emit(UserPreferencesError(failure.message)),
    );
  }

  Future<void> toggleBudgetAlerts(bool enabled) async {
    final result = await repository.updatePreferences(budgetAlertsEnabled: enabled);
    result.fold(
      (prefs) => emit(UserPreferencesLoaded(prefs)),
      (failure) => emit(UserPreferencesError(failure.message)),
    );
  }

  Future<void> toggleStockSignals(bool enabled) async {
    final result = await repository.updatePreferences(stockSignalsEnabled: enabled);
    result.fold(
      (prefs) => emit(UserPreferencesLoaded(prefs)),
      (failure) => emit(UserPreferencesError(failure.message)),
    );
  }

  void reset() {
    emit(const UserPreferencesInitial());
  }
}
