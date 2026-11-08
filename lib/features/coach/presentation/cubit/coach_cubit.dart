import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../../transactions/domain/entities/category_entity.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../../transactions/domain/repositories/category_and_account_repository.dart';
import '../../../transactions/domain/repositories/transaction_repository.dart';
import '../../domain/entities/chat_message_entity.dart';
import '../../domain/repositories/coach_repository.dart';
import 'coach_state.dart';

class CoachCubit extends Cubit<CoachState> {
  final CoachRepository coachRepository;
  final TransactionRepository? transactionRepository;
  final CategoryRepository? categoryRepository;
  final Uuid _uuid = const Uuid();

  CoachCubit({
    required this.coachRepository,
    this.transactionRepository,
    this.categoryRepository,
  }) : super(const CoachInitial());

  void reset() {
    coachRepository.clearLocalHistory();
    emit(const CoachInitial());
  }

  Future<void> loadChatHistory({String? conversationId}) async {
    emit(const CoachLoading());
    final result = await coachRepository.getChatHistory(conversationId: conversationId);

    result.fold(
      (messages) {
        String? activeId = conversationId;
        if (activeId == null && messages.isNotEmpty) {
          activeId = messages.first.conversationId;
        }
        if (messages.isEmpty) {
          // Initial greeting from Coach FinGuard
          final welcomeMessage = ChatMessageEntity(
            id: 'welcome',
            conversationId: activeId ?? 'default',
            senderType: ChatSenderType.assistant,
            content: 'Halo! Saya Coach FinGuard, pelatih keuangan pribadimu.\n\nKamu bisa mencatat pengeluaran langsung dengan bahasa sehari-hari (contoh: "Tadi makan siang Rp35.000") atau berkonsultasi sebelum belanja.',
            createdAt: DateTime.now(),
          );
          emit(CoachLoaded(
            messages: [welcomeMessage],
            activeConversationId: activeId,
          ));
        } else {
          emit(CoachLoaded(
            messages: messages,
            activeConversationId: activeId,
          ));
        }
      },
      (failure) => emit(CoachError(failure.message)),
    );
  }

  /// Start a brand new conversation thread
  Future<void> startNewConversation() async {
    emit(const CoachLoading());
    final result = await coachRepository.createConversation(title: 'Percakapan Baru');

    result.fold(
      (newConv) {
        final welcomeMessage = ChatMessageEntity(
          id: 'welcome_${DateTime.now().millisecondsSinceEpoch}',
          conversationId: newConv.id,
          senderType: ChatSenderType.assistant,
          content: 'Halo! Saya Coach FinGuard, pelatih keuangan pribadimu.\n\nKamu bisa mencatat pengeluaran langsung dengan bahasa sehari-hari (contoh: "Tadi makan siang Rp35.000") atau berkonsultasi sebelum belanja.',
          createdAt: DateTime.now(),
        );
        emit(CoachLoaded(
          messages: [welcomeMessage],
          activeConversationId: newConv.id,
          activeConversationTitle: newConv.title,
        ));
      },
      (failure) {
        final localConvId = 'conv_local_${DateTime.now().millisecondsSinceEpoch}';
        final welcomeMessage = ChatMessageEntity(
          id: 'welcome_${DateTime.now().millisecondsSinceEpoch}',
          conversationId: localConvId,
          senderType: ChatSenderType.assistant,
          content: 'Halo! Saya Coach FinGuard, pelatih keuangan pribadimu.\n\nKamu bisa mencatat pengeluaran langsung dengan bahasa sehari-hari (contoh: "Tadi makan siang Rp35.000") atau berkonsultasi sebelum belanja.',
          createdAt: DateTime.now(),
        );
        emit(CoachLoaded(
          messages: [welcomeMessage],
          activeConversationId: localConvId,
          activeConversationTitle: 'Percakapan Baru',
        ));
      },
    );
  }

  /// Load all conversations list for history page
  Future<void> loadConversations() async {
    if (state is CoachLoaded) {
      emit((state as CoachLoaded).copyWith(isLoadingConversations: true));
    }
    final result = await coachRepository.getConversations();
    result.fold(
      (conversations) {
        if (state is CoachLoaded) {
          emit((state as CoachLoaded).copyWith(
            conversations: conversations,
            isLoadingConversations: false,
          ));
        } else {
          emit(CoachLoaded(
            messages: const [],
            conversations: conversations,
            isLoadingConversations: false,
          ));
        }
      },
      (failure) {
        if (state is CoachLoaded) {
          emit((state as CoachLoaded).copyWith(isLoadingConversations: false));
        }
      },
    );
  }

  /// Delete a conversation thread and its messages
  Future<void> deleteConversation(String conversationId) async {
    final result = await coachRepository.deleteConversation(conversationId);
    result.fold(
      (_) async {
        final currentState = state is CoachLoaded ? (state as CoachLoaded) : null;
        if (currentState?.activeConversationId == conversationId) {
          await startNewConversation();
        }
        await loadConversations();
      },
      (failure) {},
    );
  }

