import 'package:equatable/equatable.dart';
import '../../domain/entities/monthly_review_entity.dart';

abstract class MonthlyReviewState extends Equatable {
  const MonthlyReviewState();

  @override
  List<Object?> get props => [];
}

class MonthlyReviewInitial extends MonthlyReviewState {
  const MonthlyReviewInitial();
}

class MonthlyReviewLoading extends MonthlyReviewState {
  const MonthlyReviewLoading();
}

class MonthlyReviewLoaded extends MonthlyReviewState {
  final MonthlyReviewEntity review;
  final DateTime selectedMonth;

  const MonthlyReviewLoaded({
    required this.review,
    required this.selectedMonth,
  });

  @override
  List<Object?> get props => [review, selectedMonth];
}

class MonthlyReviewError extends MonthlyReviewState {
  final String message;

  const MonthlyReviewError(this.message);

  @override
  List<Object?> get props => [message];
}

