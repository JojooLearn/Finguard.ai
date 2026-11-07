import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:finguard/core/errors/failure.dart';
import 'package:finguard/core/result/result.dart';
import 'package:finguard/features/monthly_review/domain/entities/monthly_review_entity.dart';
import 'package:finguard/features/monthly_review/domain/repositories/monthly_review_repository.dart';
import 'package:finguard/features/monthly_review/presentation/cubit/monthly_review_cubit.dart';
import 'package:finguard/features/monthly_review/presentation/cubit/monthly_review_state.dart';

class MockMonthlyReviewRepository extends Mock implements MonthlyReviewRepository {}

void main() {
  late MockMonthlyReviewRepository mockRepo;

  const testReview = MonthlyReviewEntity(
    id: 'rev-1',
    periodStart: '2026-10-01',
    periodEnd: '2026-10-31',
    currencyCode: 'IDR',
    metrics: MonthlyReviewMetrics(
      totalIncome: 8000000,
      totalExpense: 3750000,
      netCashFlow: 4250000,
      transactionCount: 24,
      savingsRate: 53.125,
    ),
    narrative: 'Surplus kas sangat baik di bulan Oktober.',
  );

  setUp(() {
    mockRepo = MockMonthlyReviewRepository();
  });

  group('MonthlyReviewCubit', () {
    test('initial state is MonthlyReviewInitial', () {
      final cubit = MonthlyReviewCubit(monthlyReviewRepository: mockRepo);
      expect(cubit.state, const MonthlyReviewInitial());
      cubit.close();
    });

    blocTest<MonthlyReviewCubit, MonthlyReviewState>(
      'emits [Loading, Loaded] when monthly review is successfully loaded',
      build: () {
        when(() => mockRepo.getOrGenerateMonthlyReview(
              periodStart: any(named: 'periodStart'),
              periodEnd: any(named: 'periodEnd'),
              forceRegenerate: any(named: 'forceRegenerate'),
            )).thenAnswer((_) async => const Success(testReview));
        return MonthlyReviewCubit(monthlyReviewRepository: mockRepo);
      },
      act: (cubit) => cubit.loadReviewForMonth(DateTime(2026, 10, 1)),
      expect: () => [
        const MonthlyReviewLoading(),
        MonthlyReviewLoaded(
          review: testReview,
          selectedMonth: DateTime(2026, 10, 1),
        ),
      ],
    );

    blocTest<MonthlyReviewCubit, MonthlyReviewState>(
      'emits [Loading, Error] when repository returns a failure',
      build: () {
        when(() => mockRepo.getOrGenerateMonthlyReview(
              periodStart: any(named: 'periodStart'),
              periodEnd: any(named: 'periodEnd'),
              forceRegenerate: any(named: 'forceRegenerate'),
            )).thenAnswer((_) async => const ErrorResult(ServerFailure('Gagal memuat review')));
        return MonthlyReviewCubit(monthlyReviewRepository: mockRepo);
      },
      act: (cubit) => cubit.loadReviewForMonth(DateTime(2026, 10, 1)),
      expect: () => [
        const MonthlyReviewLoading(),
        const MonthlyReviewError('Gagal memuat review'),
      ],
    );
  });
}