  Future<void> sendMessage(
    String text, {
    String? conversationId,
    bool requestAudio = false,
  }) async {
    if (text.trim().isEmpty) return;

    final currentState = state is CoachLoaded ? (state as CoachLoaded) : null;
    final currentMessages = currentState?.messages ?? <ChatMessageEntity>[];
    final activeConvId = conversationId ?? currentState?.activeConversationId;

    final clientRequestId = _uuid.v4();

    // Optimistically add user message
    final userMessage = ChatMessageEntity(
      id: clientRequestId,
      conversationId: activeConvId ?? 'default',
      senderType: ChatSenderType.user,
      content: text,
      structuredPayload: requestAudio ? {'request_audio': true} : null,
      clientRequestId: clientRequestId,
      createdAt: DateTime.now(),
    );

    emit((currentState ?? CoachLoaded(messages: currentMessages)).copyWith(
      messages: [...currentMessages, userMessage],
      isSending: true,
      activeConversationId: activeConvId,
    ));

    final result = await coachRepository.sendMessage(
      message: text,
      conversationId: activeConvId,
      clientRequestId: clientRequestId,
      requestAudio: requestAudio,
    );

    result.fold(
      (replyEntity) {
        final updatedState = state is CoachLoaded ? (state as CoachLoaded) : null;
        final updated = updatedState?.messages ?? <ChatMessageEntity>[];
        emit((updatedState ?? CoachLoaded(messages: updated)).copyWith(
          messages: [...updated, replyEntity],
          isSending: false,
          isScanningReceipt: false,
          activeConversationId: replyEntity.conversationId.isNotEmpty
              ? replyEntity.conversationId
              : activeConvId,
        ));
      },
      (failure) {
        // Add a failed message that can be retried
        final failedMessage = ChatMessageEntity(
          id: 'error_${_uuid.v4()}',
          conversationId: activeConvId ?? 'default',
          senderType: ChatSenderType.assistant,
          content: failure.message,
          clientRequestId: clientRequestId,
          createdAt: DateTime.now(),
          status: ChatMessageStatus.failed,
        );
        final updatedState = state is CoachLoaded ? (state as CoachLoaded) : null;
        final messagesWithError = updatedState != null
            ? [...updatedState.messages, failedMessage]
            : [failedMessage];
        emit((updatedState ?? CoachLoaded(messages: messagesWithError)).copyWith(
          messages: messagesWithError,
          isSending: false,
          isScanningReceipt: false,
          activeConversationId: activeConvId,
        ));
      },
    );
  }

  /// Send a message with an attached receipt image path & base64 data
  Future<void> sendReceiptScan({
    required String receiptPath,
    String? receiptBase64,
    String? caption,
    String? conversationId,
  }) async {
    final activeConvId = conversationId ??
        (state is CoachLoaded
            ? (state as CoachLoaded).activeConversationId
            : null);

    final text = (caption != null && caption.trim().isNotEmpty)
        ? caption.trim()
        : 'Tolong catat transaksi dari nota ini';

    final clientRequestId = _uuid.v4();
    final userMessage = ChatMessageEntity(
      id: 'usr_${DateTime.now().millisecondsSinceEpoch}',
      conversationId: activeConvId ?? 'default',
      senderType: ChatSenderType.user,
      content: text,
      structuredPayload: {'receipt_path': receiptPath},
      clientRequestId: clientRequestId,
      createdAt: DateTime.now(),
    );

    final currentMessages = state is CoachLoaded
        ? (state as CoachLoaded).messages
        : <ChatMessageEntity>[];

    emit((state is CoachLoaded ? (state as CoachLoaded) : CoachLoaded(messages: currentMessages)).copyWith(
      messages: [...currentMessages, userMessage],
      isSending: true,
      isScanningReceipt: true,
      activeConversationId: activeConvId,
    ));

    final result = await coachRepository.sendMessage(
      message: text,
      conversationId: activeConvId,
      clientRequestId: clientRequestId,
      receiptPath: receiptPath,
      receiptBase64: receiptBase64,
    );

    result.fold(
      (replyEntity) {
        final updatedState = state is CoachLoaded ? (state as CoachLoaded) : null;
        final updated = updatedState?.messages ?? <ChatMessageEntity>[];
        emit((updatedState ?? CoachLoaded(messages: updated)).copyWith(
          messages: [...updated, replyEntity],
          isSending: false,
          isScanningReceipt: false,
          activeConversationId: replyEntity.conversationId.isNotEmpty
              ? replyEntity.conversationId
              : activeConvId,
        ));
      },
      (failure) {
        final failedMessage = ChatMessageEntity(
          id: 'error_${_uuid.v4()}',
          conversationId: activeConvId ?? 'default',
          senderType: ChatSenderType.assistant,
          content: failure.message,
          clientRequestId: clientRequestId,
          createdAt: DateTime.now(),
          status: ChatMessageStatus.failed,
        );
        final updatedState = state is CoachLoaded ? (state as CoachLoaded) : null;
        final messagesWithError = updatedState != null
            ? [...updatedState.messages, failedMessage]
            : [failedMessage];
        emit((updatedState ?? CoachLoaded(messages: messagesWithError)).copyWith(
          messages: messagesWithError,
          isSending: false,
          isScanningReceipt: false,
          activeConversationId: activeConvId,
        ));
      },
    );
  }

