import 'package:equatable/equatable.dart';
import '../../domain/entities/user_preferences_entity.dart';

abstract class UserPreferencesState extends Equatable {
  const UserPreferencesState();

  @override
  List<Object?> get props => [];
}

class UserPreferencesInitial extends UserPreferencesState {
  const UserPreferencesInitial();
}

class UserPreferencesLoading extends UserPreferencesState {
  const UserPreferencesLoading();
}

class UserPreferencesLoaded extends UserPreferencesState {
  final UserPreferencesEntity preferences;

  const UserPreferencesLoaded(this.preferences);

  @override
  List<Object?> get props => [preferences];
}

class UserPreferencesError extends UserPreferencesState {
  final String message;

  const UserPreferencesError(this.message);

  @override
  List<Object?> get props => [message];
}

