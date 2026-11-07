import 'package:equatable/equatable.dart';

enum ChatSenderType {
  user,
  assistant,
  system;

  static ChatSenderType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'user':
        return ChatSenderType.user;
      case 'system':
        return ChatSenderType.system;
      case 'assistant':
      default:
        return ChatSenderType.assistant;
    }
  }

  String toDbString() => name;
}

/// Message status for tracking AI lifecycle
enum ChatMessageStatus {
  sending,
  completed,
  needsClarification,
  failed;

  static ChatMessageStatus fromString(String? value) {
    switch (value) {
      case 'sending':
      case 'processing':
        return ChatMessageStatus.sending;
      case 'needs_clarification':
        return ChatMessageStatus.needsClarification;
      case 'failed':
        return ChatMessageStatus.failed;
      case 'completed':
      case 'sent':
      default:
        return ChatMessageStatus.completed;
    }
  }

  String toDbString() {
    switch (this) {
      case ChatMessageStatus.sending:
        return 'processing';
      case ChatMessageStatus.failed:
        return 'failed';
      case ChatMessageStatus.needsClarification:
      case ChatMessageStatus.completed:
        return 'completed';
    }
  }
}

class ChatMessageEntity extends Equatable {
  final String id;
  final String conversationId;
  final ChatSenderType senderType;
  final String content;
  final String? clientRequestId;
  final DateTime createdAt;
  final Map<String, dynamic>? structuredPayload;
  final ChatMessageStatus status;
  final bool needsClarification;
  final List<String> missingFields;
  final bool isConfirmed;

  const ChatMessageEntity({
    required this.id,
    required this.conversationId,
    required this.senderType,
    required this.content,
    this.clientRequestId,
    required this.createdAt,
    this.structuredPayload,
    this.status = ChatMessageStatus.completed,
    this.needsClarification = false,
    this.missingFields = const [],
    this.isConfirmed = false,
  });

  ChatMessageEntity copyWith({
    String? id,
    String? conversationId,
    ChatSenderType? senderType,
    String? content,
    String? clientRequestId,
    DateTime? createdAt,
    Map<String, dynamic>? structuredPayload,
    ChatMessageStatus? status,
    bool? needsClarification,
    List<String>? missingFields,
    bool? isConfirmed,
  }) {
    return ChatMessageEntity(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderType: senderType ?? this.senderType,
      content: content ?? this.content,
      clientRequestId: clientRequestId ?? this.clientRequestId,
      createdAt: createdAt ?? this.createdAt,
      structuredPayload: structuredPayload ?? this.structuredPayload,
      status: status ?? this.status,
      needsClarification: needsClarification ?? this.needsClarification,
      missingFields: missingFields ?? this.missingFields,
      isConfirmed: isConfirmed ?? this.isConfirmed,
    );
  }

  bool get isUser => senderType == ChatSenderType.user;

  /// Whether this message has a pending extracted transaction awaiting confirmation
  bool get hasPendingExtraction =>
      !isUser &&
      !isConfirmed &&
      !needsClarification &&
      structuredPayload != null &&
      structuredPayload!['amount'] != null &&
      ((structuredPayload!['amount'] as num?) ?? 0) > 0;

  /// Whether this message represents a failed delivery that can be retried
  bool get isRetryable => status == ChatMessageStatus.failed;

  @override
  List<Object?> get props => [
        id,
        conversationId,
        senderType,
        content,
        clientRequestId,
        createdAt,
        structuredPayload,
        status,
        needsClarification,
        missingFields,
        isConfirmed,
      ];
}
