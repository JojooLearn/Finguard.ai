import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/goal_entity.dart';
import '../../domain/repositories/goal_repository.dart';
import 'goal_state.dart';

class GoalCubit extends Cubit<GoalState> {
  final GoalRepository goalRepository;

  GoalCubit({required this.goalRepository}) : super(const GoalInitial());

  Future<void> loadGoals() async {
    emit(const GoalLoading());
    final result = await goalRepository.getGoals();
    Map<String, double> monthlyTransfers = const {};
    try {
      final transferResult = await goalRepository.getMonthlySavingsTransfers();
      transferResult.fold(
        (transfers) => monthlyTransfers = transfers,
        (_) {},
      );
    } catch (_) {}
    result.fold(
      (goals) => emit(
        GoalLoaded(goals, monthlySavingsTransfers: monthlyTransfers),
      ),
      (failure) => emit(GoalError(failure.message)),
    );
  }

  Future<void> createGoal({
    required String name,
    required GoalType type,
    required double targetAmount,
    DateTime? targetDate,
    String? description,
    int priority = 3,
  }) async {
    final result = await goalRepository.createGoal(
      name: name,
      type: type,
      targetAmount: targetAmount,
      targetDate: targetDate,
      description: description,
      priority: priority,
    );

    await result.fold<Future<void>>(
      (_) => loadGoals(),
      (failure) async => emit(GoalError(failure.message)),
    );
  }

  Future<void> addContribution({
    required String goalId,
    required double amount,
    DateTime? date,
    String? note,
  }) async {
    final result = await goalRepository.addContribution(
      goalId: goalId,
      amount: amount,
      date: date,
      note: note,
    );

    await result.fold<Future<void>>(
      (_) => loadGoals(),
      (failure) async => emit(GoalError(failure.message)),
    );
  }

  Future<void> deleteGoal(String goalId) async {
    final result = await goalRepository.deleteGoal(goalId);
    await result.fold<Future<void>>(
      (_) => loadGoals(),
      (failure) async => emit(GoalError(failure.message)),
    );
  }

  void reset() {
    emit(const GoalInitial());
  }
}
