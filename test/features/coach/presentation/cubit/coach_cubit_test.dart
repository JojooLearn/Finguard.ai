import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:finguard/core/errors/failure.dart';
import 'package:finguard/core/result/result.dart';
import 'package:finguard/features/coach/domain/entities/chat_message_entity.dart';
import 'package:finguard/features/coach/domain/repositories/coach_repository.dart';
import 'package:finguard/features/coach/presentation/cubit/coach_cubit.dart';
import 'package:finguard/features/coach/presentation/cubit/coach_state.dart';
import 'package:finguard/features/transactions/domain/entities/category_entity.dart';
import 'package:finguard/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finguard/features/transactions/domain/repositories/transaction_repository.dart';

class MockCoachRepository extends Mock implements CoachRepository {}
class MockTransactionRepository extends Mock implements TransactionRepository {}

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
  });
}
