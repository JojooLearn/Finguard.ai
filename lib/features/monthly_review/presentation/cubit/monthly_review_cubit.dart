import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/monthly_review_repository.dart';
import 'monthly_review_state.dart';

class MonthlyReviewCubit extends Cubit<MonthlyReviewState> {
  final MonthlyReviewRepository monthlyReviewRepository;

  MonthlyReviewCubit({required this.monthlyReviewRepository})
      : super(const MonthlyReviewInitial());

  Future<void> loadReviewForMonth(DateTime month, {bool forceRegenerate = false}) async {
    emit(const MonthlyReviewLoading());

    final periodStart = DateTime(month.year, month.month, 1);
    // Last day of month
    final periodEnd = DateTime(month.year, month.month + 1, 0);

    final result = await monthlyReviewRepository.getOrGenerateMonthlyReview(
      periodStart: periodStart,
      periodEnd: periodEnd,
      forceRegenerate: forceRegenerate,
    );

    result.fold(
      (review) => emit(MonthlyReviewLoaded(
        review: review,
        selectedMonth: month,
      )),
      (failure) => emit(MonthlyReviewError(failure.message)),
    );
  }

  void reset() {
    emit(const MonthlyReviewInitial());
  }
}

