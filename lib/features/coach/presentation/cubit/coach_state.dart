import 'package:equatable/equatable.dart';
import '../../domain/entities/chat_conversation_entity.dart';
import '../../domain/entities/chat_message_entity.dart';

abstract class CoachState extends Equatable {
  const CoachState();

  @override
  List<Object?> get props => [];
}

class CoachInitial extends CoachState {
  const CoachInitial();
}

class CoachLoading extends CoachState {
  const CoachLoading();
}

class CoachLoaded extends CoachState {
  final List<ChatMessageEntity> messages;
  final bool isSending;
  final bool isScanningReceipt;
  final String? confirmingMessageId;
  final String? activeConversationId;
  final String? activeConversationTitle;
  final List<ChatConversationEntity> conversations;
  final bool isLoadingConversations;

  const CoachLoaded({
    required this.messages,
    this.isSending = false,
    this.isScanningReceipt = false,
    this.confirmingMessageId,
    this.activeConversationId,
    this.activeConversationTitle,
    this.conversations = const [],
    this.isLoadingConversations = false,
  });

  CoachLoaded copyWith({
    List<ChatMessageEntity>? messages,
    bool? isSending,
    bool? isScanningReceipt,
    String? confirmingMessageId,
    bool clearConfirming = false,
    String? activeConversationId,
    bool clearActiveConversation = false,
    String? activeConversationTitle,
    List<ChatConversationEntity>? conversations,
    bool? isLoadingConversations,
  }) {
    return CoachLoaded(
      messages: messages ?? this.messages,
      isSending: isSending ?? this.isSending,
      isScanningReceipt: isScanningReceipt ?? this.isScanningReceipt,
      confirmingMessageId: clearConfirming
          ? null
          : (confirmingMessageId ?? this.confirmingMessageId),
      activeConversationId: clearActiveConversation
          ? null
          : (activeConversationId ?? this.activeConversationId),
      activeConversationTitle: clearActiveConversation
          ? null
          : (activeConversationTitle ?? this.activeConversationTitle),
      conversations: conversations ?? this.conversations,
      isLoadingConversations:
          isLoadingConversations ?? this.isLoadingConversations,
    );
  }

  @override
  List<Object?> get props => [
        messages,
        isSending,
        isScanningReceipt,
        confirmingMessageId,
        activeConversationId,
        activeConversationTitle,
        conversations,
        isLoadingConversations,
      ];
}

class CoachError extends CoachState {
  final String message;

  const CoachError(this.message);

  @override
  List<Object?> get props => [message];
}
