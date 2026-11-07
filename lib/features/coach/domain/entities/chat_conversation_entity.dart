import 'package:equatable/equatable.dart';

class ChatConversationEntity extends Equatable {
  final String id;
  final String title;
  final String conversationType;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? lastMessage;

  const ChatConversationEntity({
    required this.id,
    required this.title,
    this.conversationType = 'coach',
    required this.createdAt,
    required this.updatedAt,
    this.lastMessage,
  });

  ChatConversationEntity copyWith({
    String? id,
    String? title,
    String? conversationType,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? lastMessage,
  }) {
    return ChatConversationEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      conversationType: conversationType ?? this.conversationType,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastMessage: lastMessage ?? this.lastMessage,
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        conversationType,
        createdAt,
        updatedAt,
        lastMessage,
      ];
}

