import '../../../../core/result/result.dart';
import '../entities/monthly_review_entity.dart';

abstract class MonthlyReviewRepository {
  Future<Result<MonthlyReviewEntity>> getOrGenerateMonthlyReview({
    required DateTime periodStart,
    required DateTime periodEnd,
    bool forceRegenerate = false,
  });
}

