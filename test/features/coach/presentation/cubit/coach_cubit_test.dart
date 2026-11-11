import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:finguard/core/errors/failure.dart';
import 'package:finguard/core/result/result.dart';
import 'package:finguard/features/coach/domain/entities/chat_message_entity.dart';
import 'package:finguard/features/coach/domain/repositories/coach_repository.dart';
import 'package:finguard/features/coach/presentation/cubit/coach_cubit.dart';
import 'package:finguard/features/coach/presentation/cubit/coach_state.dart';
import 'package:finguard/features/goals/domain/entities/goal_entity.dart';
import 'package:finguard/features/goals/domain/repositories/goal_repository.dart';
import 'package:finguard/features/transactions/domain/entities/category_entity.dart';
import 'package:finguard/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finguard/features/transactions/domain/repositories/category_and_account_repository.dart';
import 'package:finguard/features/transactions/domain/repositories/transaction_repository.dart';

class MockCoachRepository extends Mock implements CoachRepository {}
class MockTransactionRepository extends Mock implements TransactionRepository {}
class MockCategoryRepository extends Mock implements CategoryRepository {}
class MockGoalRepository extends Mock implements GoalRepository {}

void main() {
  late MockCoachRepository mockCoachRepo;
  late MockTransactionRepository mockTxRepo;

  final testDate = DateTime(2026, 10, 29, 5, 0);
  final testReply = ChatMessageEntity(
    id: 'reply-1',
    conversationId: 'conv-1',
    senderType: ChatSenderType.assistant,
    content: 'Dicatat: Makan Siang sebesar Rp35.000.',
    createdAt: testDate,
  );

  setUpAll(() {
    registerFallbackValue(TransactionType.expense);
    registerFallbackValue(TransactionSource.chat);
    registerFallbackValue(DateTime.now());
  });

  setUp(() {
    mockCoachRepo = MockCoachRepository();
    mockTxRepo = MockTransactionRepository();
  });

  group('CoachCubit', () {
    test('initial state is CoachInitial', () {
      final cubit = CoachCubit(
        coachRepository: mockCoachRepo,
        transactionRepository: mockTxRepo,
      );
      expect(cubit.state, const CoachInitial());
      cubit.close();
    });

    blocTest<CoachCubit, CoachState>(
      'emits [CoachLoading, CoachLoaded] with default welcome message if history is empty',
      build: () {
        when(() => mockCoachRepo.getChatHistory(conversationId: any(named: 'conversationId')))
            .thenAnswer((_) async => const Success(<ChatMessageEntity>[]));
        return CoachCubit(
          coachRepository: mockCoachRepo,
          transactionRepository: mockTxRepo,
        );
      },
      act: (cubit) => cubit.loadChatHistory(),
      expect: () => [
        const CoachLoading(),
        isA<CoachLoaded>().having((s) => s.messages.length, 'messages length', 1),
      ],
    );

    blocTest<CoachCubit, CoachState>(
      'optimistically appends user message then appends assistant reply',
      build: () {
        when(() => mockCoachRepo.sendMessage(
              message: any(named: 'message'),
              conversationId: any(named: 'conversationId'),
              clientRequestId: any(named: 'clientRequestId'),
            )).thenAnswer((_) async => Success(testReply));
        return CoachCubit(
          coachRepository: mockCoachRepo,
          transactionRepository: mockTxRepo,
        );
      },
      act: (cubit) => cubit.sendMessage('Makan siang 35.000'),
      expect: () => [
        isA<CoachLoaded>().having((s) => s.isSending, 'isSending is true', true),
        isA<CoachLoaded>()
            .having((s) => s.isSending, 'isSending is false', false)
            .having((s) => s.messages.length, 'messages length', 2),
      ],
    );

    blocTest<CoachCubit, CoachState>(
      'appends failed message with retry capability when sending message fails',
      build: () {
        when(() => mockCoachRepo.sendMessage(
              message: any(named: 'message'),
              conversationId: any(named: 'conversationId'),
              clientRequestId: any(named: 'clientRequestId'),
            )).thenAnswer((_) async => const ErrorResult(ServerFailure('Gagal menghubungi AI')));
        return CoachCubit(
          coachRepository: mockCoachRepo,
          transactionRepository: mockTxRepo,
        );
      },
      act: (cubit) => cubit.sendMessage('Makan siang 35.000'),
      expect: () => [
        isA<CoachLoaded>().having((s) => s.isSending, 'isSending is true', true),
        isA<CoachLoaded>()
            .having((s) => s.isSending, 'isSending is false', false)
            .having((s) => s.messages.length, 'messages length', 2)
            .having((s) => s.messages.last.status, 'last message status', ChatMessageStatus.failed)
            .having((s) => s.messages.last.content, 'last message content', 'Gagal menghubungi AI'),
      ],
    );

    blocTest<CoachCubit, CoachState>(
      'confirms extracted transaction and creates real transaction record',
      build: () {
        final mockCreatedTx = TransactionEntity(
          id: 'tx-1',
          userId: 'user-1',
          transactionType: TransactionType.expense,
          amount: 35000,
          currencyCode: 'IDR',
          transactionDate: DateTime.now(),
          source: TransactionSource.chat,
          status: TransactionStatus.confirmed,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        when(() => mockTxRepo.createTransaction(
              amount: any(named: 'amount'),
              type: any(named: 'type'),
              transactionDate: any(named: 'transactionDate'),
              note: any(named: 'note'),
              source: any(named: 'source'),
              clientRequestId: any(named: 'clientRequestId'),
            )).thenAnswer((_) async => Success(mockCreatedTx));

        final cubit = CoachCubit(
          coachRepository: mockCoachRepo,
          transactionRepository: mockTxRepo,
        );

        return cubit;
      },
      seed: () => CoachLoaded(messages: [
        ChatMessageEntity(
          id: 'msg-extract-1',
          conversationId: 'conv-1',
          senderType: ChatSenderType.assistant,
          content: 'Saya deteksi pengeluaran 35.000',
          createdAt: DateTime.now(),
          structuredPayload: const {
            'amount': 35000.0,
            'type': 'expense',
            'note': 'Makan Siang',
          },
        ),
      ]),
      act: (cubit) {
        final msg = (cubit.state as CoachLoaded).messages.first;
        return cubit.confirmExtractedTransaction(msg);
      },
      expect: () => [
        isA<CoachLoaded>().having((s) => s.confirmingMessageId, 'confirmingMessageId', 'msg-extract-1'),
        isA<CoachLoaded>()
            .having((s) => s.confirmingMessageId, 'confirmingMessageId', null)
            .having((s) => s.messages.first.isConfirmed, 'isConfirmed', true),
      ],
      verify: (_) {
        verify(() => mockTxRepo.createTransaction(
              amount: 35000.0,
              type: TransactionType.expense,
              transactionDate: any(named: 'transactionDate'),
              note: 'Makan Siang',
              source: TransactionSource.chat,
              clientRequestId: any(named: 'clientRequestId'),
            )).called(1);
      },
    );

    blocTest<CoachCubit, CoachState>(
      'persists confirmed metadata in coachRepository and prevents duplicate confirm',
      build: () {
        final mockCreatedTx = TransactionEntity(
          id: 'tx-persist-1',
          userId: 'user-1',
          transactionType: TransactionType.expense,
          amount: 10000,
          currencyCode: 'IDR',
          transactionDate: DateTime.now(),
          source: TransactionSource.chat,
          status: TransactionStatus.confirmed,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        when(() => mockTxRepo.createTransaction(
              amount: any(named: 'amount'),
              type: any(named: 'type'),
              transactionDate: any(named: 'transactionDate'),
              note: any(named: 'note'),
              source: any(named: 'source'),
              clientRequestId: any(named: 'clientRequestId'),
            )).thenAnswer((_) async => Success(mockCreatedTx));

        when(() => mockCoachRepo.updateMessageMetadata(
              messageId: any(named: 'messageId'),
              metadata: any(named: 'metadata'),
            )).thenAnswer((_) async {});

        return CoachCubit(
          coachRepository: mockCoachRepo,
          transactionRepository: mockTxRepo,
        );
      },
      seed: () => CoachLoaded(messages: [
        ChatMessageEntity(
          id: '11111111-1111-4111-8111-111111111111',
          conversationId: 'conv-1',
          senderType: ChatSenderType.assistant,
          content: 'Rp10.000 buat makan?',
          createdAt: DateTime.now(),
          structuredPayload: const {
            'amount': 10000.0,
            'type': 'expense',
            'note': 'Makan siang',
          },
        ),
      ]),
      act: (cubit) async {
        final msg = (cubit.state as CoachLoaded).messages.first;
        await cubit.confirmExtractedTransaction(msg);
        // Second call with updated confirmed message must be a no-op
        final confirmedMsg = (cubit.state as CoachLoaded).messages.first;
        await cubit.confirmExtractedTransaction(confirmedMsg);
      },
      expect: () => [
        isA<CoachLoaded>().having(
          (s) => s.confirmingMessageId,
          'confirmingMessageId',
          '11111111-1111-4111-8111-111111111111',
        ),
        isA<CoachLoaded>()
            .having((s) => s.confirmingMessageId, 'confirmingMessageId', null)
            .having((s) => s.messages.first.isConfirmed, 'isConfirmed', true)
            .having(
              (s) => s.messages.first.structuredPayload?['confirmed'],
              'metadata confirmed',
              true,
            )
            .having(
              (s) => s.messages.first.structuredPayload?['transaction_id'],
              'metadata transaction_id',
              'tx-persist-1',
            ),
      ],
      verify: (_) {
        verify(() => mockTxRepo.createTransaction(
              amount: 10000.0,
              type: TransactionType.expense,
              transactionDate: any(named: 'transactionDate'),
              note: 'Makan siang',
              source: TransactionSource.chat,
              clientRequestId: any(named: 'clientRequestId'),
            )).called(1);
        verify(() => mockCoachRepo.updateMessageMetadata(
              messageId: '11111111-1111-4111-8111-111111111111',
              metadata: {
                'amount': 10000.0,
                'type': 'expense',
                'note': 'Makan siang',
                'confirmed': true,
                'transaction_id': 'tx-persist-1',
              },
            )).called(1);
      },
    );

    blocTest<CoachCubit, CoachState>(
      'switches funding source between emergency_fund and regular fallback category',
      build: () {
        when(() => mockCoachRepo.updateMessageMetadata(
              messageId: any(named: 'messageId'),
              metadata: any(named: 'metadata'),
            )).thenAnswer((_) async {});
        return CoachCubit(
          coachRepository: mockCoachRepo,
          transactionRepository: mockTxRepo,
        );
      },
      seed: () => CoachLoaded(messages: [
        ChatMessageEntity(
          id: '22222222-2222-4222-8222-222222222222',
          conversationId: 'conv-1',
          senderType: ChatSenderType.assistant,
          content: 'Tambal ban Rp20.000',
          createdAt: testDate,
          structuredPayload: const {
            'amount': 20000.0,
            'type': 'expense',
            'note': 'Tambal ban darurat',
            'category_suggestion': 'Dana Darurat',
            'funding_source': 'emergency_fund',
            'fallback_category_suggestion': 'Transportasi',
          },
        ),
      ]),
      act: (cubit) async {
        final msg = (cubit.state as CoachLoaded).messages.first;
        await cubit.switchTransactionFundingSource(msg, useEmergencyFund: false);
      },
      expect: () => [
        isA<CoachLoaded>()
            .having(
              (s) => s.messages.first.structuredPayload?['funding_source'],
              'funding_source',
              'regular',
            )
            .having(
              (s) => s.messages.first.structuredPayload?['category_suggestion'],
              'category_suggestion',
              'Transportasi',
            ),
      ],
    );

    blocTest<CoachCubit, CoachState>(
      'deducts Dana Darurat and records transaction under Lainnya when funding_source is emergency_fund',
      build: () {
        final mockCatRepo = MockCategoryRepository();
        final mockGoalRepo = MockGoalRepository();
        final now = DateTime.now();

        when(() => mockGoalRepo.getGoals()).thenAnswer((_) async => Success([
              GoalEntity(
                id: 'goal-emergency-1',
                userId: 'user-1',
                name: 'Dana Darurat',
                goalType: GoalType.emergencyFund,
                targetAmount: 6750000,
                currentAmount: 200000,
                createdAt: now,
                updatedAt: now,
              ),
            ]));

        when(() => mockGoalRepo.addContribution(
              goalId: 'goal-emergency-1',
              amount: -20000.0,
              date: any(named: 'date'),
              note: any(named: 'note'),
            )).thenAnswer((_) async => Success(GoalEntity(
              id: 'goal-emergency-1',
              userId: 'user-1',
              name: 'Dana Darurat',
              goalType: GoalType.emergencyFund,
              targetAmount: 6750000,
              currentAmount: 180000,
              createdAt: now,
              updatedAt: now,
            )));

        when(() => mockCatRepo.getCategories(type: TransactionType.expense))
            .thenAnswer((_) async => Success([
                  CategoryEntity(
                    id: 'cat-transport',
                    name: 'Transportasi',
                    transactionType: TransactionType.expense,
                    createdAt: now,
                    updatedAt: now,
                  ),
                  CategoryEntity(
                    id: 'cat-other',
                    name: 'Lainnya',
                    transactionType: TransactionType.expense,
                    createdAt: now,
                    updatedAt: now,
                  ),
                ]));

        when(() => mockTxRepo.createTransaction(
              amount: 20000.0,
              type: TransactionType.expense,
              transactionDate: any(named: 'transactionDate'),
              categoryId: 'cat-other',
              note: any(named: 'note'),
              source: TransactionSource.chat,
              clientRequestId: any(named: 'clientRequestId'),
            )).thenAnswer((_) async => Success(TransactionEntity(
              id: 'tx-emg-1',
              userId: 'user-1',
              transactionType: TransactionType.expense,
              amount: 20000,
              categoryId: 'cat-other',
              currencyCode: 'IDR',
              transactionDate: now,
              source: TransactionSource.chat,
              status: TransactionStatus.confirmed,
              createdAt: now,
              updatedAt: now,
            )));

        when(() => mockCoachRepo.updateMessageMetadata(
              messageId: any(named: 'messageId'),
              metadata: any(named: 'metadata'),
            )).thenAnswer((_) async {});

        return CoachCubit(
          coachRepository: mockCoachRepo,
          transactionRepository: mockTxRepo,
          categoryRepository: mockCatRepo,
          goalRepository: mockGoalRepo,
        );
      },
      seed: () => CoachLoaded(messages: [
        ChatMessageEntity(
          id: '33333333-3333-4333-8333-333333333333',
          conversationId: 'conv-1',
          senderType: ChatSenderType.assistant,
          content: 'Tambal ban pakai Dana Darurat Rp20.000',
          createdAt: testDate,
          structuredPayload: const {
            'amount': 20000.0,
            'type': 'expense',
            'note': 'Tambal ban darurat',
            'category_suggestion': 'Dana Darurat',
            'funding_source': 'emergency_fund',
            'fallback_category_suggestion': 'Transportasi',
          },
        ),
      ]),
      act: (cubit) async {
        final msg = (cubit.state as CoachLoaded).messages.first;
        await cubit.confirmExtractedTransaction(msg);
      },
      expect: () => [
        isA<CoachLoaded>().having(
          (s) => s.confirmingMessageId,
          'confirmingMessageId',
          '33333333-3333-4333-8333-333333333333',
        ),
        isA<CoachLoaded>()
            .having((s) => s.confirmingMessageId, 'confirmingMessageId', null)
            .having((s) => s.messages.first.isConfirmed, 'isConfirmed', true),
      ],
      verify: (_) {
        verify(() => mockTxRepo.createTransaction(
              amount: 20000.0,
              type: TransactionType.expense,
              transactionDate: any(named: 'transactionDate'),
              categoryId: 'cat-other',
              note: any(named: 'note'),
              source: TransactionSource.chat,
              clientRequestId: any(named: 'clientRequestId'),
            )).called(1);
      },
    );

    blocTest<CoachCubit, CoachState>(
      'emits feedback message and aborts withdrawal when Dana Darurat balance is insufficient',
      build: () {
        final mockGoalRepo = MockGoalRepository();
        final now = DateTime.now();

        when(() => mockGoalRepo.getGoals()).thenAnswer((_) async => Success([
              GoalEntity(
                id: 'goal-emergency-1',
                userId: 'user-1',
                name: 'Dana Darurat',
                goalType: GoalType.emergencyFund,
                targetAmount: 6750000,
                currentAmount: 10000,
                createdAt: now,
                updatedAt: now,
              ),
            ]));

        return CoachCubit(
          coachRepository: mockCoachRepo,
          transactionRepository: mockTxRepo,
          goalRepository: mockGoalRepo,
        );
      },
      seed: () => CoachLoaded(messages: [
        ChatMessageEntity(
          id: '44444444-4444-4444-8444-444444444444',
          conversationId: 'conv-1',
          senderType: ChatSenderType.assistant,
          content: 'Tambal ban Rp20.000',
          createdAt: testDate,
          structuredPayload: const {
            'amount': 20000.0,
            'type': 'expense',
            'note': 'Tambal ban darurat',
            'category_suggestion': 'Dana Darurat',
            'funding_source': 'emergency_fund',
            'fallback_category_suggestion': 'Transportasi',
          },
        ),
      ]),
      act: (cubit) async {
        final msg = (cubit.state as CoachLoaded).messages.first;
        await cubit.confirmExtractedTransaction(msg);
      },
      expect: () => [
        isA<CoachLoaded>().having(
          (s) => s.confirmingMessageId,
          'confirmingMessageId',
          '44444444-4444-4444-8444-444444444444',
        ),
        isA<CoachLoaded>()
            .having((s) => s.confirmingMessageId, 'confirmingMessageId', null)
            .having((s) => s.messages.first.isConfirmed, 'isConfirmed', false)
            .having(
              (s) => s.confirmFeedbackMessage,
              'confirmFeedbackMessage',
              contains('tidak cukup'),
            ),
      ],
    );
  });
}
