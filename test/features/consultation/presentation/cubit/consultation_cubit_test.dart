import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:finguard/core/errors/failure.dart';
import 'package:finguard/core/result/result.dart';
import 'package:finguard/features/consultation/domain/entities/consultation_result_entity.dart';
import 'package:finguard/features/consultation/domain/repositories/consultation_repository.dart';
import 'package:finguard/features/consultation/presentation/cubit/consultation_cubit.dart';
import 'package:finguard/features/consultation/presentation/cubit/consultation_state.dart';

class MockConsultationRepository extends Mock
    implements ConsultationRepository {}

void main() {
  late MockConsultationRepository mockRepo;

  const testAffordableResult = ConsultationResultEntity(
    itemName: 'Buku Finansial',
    estimatedPrice: 150000,
    verdict: ConsultationVerdict.affordable,
    explanation: 'Pembelian dapat diterima.',
    freeCash: 4250000,
    remainingCash: 4100000,
  );

  const testNotRecommendedResult = ConsultationResultEntity(
    itemName: 'Laptop Gaming Mewah',
    estimatedPrice: 25000000,
    verdict: ConsultationVerdict.notRecommended,
    explanation: 'Tidak direkomendasikan karena melebihi kas bebas.',
    opportunityCost: 'Menunda target dana darurat selama 5 bulan.',
    freeCash: 4250000,
    remainingCash: -20750000,
  );

  const testInsufficientDataResult = ConsultationResultEntity(
    itemName: 'Sepatu Lari',
    estimatedPrice: 1200000,
    verdict: ConsultationVerdict.insufficientData,
    explanation: 'Data profil belum lengkap.',
    freeCash: 0,
    remainingCash: 0,
  );

  setUp(() {
    mockRepo = MockConsultationRepository();
  });

  group('ConsultationCubit', () {
    test('initial state is ConsultationInitial', () {
      final cubit = ConsultationCubit(consultationRepository: mockRepo);
      expect(cubit.state, const ConsultationInitial());
      cubit.close();
    });

    blocTest<ConsultationCubit, ConsultationState>(
      'emits error if item name is empty',
      build: () => ConsultationCubit(consultationRepository: mockRepo),
      act: (cubit) =>
          cubit.consultPurchase(itemName: '', estimatedPrice: 100000),
      expect: () => [const ConsultationError('Nama barang wajib diisi')],
    );

    blocTest<ConsultationCubit, ConsultationState>(
      'emits error if estimated price is non-positive',
      build: () => ConsultationCubit(consultationRepository: mockRepo),
      act: (cubit) =>
          cubit.consultPurchase(itemName: 'Kamera', estimatedPrice: 0),
      expect: () => [
        const ConsultationError('Harga barang harus lebih dari 0'),
      ],
    );

    blocTest<ConsultationCubit, ConsultationState>(
      'emits [Loading, Success] with affordable result when purchase is within budget',
      build: () {
        when(
          () => mockRepo.consultPurchase(
            itemName: any(named: 'itemName'),
            estimatedPrice: any(named: 'estimatedPrice'),
            categoryName: any(named: 'categoryName'),
          ),
        ).thenAnswer((_) async => const Success(testAffordableResult));
        return ConsultationCubit(consultationRepository: mockRepo);
      },
      act: (cubit) => cubit.consultPurchase(
        itemName: 'Buku Finansial',
        estimatedPrice: 150000,
        categoryName: 'Pendidikan',
      ),
      expect: () => [
        const ConsultationLoading(),
        const ConsultationSuccess(testAffordableResult),
      ],
    );

    blocTest<ConsultationCubit, ConsultationState>(
      'emits [Loading, Success] with notRecommended and opportunity cost when purchase exceeds free cash',
      build: () {
        when(
          () => mockRepo.consultPurchase(
            itemName: any(named: 'itemName'),
            estimatedPrice: any(named: 'estimatedPrice'),
            categoryName: any(named: 'categoryName'),
          ),
        ).thenAnswer((_) async => const Success(testNotRecommendedResult));
        return ConsultationCubit(consultationRepository: mockRepo);
      },
      act: (cubit) => cubit.consultPurchase(
        itemName: 'Laptop Gaming Mewah',
        estimatedPrice: 25000000,
      ),
      expect: () => [
        const ConsultationLoading(),
        const ConsultationSuccess(testNotRecommendedResult),
      ],
    );

    blocTest<ConsultationCubit, ConsultationState>(
      'emits [Loading, Success] with insufficientData when profile is incomplete (PRD exit criteria)',
      build: () {
        when(
          () => mockRepo.consultPurchase(
            itemName: any(named: 'itemName'),
            estimatedPrice: any(named: 'estimatedPrice'),
            categoryName: any(named: 'categoryName'),
          ),
        ).thenAnswer((_) async => const Success(testInsufficientDataResult));
        return ConsultationCubit(consultationRepository: mockRepo);
      },
      act: (cubit) => cubit.consultPurchase(
        itemName: 'Sepatu Lari',
        estimatedPrice: 1200000,
      ),
      expect: () => [
        const ConsultationLoading(),
        const ConsultationSuccess(testInsufficientDataResult),
      ],
    );

    blocTest<ConsultationCubit, ConsultationState>(
      'emits [Loading, Error] when repository throws a failure',
      build: () {
        when(
          () => mockRepo.consultPurchase(
            itemName: any(named: 'itemName'),
            estimatedPrice: any(named: 'estimatedPrice'),
            categoryName: any(named: 'categoryName'),
          ),
        ).thenAnswer(
          (_) async => const ErrorResult(ServerFailure('Koneksi terputus')),
        );
        return ConsultationCubit(consultationRepository: mockRepo);
      },
      act: (cubit) => cubit.consultPurchase(
        itemName: 'Sepatu Lari',
        estimatedPrice: 1200000,
      ),
      expect: () => [
        const ConsultationLoading(),
        const ConsultationError('Koneksi terputus'),
      ],
    );
  });
}
