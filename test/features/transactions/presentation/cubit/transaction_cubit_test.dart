import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:finguard/core/errors/failure.dart';
import 'package:finguard/core/result/result.dart';
import 'package:finguard/features/transactions/domain/entities/account_entity.dart';
import 'package:finguard/features/transactions/domain/entities/category_entity.dart';
import 'package:finguard/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finguard/features/transactions/domain/repositories/category_and_account_repository.dart';
import 'package:finguard/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:finguard/features/transactions/presentation/cubit/transaction_cubit.dart';
import 'package:finguard/features/transactions/presentation/cubit/transaction_state.dart';

class MockTransactionRepository extends Mock implements TransactionRepository {}
class MockCategoryRepository extends Mock implements CategoryRepository {}
class MockAccountRepository extends Mock implements AccountRepository {}

void main() {
  late MockTransactionRepository mockTxRepo;
  late MockCategoryRepository mockCatRepo;
  late MockAccountRepository mockAccRepo;

  setUpAll(() {
    registerFallbackValue(TransactionType.expense);
    registerFallbackValue(DateTime(2026, 1, 1));
  });

  final testDate = DateTime(2026, 10, 28);
  final testTx = TransactionEntity(
    id: 'tx-1',
    userId: 'user-1',
    transactionType: TransactionType.expense,
    amount: 50000,
    transactionDate: testDate,
    note: 'Makan Siang',
    createdAt: testDate,
    updatedAt: testDate,
  );

  setUp(() {
    mockTxRepo = MockTransactionRepository();
    mockCatRepo = MockCategoryRepository();
    mockAccRepo = MockAccountRepository();

    when(() => mockCatRepo.getCategories())
        .thenAnswer((_) async => const Success(<CategoryEntity>[]));
    when(() => mockAccRepo.getAccounts())
        .thenAnswer((_) async => const Success(<AccountEntity>[]));
  });

  group('TransactionCubit', () {
    test('initial state is TransactionInitial', () {
      final cubit = TransactionCubit(
        transactionRepository: mockTxRepo,
        categoryRepository: mockCatRepo,
        accountRepository: mockAccRepo,
      );
      expect(cubit.state, const TransactionInitial());
      cubit.close();
    });

    blocTest<TransactionCubit, TransactionState>(
      'emits [TransactionLoading, TransactionLoaded] on successful load',
      build: () {
        when(() => mockTxRepo.getTransactions(type: any(named: 'type')))
            .thenAnswer((_) async => Success([testTx]));
        return TransactionCubit(
          transactionRepository: mockTxRepo,
          categoryRepository: mockCatRepo,
          accountRepository: mockAccRepo,
        );
      },
      act: (cubit) => cubit.loadTransactions(),
      expect: () => [
        const TransactionLoading(),
        isA<TransactionLoaded>().having(
          (s) => s.transactions.length,
          'transactions length',
          1,
        ),
      ],
    );

    blocTest<TransactionCubit, TransactionState>(
      'emits [TransactionLoading, TransactionError] when repository fails',
      build: () {
        when(() => mockTxRepo.getTransactions(type: any(named: 'type')))
            .thenAnswer((_) async => const ErrorResult(ServerFailure('Database error')));
        return TransactionCubit(
          transactionRepository: mockTxRepo,
          categoryRepository: mockCatRepo,
          accountRepository: mockAccRepo,
        );
      },
      act: (cubit) => cubit.loadTransactions(),
      expect: () => [
        const TransactionLoading(),
        const TransactionError('Database error'),
      ],
    );

    blocTest<TransactionCubit, TransactionState>(
      'reloads transactions after addTransaction succeeds',
      build: () {
        when(() => mockTxRepo.createTransaction(
              amount: any(named: 'amount'),
              type: any(named: 'type'),
              transactionDate: any(named: 'transactionDate'),
              categoryId: any(named: 'categoryId'),
              accountId: any(named: 'accountId'),
              note: any(named: 'note'),
            )).thenAnswer((_) async => Success(testTx));
        when(() => mockTxRepo.getTransactions(type: any(named: 'type')))
            .thenAnswer((_) async => Success([testTx]));
        return TransactionCubit(
          transactionRepository: mockTxRepo,
          categoryRepository: mockCatRepo,
          accountRepository: mockAccRepo,
        );
      },
      act: (cubit) => cubit.addTransaction(
        amount: 50000,
        type: TransactionType.expense,
        transactionDate: testDate,
        note: 'Makan Siang',
      ),
      expect: () => [
        const TransactionLoading(),
        isA<TransactionLoaded>(),
      ],
      verify: (_) {
        verify(() => mockTxRepo.createTransaction(
              amount: 50000,
              type: TransactionType.expense,
              transactionDate: testDate,
              note: 'Makan Siang',
            )).called(1);
      },
    );
  });
}
