import 'package:equatable/equatable.dart';

class UserPreferencesEntity extends Equatable {
  final String userId;
  final bool notificationsEnabled;
  final bool budgetAlertsEnabled;
  final bool stockSignalsEnabled;

  const UserPreferencesEntity({
    required this.userId,
    this.notificationsEnabled = true,
    this.budgetAlertsEnabled = true,
    this.stockSignalsEnabled = true,
  });

  UserPreferencesEntity copyWith({
    String? userId,
    bool? notificationsEnabled,
    bool? budgetAlertsEnabled,
    bool? stockSignalsEnabled,
  }) {
    return UserPreferencesEntity(
      userId: userId ?? this.userId,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      budgetAlertsEnabled: budgetAlertsEnabled ?? this.budgetAlertsEnabled,
      stockSignalsEnabled: stockSignalsEnabled ?? this.stockSignalsEnabled,
    );
  }

  @override
  List<Object?> get props => [
    userId,
    notificationsEnabled,
    budgetAlertsEnabled,
    stockSignalsEnabled,
  ];
}

