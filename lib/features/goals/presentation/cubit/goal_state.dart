import 'package:equatable/equatable.dart';
import '../../domain/entities/goal_entity.dart';

abstract class GoalState extends Equatable {
  const GoalState();

  @override
  List<Object?> get props => [];
}

class GoalInitial extends GoalState {
  const GoalInitial();
}

class GoalLoading extends GoalState {
  const GoalLoading();
}

class GoalLoaded extends GoalState {
  final List<GoalEntity> goals;

  const GoalLoaded(this.goals);

  double get totalTarget => goals.fold(0.0, (sum, g) => sum + g.targetAmount);
  double get totalAccumulated => goals.fold(0.0, (sum, g) => sum + g.currentAmount);
  double get totalRemaining => (totalTarget - totalAccumulated).clamp(0.0, double.infinity);

  @override
  List<Object?> get props => [goals];
}

class GoalError extends GoalState {
  final String message;

  const GoalError(this.message);

  @override
  List<Object?> get props => [message];
}