  /// Retry the last failed message by re-sending the user's original text
  Future<void> retryLastMessage({String? conversationId}) async {
    if (state is! CoachLoaded) return;

    final currentState = state as CoachLoaded;
    final messages = currentState.messages;
    final activeConvId = conversationId ?? currentState.activeConversationId;

    // Find and remove the last error message, then find the user message before it
    final lastFailedIndex = messages.lastIndexWhere((m) => m.isRetryable);
    if (lastFailedIndex == -1) return;

    // Find the user message right before the error
    String? userText;
    int userMsgIndex = -1;
    for (int i = lastFailedIndex - 1; i >= 0; i--) {
      if (messages[i].isUser) {
        userText = messages[i].content;
        userMsgIndex = i;
        break;
      }
    }

    if (userText == null || userMsgIndex == -1) return;

    // Remove both the failed message and the original user message, then re-send
    final cleanedMessages = List<ChatMessageEntity>.from(messages);
    cleanedMessages.removeAt(lastFailedIndex);
    cleanedMessages.removeAt(userMsgIndex);

    emit(currentState.copyWith(messages: cleanedMessages, isSending: false));

    // Re-send with a new idempotency key
    await sendMessage(userText, conversationId: activeConvId);
  }

  /// Dismiss the last error message
  void dismissError() {
    if (state is! CoachLoaded) return;

    final messages = (state as CoachLoaded).messages;
    final lastFailedIndex = messages.lastIndexWhere((m) => m.isRetryable);
    if (lastFailedIndex == -1) return;

    final cleanedMessages = List<ChatMessageEntity>.from(messages);
    cleanedMessages.removeAt(lastFailedIndex);

    emit(CoachLoaded(messages: cleanedMessages, isSending: false));
  }

  /// Confirm and persist extracted transaction to database
  Future<void> confirmExtractedTransaction(ChatMessageEntity message) async {
    if (state is! CoachLoaded || transactionRepository == null) return;
    final currentState = state as CoachLoaded;
    final payload = message.structuredPayload;
    if (payload == null || payload['amount'] == null) return;

    emit(currentState.copyWith(confirmingMessageId: message.id));

    try {
      final amount = (payload['amount'] as num).toDouble();
      final isIncome = payload['type'] == 'income';
      final note = payload['note']?.toString() ?? 'Transaksi Coach AI';
      final clientReqId = _uuid.v4();

      String? categoryId;
      final catSuggestion = payload['category_suggestion']?.toString().toLowerCase().trim();
      if (catSuggestion != null && categoryRepository != null) {
        final catsRes = await categoryRepository!.getCategories(
          type: isIncome ? TransactionType.income : TransactionType.expense,
        );
        catsRes.fold((categories) {
          for (final c in categories) {
            final cLower = c.name.toLowerCase();
            if (cLower == catSuggestion || cLower.contains(catSuggestion) || catSuggestion.contains(cLower)) {
              categoryId = c.id;
              break;
            }
          }
        }, (_) {});
      }

      final txResult = await transactionRepository!.createTransaction(
        amount: amount,
        type: isIncome ? TransactionType.income : TransactionType.expense,
        transactionDate: DateTime.now(),
        categoryId: categoryId,
        note: note,
        source: TransactionSource.chat,
        clientRequestId: clientReqId,
      );

      txResult.fold(
        (createdTx) async {
          // Persist confirmed status in chat_messages table
          try {
            await coachRepository.updateMessageMetadata(
              messageId: message.id,
              metadata: {
                ...?message.structuredPayload,
                'confirmed': true,
                'transaction_id': createdTx.id,
              },
            );
          } catch (_) {}

          // Update the message state to confirmed
          final updatedMessages = currentState.messages.map((m) {
            if (m.id == message.id) {
              return m.copyWith(isConfirmed: true);
            }
            return m;
          }).toList();

          emit(currentState.copyWith(
            messages: updatedMessages,
            clearConfirming: true,
          ));
        },
        (failure) {
          emit(currentState.copyWith(clearConfirming: true));
        },
      );
    } catch (_) {
      emit(currentState.copyWith(clearConfirming: true));
    }
  }

  /// Cancel/reject an unconfirmed extracted transaction card
  Future<void> cancelExtractedTransaction(ChatMessageEntity message) async {
    if (state is! CoachLoaded) return;
    final currentState = state as CoachLoaded;

    final updatedMessages = currentState.messages.map((m) {
      if (m.id == message.id) {
        return m.copyWith(
          structuredPayload: {
            ...?m.structuredPayload,
            'rejected': true,
            'cancelled': true,
          },
        );
      }
      return m;
    }).toList();

    emit(currentState.copyWith(messages: updatedMessages));

    try {
      await coachRepository.updateMessageMetadata(
        messageId: message.id,
        metadata: {
          ...?message.structuredPayload,
          'rejected': true,
          'cancelled': true,
        },
      );
    } catch (_) {}
  }
}
