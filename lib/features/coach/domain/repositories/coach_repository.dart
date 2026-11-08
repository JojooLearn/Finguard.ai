import '../../../../core/result/result.dart';
import '../entities/chat_conversation_entity.dart';
import '../entities/chat_message_entity.dart';

abstract class CoachRepository {
  Future<Result<List<ChatMessageEntity>>> getChatHistory({String? conversationId});

  Future<Result<List<ChatConversationEntity>>> getConversations();

  Future<Result<ChatConversationEntity>> createConversation({String? title});

  Future<Result<void>> deleteConversation(String conversationId);

  Future<Result<ChatMessageEntity>> sendMessage({
    required String message,
    String? conversationId,
    String? clientRequestId,
    String? receiptPath,
    String? receiptBase64,
    bool requestAudio = false,
  });

  Future<void> updateMessageMetadata({
    required String messageId,
    required Map<String, dynamic> metadata,
  });

  void clearLocalHistory();
}
