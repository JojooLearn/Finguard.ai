import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/result/result.dart';
import '../../../../core/utils/financial_calculator.dart';
import '../../../budgets/domain/entities/budget_entity.dart';
import '../../../budgets/domain/repositories/budget_repository.dart';
import '../../../debts/domain/entities/debt_entity.dart';
import '../../../debts/domain/repositories/debt_repository.dart';
import '../../../goals/domain/entities/goal_entity.dart';
import '../../../goals/domain/repositories/goal_repository.dart';
import '../../../transactions/domain/entities/account_entity.dart';
import '../../../transactions/domain/entities/category_entity.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../../transactions/domain/repositories/category_and_account_repository.dart';
import '../../../transactions/domain/repositories/transaction_repository.dart';
import '../../domain/entities/chat_conversation_entity.dart';
import '../../domain/entities/chat_message_entity.dart';
import '../../domain/repositories/coach_repository.dart';

class CoachRepositoryImpl implements CoachRepository {
  final SupabaseClient client;
  final TransactionRepository transactionRepository;
  final BudgetRepository budgetRepository;
  final GoalRepository goalRepository;
  final AccountRepository? accountRepository;
  final DebtRepository? debtRepository;

  final List<ChatMessageEntity> _localChatHistory = [];

  CoachRepositoryImpl({
    required this.client,
    required this.transactionRepository,
    required this.budgetRepository,
    required this.goalRepository,
    this.accountRepository,
    this.debtRepository,
  });

  Future<String?>? _pendingGetOrCreate;
  String? _cachedConversationId;

  Future<String?> _getOrCreateConversationId(
    String userId, [
    String? candidateId,
  ]) async {
    final uuidRegex = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    if (candidateId != null && uuidRegex.hasMatch(candidateId)) {
      _cachedConversationId = candidateId;
      return candidateId;
    }

    if (_cachedConversationId != null) {
      return _cachedConversationId;
    }

    if (_pendingGetOrCreate != null) {
      return _pendingGetOrCreate!;
    }

    _pendingGetOrCreate = _getOrCreateConversationIdInternal(userId);
    try {
      return await _pendingGetOrCreate!;
    } finally {
      _pendingGetOrCreate = null;
    }
  }

  Future<String?> _getOrCreateConversationIdInternal(String userId) async {
    try {
      final convList = await client
          .from('chat_conversations')
          .select('id')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(1);

      if (convList.isNotEmpty) {
        _cachedConversationId = convList.first['id'] as String;
        return _cachedConversationId;
      }

      final created = await client
          .from('chat_conversations')
          .insert({'user_id': userId, 'title': 'Konsultasi FinGuard'})
          .select('id')
          .single();
      _cachedConversationId = created['id'] as String;
      return _cachedConversationId;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Result<List<ChatMessageEntity>>> getChatHistory({
    String? conversationId,
  }) async {
    try {
      final user = client.auth.currentUser;
      if (user != null) {
        final convId = await _getOrCreateConversationId(
          user.id,
          conversationId,
        );

        if (convId != null) {
          final response = await client
              .from('chat_messages')
              .select()
              .eq('conversation_id', convId)
              .order('created_at', ascending: true);

          final messages = (response as List).map((json) {
            final rawMeta = json['metadata'];
            final metadata = rawMeta is Map
                ? Map<String, dynamic>.from(rawMeta)
                : null;
            final isClarification = metadata?['needs_clarification'] == true;
            return ChatMessageEntity(
              id: json['id'],
              conversationId: json['conversation_id'],
              senderType: ChatSenderType.fromString(
                json['role'] ?? 'assistant',
              ),
              content: json['content'] ?? '',
              createdAt: DateTime.parse(json['created_at']).toLocal(),
              structuredPayload: metadata,
              status: isClarification
                  ? ChatMessageStatus.needsClarification
                  : ChatMessageStatus.completed,
              needsClarification: isClarification,
              isConfirmed: metadata?['confirmed'] == true,
              audioBase64: metadata?['audio_base64'] as String?,
            );
          }).toList();

          if (messages.isNotEmpty) {
            _localChatHistory.clear();
            _localChatHistory.addAll(messages);
            return Success(messages);
          } else {
            // Seed welcome message into Supabase
            const welcomeText =
                'Woi! Gue Coach finansial lu. Tanya aja kondisi saldo, cek sisa jatah jajan, konsultasi rencana beli barang, atau ketik langsung buat catat transaksi!';

            try {
              final welcomeInsert = await client
                  .from('chat_messages')
                  .insert({
                    'conversation_id': convId,
                    'user_id': user.id,
                    'role': 'assistant',
                    'content': welcomeText,
                    'message_status': 'completed',
                    'metadata': {},
                  })
                  .select()
                  .single();

              final welcomeMsg = ChatMessageEntity(
                id: welcomeInsert['id'],
                conversationId: convId,
                senderType: ChatSenderType.assistant,
                content: welcomeText,
                createdAt: DateTime.parse(
                  welcomeInsert['created_at'],
                ).toLocal(),
              );

              _localChatHistory.clear();
              _localChatHistory.add(welcomeMsg);
              return Success([welcomeMsg]);
            } catch (_) {}
          }
        }
      }
    } catch (_) {
      // Fallback to local history
    }

    if (_localChatHistory.isEmpty) {
      _localChatHistory.add(
        ChatMessageEntity(
          id: 'msg_welcome',
          conversationId: 'conv_local_default',
          senderType: ChatSenderType.assistant,
          content:
              'Woi! Gue Coach finansial lu. Tanya aja kondisi saldo, cek sisa jatah jajan, konsultasi rencana beli barang, atau ketik langsung buat catat transaksi!',
          createdAt: DateTime.now(),
        ),
      );
    }

    return Success(List.unmodifiable(_localChatHistory));
  }

  @override
  Future<Result<List<ChatConversationEntity>>> getConversations() async {
    try {
      final user = client.auth.currentUser;
      if (user != null) {
        final res = await client
            .from('chat_conversations')
            .select('id, title, conversation_type, created_at, updated_at')
            .eq('user_id', user.id)
            .isFilter('archived_at', null)
            .order('updated_at', ascending: false);

        final convList = <ChatConversationEntity>[];
        const placeholderTitles = {
          '',
          'percakapan baru',
          'chat coach finguard',
          'konsultasi finguard',
          'percakapan finguard',
        };
        for (final item in (res as List)) {
          final convId = item['id'] as String;
          bool hasUserMessage = false;
          String? firstUserMsg;
          String? lastMsg;
          try {
            final firstUserRes = await client
                .from('chat_messages')
                .select('id, content')
                .eq('conversation_id', convId)
                .eq('role', 'user')
                .order('created_at', ascending: true)
                .limit(1)
                .maybeSingle();
            if (firstUserRes != null) {
              hasUserMessage = true;
              firstUserMsg = firstUserRes['content'] as String?;
            }

            final lastMsgRes = await client
                .from('chat_messages')
                .select('content')
                .eq('conversation_id', convId)
                .order('created_at', ascending: false)
                .limit(1)
                .maybeSingle();
            if (lastMsgRes != null) {
              lastMsg = lastMsgRes['content'] as String?;
            }
          } catch (_) {}

          // Filter out phantom conversations with 0 user messages so brand new users don't see spam
          if (!hasUserMessage) {
            continue;
          }

          String resolvedTitle = (item['title'] as String? ?? '').trim();
          if (placeholderTitles.contains(resolvedTitle.toLowerCase()) &&
              firstUserMsg != null &&
              firstUserMsg.trim().isNotEmpty) {
            final normalizedFirst =
                firstUserMsg.replaceAll(RegExp(r'\s+'), ' ').trim();
            resolvedTitle = normalizedFirst.length > 42
                ? '${normalizedFirst.substring(0, 39).trim()}...'
                : normalizedFirst;
            try {
              await client
                  .from('chat_conversations')
                  .update({'title': resolvedTitle})
                  .eq('id', convId);
            } catch (_) {}
          }
          if (resolvedTitle.isEmpty) {
            resolvedTitle = 'Percakapan FinGuard';
          }

          convList.add(
            ChatConversationEntity(
              id: convId,
              title: resolvedTitle,
              conversationType: item['conversation_type'] as String? ?? 'coach',
              createdAt: DateTime.parse(item['created_at']).toLocal(),
              updatedAt: DateTime.parse(item['updated_at']).toLocal(),
              lastMessage: lastMsg,
            ),
          );
        }
        return Success(convList);
      }
    } catch (e) {
      return ErrorResult(ServerFailure('Gagal memuat riwayat percakapan: $e'));
    }
    return const Success(<ChatConversationEntity>[]);
  }

  @override
  Future<Result<ChatConversationEntity>> createConversation({
    String? title,
  }) async {
    try {
      final user = client.auth.currentUser;
      if (user != null) {
        // If an unused/unstarted conversation already exists with 0 user messages, reuse it
        try {
          final existingUnused = await client
              .from('chat_conversations')
              .select('id, title, conversation_type, created_at, updated_at')
              .eq('user_id', user.id)
              .isFilter('archived_at', null)
              .order('updated_at', ascending: false)
              .limit(1)
              .maybeSingle();

          if (existingUnused != null) {
            final convId = existingUnused['id'] as String;
            final userMsg = await client
                .from('chat_messages')
                .select('id')
                .eq('conversation_id', convId)
                .eq('role', 'user')
                .limit(1);
            if ((userMsg as List).isEmpty) {
              return Success(
                ChatConversationEntity(
                  id: convId,
                  title:
                      existingUnused['title'] as String? ?? 'Percakapan Baru',
                  conversationType:
                      existingUnused['conversation_type'] as String? ?? 'coach',
                  createdAt: DateTime.parse(
                    existingUnused['created_at'],
                  ).toLocal(),
                  updatedAt: DateTime.parse(
                    existingUnused['updated_at'],
                  ).toLocal(),
                ),
              );
            }
          }
        } catch (_) {}

        final insertRes = await client
            .from('chat_conversations')
            .insert({
              'user_id': user.id,
              'title': title ?? 'Percakapan Baru',
              'conversation_type': 'coach',
            })
            .select()
            .single();

        return Success(
          ChatConversationEntity(
            id: insertRes['id'] as String,
            title: insertRes['title'] as String? ?? 'Percakapan Baru',
            conversationType:
                insertRes['conversation_type'] as String? ?? 'coach',
            createdAt: DateTime.parse(insertRes['created_at']).toLocal(),
            updatedAt: DateTime.parse(insertRes['updated_at']).toLocal(),
          ),
        );
      }
    } catch (e) {
      return ErrorResult(ServerFailure('Gagal membuat percakapan baru: $e'));
    }

    final now = DateTime.now();
    return Success(
      ChatConversationEntity(
        id: 'conv_local_${now.millisecondsSinceEpoch}',
        title: title ?? 'Percakapan Baru',
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  @override
  Future<Result<void>> deleteConversation(String conversationId) async {
    try {
      final user = client.auth.currentUser;
      if (user != null) {
        try {
          await client
              .from('chat_messages')
              .delete()
              .eq('conversation_id', conversationId);
        } catch (_) {}

        await client
            .from('chat_conversations')
            .delete()
            .eq('id', conversationId);
      }

      _localChatHistory.removeWhere((m) => m.conversationId == conversationId);
      return const Success(null);
    } catch (e) {
      return ErrorResult(ServerFailure('Gagal menghapus percakapan: $e'));
    }
  }

  @override
  Future<Result<ChatMessageEntity>> sendMessage({
    required String message,
    String? conversationId,
    String? clientRequestId,
    String? receiptPath,
    String? receiptBase64,
    bool requestAudio = false,
    int? strictnessLevel,
  }) async {
    final effectiveRequestId = clientRequestId ?? const Uuid().v4();
    final user = client.auth.currentUser;
    String? activeConvId;
    if (user != null) {
      activeConvId = await _getOrCreateConversationId(user.id, conversationId);
    }
    final effectiveConvId =
        activeConvId ?? conversationId ?? 'conv_local_default';

    // 1. Record user message locally
    final userMsg = ChatMessageEntity(
      id: 'msg_usr_${DateTime.now().millisecondsSinceEpoch}',
      conversationId: effectiveConvId,
      senderType: ChatSenderType.user,
      content: message,
      structuredPayload: receiptPath != null
          ? {'receipt_path': receiptPath, 'request_audio': requestAudio}
          : (requestAudio ? {'request_audio': true} : null),
      clientRequestId: effectiveRequestId,
      createdAt: DateTime.now(),
    );
    _localChatHistory.add(userMsg);

    String coachReply = '';
    Map<String, dynamic>? structuredData;
    String? audioBase64;
    bool needsClarification = false;
    List<String> missingFields = [];
    ChatMessageStatus messageStatus = ChatMessageStatus.completed;

    // 2. Try remote Edge Function if user is authenticated (Fast path: no redundant sequential pre-queries, 20s timeout)
    bool edgeFunctionPersisted = false;
    String? remoteAssistantMsgId;
    if (user != null) {
      try {
        final now = DateTime.now();

        // Package at most the last 6 messages as recent history for multi-turn context
        final historyList = _localChatHistory.length > 1
            ? _localChatHistory.sublist(0, _localChatHistory.length - 1)
            : <ChatMessageEntity>[];
        final recentHistory = historyList.length > 6
            ? historyList.sublist(historyList.length - 6)
            : historyList;

        final clientDate =
            '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

        final invokeBody = <String, dynamic>{
          'message': message,
          'conversation_id': effectiveConvId,
          'client_request_id': effectiveRequestId,
          'strictness_level': ?strictnessLevel,
          'client_date': clientDate,
          'request_audio': requestAudio,
          'receipt_path': ?receiptPath,
          'receipt_base64': ?receiptBase64,
          'recent_history': recentHistory
              .map(
                (m) => {
                  'sender': m.senderType.toDbString(),
                  'content': m.content,
                },
              )
              .toList(),
        };

        final res = await client.functions
            .invoke('coach-chat', body: invokeBody)
            .timeout(const Duration(seconds: 20));

        if (res.data != null && res.data is Map) {
          final data = Map<String, dynamic>.from(res.data as Map);
          final msgMap = data['message'] is Map
              ? Map<String, dynamic>.from(data['message'] as Map)
              : null;
          coachReply = msgMap?['content']?.toString() ??
              data['reply']?.toString() ??
              '';
          final rawAstId = msgMap?['id']?.toString() ??
              data['assistant_message_id']?.toString();
          if (rawAstId != null && rawAstId.isNotEmpty) {
            remoteAssistantMsgId = rawAstId;
          }
          final sourceEngine = msgMap?['source_engine']?.toString() ??
              data['source_engine']?.toString();
          if (sourceEngine != null && sourceEngine.isNotEmpty) {
            debugPrint('[coach-chat] AI response from source_engine=$sourceEngine');
          }
          needsClarification = data['needs_clarification'] == true;
          if (data['missing_fields'] is List) {
            missingFields = (data['missing_fields'] as List)
                .map((e) => e.toString())
                .toList();
          }
          if (!needsClarification && data['structured_transaction'] != null) {
            structuredData = Map<String, dynamic>.from(
              data['structured_transaction'] as Map,
            );
          }
          if (needsClarification) {
            messageStatus = ChatMessageStatus.needsClarification;
          }
          edgeFunctionPersisted = true;
          if (data['conversation_id'] != null) {
            _cachedConversationId = data['conversation_id'].toString();
          }
        }
      } catch (e) {
        debugPrint('Coach chat invoke failed: $e');
        // Fallback to local engine
      }
    }

    // 3. Contextual Data-Driven Local Engine
    if (coachReply.isEmpty) {
      if (receiptPath != null || receiptBase64 != null) {
        coachReply =
            'Foto nota belum dapat diproses oleh AI Vision saat ini. Pastikan foto struk terlihat jelas, tidak buram, dan memuat angka total belanja, lalu silakan coba foto ulang.';
      } else {
        final contextualResult = await _generateContextualConsultation(
          message,
          strictnessLevelOverride: strictnessLevel,
        );
        coachReply = contextualResult.reply;
        structuredData = contextualResult.extractedTx;
        needsClarification = contextualResult.needsClarification;
        missingFields = contextualResult.missingFields;
        if (needsClarification) {
          messageStatus = ChatMessageStatus.needsClarification;
        }
      }
    }

    // Communication Mirroring Contract (On-Device TTS):
    // Server returns pure text only (no audio_base64 bandwidth overhead).
    // - requestAudio == true  -> marks message with voice_out & triggers on-device flutter_tts
    // - requestAudio == false -> silent mode (no TTS)
    audioBase64 = null;
    if (requestAudio) {
      structuredData = {
        ...?structuredData,
        'voice_out': true,
      };
    }

    // 4. Direct Client DB Persistence to Supabase (Fallback ONLY if Edge Function was not used or failed)
    String assistantMsgId =
        (remoteAssistantMsgId != null && remoteAssistantMsgId.isNotEmpty)
            ? remoteAssistantMsgId
            : 'msg_ast_${DateTime.now().millisecondsSinceEpoch}';
    if (user != null && !edgeFunctionPersisted) {
      final convId = activeConvId ?? await _getOrCreateConversationId(user.id);
      if (convId != null) {
        try {
          // Check if user message already saved by Edge Function
          final existingUMsg = await client
              .from('chat_messages')
              .select('id')
              .eq('conversation_id', convId)
              .eq('role', 'user')
              .eq('content', message)
              .order('created_at', ascending: false)
              .limit(1)
              .maybeSingle();

          if (existingUMsg == null) {
            await client.from('chat_messages').insert({
              'conversation_id': convId,
              'user_id': user.id,
              'role': 'user',
              'content': message,
              'message_status': 'completed',
              'metadata': {
                'client_request_id': effectiveRequestId,
                'receipt_path': ?receiptPath,
              },
            });
          }

          // Check if assistant message already saved by Edge Function
          final existingAMsg = await client
              .from('chat_messages')
              .select('id')
              .eq('conversation_id', convId)
              .eq('role', 'assistant')
              .eq('content', coachReply)
              .order('created_at', ascending: false)
              .limit(1)
              .maybeSingle();

          if (existingAMsg == null) {
            try {
              final aRow = await client
                  .from('chat_messages')
                  .insert({
                    'conversation_id': convId,
                    'user_id': user.id,
                    'role': 'assistant',
                    'content': coachReply,
                    'message_status': messageStatus.toDbString(),
                    'metadata': structuredData ?? {},
                  })
                  .select('id')
                  .single();
              assistantMsgId = aRow['id'] as String;
            } catch (_) {
              final aRow = await client
                  .from('chat_messages')
                  .insert({
                    'conversation_id': convId,
                    'user_id': user.id,
                    'role': 'assistant',
                    'content': coachReply,
                  })
                  .select('id')
                  .single();
              assistantMsgId = aRow['id'] as String;
            }
          } else {
            assistantMsgId = existingAMsg['id'] as String;
          }

          final updatePayload = <String, dynamic>{
            'updated_at': DateTime.now().toIso8601String(),
          };
          try {
            final convRow = await client
                .from('chat_conversations')
                .select('title')
                .eq('id', convId)
                .maybeSingle();
            final currentTitle = convRow?['title'] as String? ?? '';
            if (currentTitle.isEmpty ||
                currentTitle == 'Percakapan Baru' ||
                currentTitle == 'Konsultasi FinGuard') {
              final newTitle = message.length > 35
                  ? '${message.substring(0, 32)}...'
                  : message;
              updatePayload['title'] = newTitle;
            }
          } catch (_) {}

          await client
              .from('chat_conversations')
              .update(updatePayload)
              .eq('id', convId);
        } catch (_) {}
      }
    }

    final assistantMsg = ChatMessageEntity(
      id: assistantMsgId,
      conversationId: effectiveConvId,
      senderType: ChatSenderType.assistant,
      content: coachReply,
      clientRequestId: effectiveRequestId,
      createdAt: DateTime.now(),
      structuredPayload: structuredData,
      status: messageStatus,
      needsClarification: needsClarification,
      missingFields: missingFields,
      audioBase64: audioBase64,
      autoSpeak: requestAudio,
    );

    _localChatHistory.add(assistantMsg);

    return Success(assistantMsg);
  }

  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  @override
  Future<void> updateMessageMetadata({
    required String messageId,
    required Map<String, dynamic> metadata,
  }) async {
    String? localConvId;
    String? localContent;
    final idx = _localChatHistory.indexWhere((m) => m.id == messageId);
    if (idx != -1) {
      final existing = _localChatHistory[idx];
      localConvId = existing.conversationId;
      localContent = existing.content;
      _localChatHistory[idx] = existing.copyWith(
        isConfirmed: metadata['confirmed'] == true,
        structuredPayload: metadata,
      );
    }

    try {
      final user = client.auth.currentUser;
      if (user == null) return;

      if (_uuidRegex.hasMatch(messageId)) {
        await client
            .from('chat_messages')
            .update({'metadata': metadata})
            .eq('id', messageId)
            .eq('user_id', user.id);
        return;
      }

      // Defensive fallback if messageId was generated client-side: locate matching assistant row in Supabase
      if (localContent != null && localContent.isNotEmpty) {
        var query = client
            .from('chat_messages')
            .select('id')
            .eq('user_id', user.id)
            .eq('role', 'assistant')
            .eq('content', localContent);
        if (localConvId != null && _uuidRegex.hasMatch(localConvId)) {
          query = query.eq('conversation_id', localConvId);
        }
        final matched = await query
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();
        final resolvedId = matched?['id']?.toString();
        if (resolvedId != null && resolvedId.isNotEmpty) {
          await client
              .from('chat_messages')
              .update({'metadata': metadata})
              .eq('id', resolvedId)
              .eq('user_id', user.id);
          if (idx != -1) {
            _localChatHistory[idx] = _localChatHistory[idx].copyWith(id: resolvedId);
          }
        }
      }
    } catch (_) {}
  }

  /// Comprehensive Database-Grounded Financial Consultation Engine
  Future<
    ({
      String reply,
      Map<String, dynamic>? extractedTx,
      bool needsClarification,
      List<String> missingFields,
    })
  >
  _generateContextualConsultation(
    String text, {
    int? strictnessLevelOverride,
  }) async {
    final lower = text.toLowerCase().trim();

    // 1. Fetch live database context
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    final periodStart = DateTime(now.year, now.month, 1);
    final periodEnd = DateTime(now.year, now.month + 1, 0);

    // Fetch transactions starting from at least yesterday or start of month so yesterday is always captured
    final fetchStart = periodStart.isBefore(yesterday)
        ? periodStart
        : DateTime(yesterday.year, yesterday.month, yesterday.day);

    // Parallel repository queries to minimize latency
    final parallelResults = await Future.wait<dynamic>([
      transactionRepository.getTransactions(
        startDate: fetchStart,
        endDate: periodEnd,
      ),
      budgetRepository.getBudgets(
        periodStart: periodStart,
        periodEnd: periodEnd,
      ),
      goalRepository.getGoals(),
      accountRepository != null
          ? accountRepository!.getAccounts()
          : Future.value(const Success(<AccountEntity>[])),
      debtRepository != null
          ? debtRepository!.getDebts()
          : Future.value(const Success(<DebtEntity>[])),
    ]);

    final txResult = parallelResults[0] as Result<List<TransactionEntity>>;
    final budgetResult = parallelResults[1] as Result<List<BudgetEntity>>;
    final goalResult = parallelResults[2] as Result<List<GoalEntity>>;
    final accResult = parallelResults[3] as Result<List<AccountEntity>>;
    final debtResult = parallelResults[4] as Result<List<DebtEntity>>;

    final transactions = txResult.fold(
      (txs) => txs,
      (_) => <TransactionEntity>[],
    );
    final budgets = budgetResult.fold((b) => b, (_) => <BudgetEntity>[]);
    final goals = goalResult.fold((g) => g, (_) => <GoalEntity>[]);
    final accounts = accResult.fold((a) => a, (_) => <AccountEntity>[]);
    final debts = debtResult.fold((d) => d, (_) => <DebtEntity>[]);

    // 2. Fetch user financial profile for verified income, debt, strictness, and goals
    double verifiedMonthlyIncome = 0.0;
    double essentialExpenses = 0.0;
    double monthlyDebt = 0.0;
    int strictnessLevel = 3;
    int dependentsCount = 0;
    String incomeFrequency = 'monthly';
    double initialEmergencyFund = 0.0;
    String primaryGoalSummary = '';
    String riskProfile = 'moderate';

    List<Map<String, dynamic>> contributions = [];
    Map<String, dynamic>? latestReview;

    final currentUser = client.auth.currentUser;
    if (currentUser != null) {
      try {
        final fp = await client
            .from('financial_profiles')
            .select(
              'monthly_income, essential_monthly_expenses, monthly_debt_payments, strictness_level, dependents_count, income_frequency, current_emergency_fund, primary_goal_summary, risk_profile',
            )
            .eq('user_id', currentUser.id)
            .maybeSingle();
        if (fp != null) {
          verifiedMonthlyIncome =
              (fp['monthly_income'] as num?)?.toDouble() ?? 0.0;
          essentialExpenses =
              (fp['essential_monthly_expenses'] as num?)?.toDouble() ?? 0.0;
          monthlyDebt =
              (fp['monthly_debt_payments'] as num?)?.toDouble() ?? 0.0;
          strictnessLevel = (fp['strictness_level'] as num?)?.toInt() ?? 3;
          dependentsCount = (fp['dependents_count'] as num?)?.toInt() ?? 0;
          incomeFrequency = fp['income_frequency']?.toString() ?? 'monthly';
          initialEmergencyFund =
              (fp['current_emergency_fund'] as num?)?.toDouble() ?? 0.0;
          primaryGoalSummary = fp['primary_goal_summary']?.toString() ?? '';
          riskProfile = fp['risk_profile']?.toString() ?? 'moderate';
        }
      } catch (_) {}

      if (strictnessLevelOverride != null) {
        strictnessLevel = strictnessLevelOverride;
      }

      try {
        final gcRes = await client
            .from('goal_contributions')
            .select(
              'id, amount, contribution_date, note, financial_goals(name)',
            )
            .eq('user_id', currentUser.id)
            .order('contribution_date', ascending: false)
            .limit(10);
        final gcRows = gcRes as List<dynamic>;
        contributions = gcRows
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      } catch (_) {}

      try {
        final mrRes = await client
            .from('monthly_reviews')
            .select(
              'period_start, period_end, narrative, metrics_snapshot, status',
            )
            .eq('user_id', currentUser.id)
            .order('period_start', ascending: false)
            .limit(1)
            .maybeSingle();
        if (mrRes != null) {
          latestReview = Map<String, dynamic>.from(mrRes as Map);
        }
      } catch (_) {}
    }

    // 3. Compute key financial metrics from database
    double totalIncome = 0.0;
    double totalExpense = 0.0;
    final Map<String, double> categoryExpenseMap = {};

    final List<TransactionEntity> todayTxs = [];
    final List<TransactionEntity> yesterdayTxs = [];

    bool isSameDay(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;

    bool isFoodTx(TransactionEntity tx) {
      final textToCheck = '${tx.category?.name ?? ''} ${tx.note ?? ''}'
          .toLowerCase();
      return textToCheck.contains('makan') ||
          textToCheck.contains('minum') ||
          textToCheck.contains('kuliner') ||
          textToCheck.contains('resto') ||
          textToCheck.contains('warung') ||
          textToCheck.contains('food') ||
          textToCheck.contains('kopi') ||
          textToCheck.contains('cafe');
    }

    for (final tx in transactions) {
      final isCurrentMonth =
          tx.transactionDate.year == now.year &&
          tx.transactionDate.month == now.month;

      if (isCurrentMonth) {
        if (tx.transactionType == TransactionType.income) {
          totalIncome += tx.amount;
        } else {
          totalExpense += tx.amount;
          final cat = tx.category?.name ?? 'Umum';
          categoryExpenseMap[cat] =
              (categoryExpenseMap[cat] ?? 0.0) + tx.amount;
        }
      }

      if (isSameDay(tx.transactionDate, now)) {
        todayTxs.add(tx);
      } else if (isSameDay(tx.transactionDate, yesterday)) {
        yesterdayTxs.add(tx);
      }
    }

    final effectiveIncome = totalIncome > 0
        ? totalIncome
        : verifiedMonthlyIncome;
    final netCashFlow = effectiveIncome - totalExpense;

    // Total balances across accounts + net transactions (avoids double counting opening balance seeded with monthly income)
    double totalAccountBalance = 0.0;
    if (accounts.isNotEmpty) {
      totalAccountBalance = accounts.fold(
        0.0,
        (sum, a) => sum + a.openingBalance,
      );
    }
    double actualLiquidCash = totalIncome - totalExpense;
    if (totalAccountBalance > totalIncome) {
      actualLiquidCash += (totalAccountBalance - totalIncome);
    }
    if (actualLiquidCash < 0) actualLiquidCash = 0;

    // Total accumulated in goals
    final totalGoalsSaved = goals.fold(0.0, (sum, g) => sum + g.currentAmount);

    // Active debts & unpaid monthly debt obligation (preventing double counting if paid this month)
    final activeDebts = debts
        .where((d) => !d.isCompleted && d.remainingTenorMonths > 0)
        .toList();
    final paidDebtNotes = transactions
        .where(
          (tx) =>
              tx.transactionType == TransactionType.expense &&
              tx.transactionDate.year == now.year &&
              tx.transactionDate.month == now.month &&
              (tx.note ?? '').toLowerCase().startsWith('bayar '),
        )
        .map((tx) => (tx.note ?? '').toLowerCase())
        .toList();

    double unpaidMonthlyDebt = 0.0;
    if (activeDebts.isNotEmpty) {
      for (final d in activeDebts) {
        final dName = d.name.toLowerCase();
        final alreadyPaid = paidDebtNotes.any(
          (n) => n.contains('bayar $dName'),
        );
        if (!alreadyPaid) {
          unpaidMonthlyDebt += d.monthlyPayment;
        }
      }
    } else {
      unpaidMonthlyDebt = monthlyDebt;
    }

    // Golden Financial Rule:
    // Uang Dingin Siap Pakai = Total Pemasukan - Total Pengeluaran Konsumsi - Kewajiban Cicilan Belum Dibayar Bulan Ini - Setoran Tabungan/Dana Darurat Bulan Ini
    final effectiveConsumptionExpense = totalExpense > 0
        ? totalExpense
        : essentialExpenses;
    final freeCash = FinancialCalculator.calculateAvailableFreeCash(
      totalIncome: effectiveIncome,
      totalConsumptionExpense: effectiveConsumptionExpense,
      unpaidMonthlyDebt: unpaidMonthlyDebt,
      monthlySavingsContribution: totalGoalsSaved,
    );

    // 3. Amount Extraction with support for Indonesian vernacular (e.g. 150 juta, 3 jt, 50rb, 35k, 35.000)
    final extractedAmount = _extractAmount(lower);

    // 4. Multi-turn Follow-up Detection
    // Only trigger follow-up price if the previous assistant message explicitly asked for the item's price
    String? previousConsultationItem;
    if (_localChatHistory.length >= 2) {
      final prevMsg = _localChatHistory[_localChatHistory.length - 2];
      final prevLower = prevMsg.content.toLowerCase();
      final askedForPrice =
          prevLower.contains('berapa harga') ||
          prevLower.contains('ketik nominalnya') ||
          prevLower.contains('ketik harganya');
      if (askedForPrice) {
        if (prevLower.contains('mobil')) {
          previousConsultationItem = 'Mobil';
        } else if (prevLower.contains('gadget') ||
            prevLower.contains('hp') ||
            prevLower.contains('iphone')) {
          previousConsultationItem = 'Gadget / HP';
        } else if (prevLower.contains('laptop') ||
            prevLower.contains('macbook')) {
          previousConsultationItem = 'Laptop';
        } else if (prevLower.contains('motor')) {
          previousConsultationItem = 'Motor';
        } else if (prevLower.contains('rumah')) {
          previousConsultationItem = 'Rumah';
        } else {
          previousConsultationItem = 'Barang Impian';
        }
      }
    }

    final isExplicitPastTransaction =
        lower.startsWith('tadi ') ||
        lower.contains('tadi gue ') ||
        lower.contains('tadi saya ') ||
        lower.contains('barusan ') ||
        lower.contains('habis beli ') ||
        lower.contains('udah beli ') ||
        lower.contains('sudah beli ') ||
        lower.contains('beli bensin') ||
        lower.contains('isi bensin') ||
        lower.startsWith('catat ');

    final isFollowUpPrice =
        !isExplicitPastTransaction &&
        previousConsultationItem != null &&
        extractedAmount != null &&
        extractedAmount > 0;

    // 5. Intent Classifications
    final isQuestion =
        lower.contains('?') ||
        lower.contains('apa') ||
        lower.contains('apakah') ||
        lower.contains('berapa') ||
        lower.contains('bagaimana') ||
        lower.contains('gimana') ||
        lower.contains('bisa gak') ||
        lower.contains('bisa ga') ||
        lower.contains('boleh gak') ||
        lower.contains('boleh ga') ||
        lower.contains('aman gak') ||
        lower.contains('aman ga') ||
        lower.contains('kira kira') ||
        lower.contains('kira-kira') ||
        lower.contains('mampu gak') ||
        lower.contains('mampu ga');

    final isPurchaseConsultation =
        !isExplicitPastTransaction &&
        (isFollowUpPrice ||
            ((lower.contains('beli') ||
                    lower.contains('gadget') ||
                    lower.contains('laptop') ||
                    lower.contains('mobil') ||
                    lower.contains('motor') ||
                    lower.contains('sepatu') ||
                    lower.contains('hp') ||
                    lower.contains('rumah') ||
                    lower.contains('belanja')) &&
                (isQuestion ||
                    lower.contains('mau beli') ||
                    lower.contains('pengen beli') ||
                    lower.contains('rencana beli') ||
                    lower.contains('boleh beli') ||
                    lower.contains('bisa beli') ||
                    lower.contains('konsultasi'))));

    final isWealthQuery =
        lower.contains('dana yang') ||
        lower.contains('dana saya') ||
        lower.contains('dana ku') ||
        lower.contains('dana dimiliki') ||
        lower.contains('dana ada berapa') ||
        lower.contains('uang saya') ||
        lower.contains('uang ku') ||
        lower.contains('uang ada berapa') ||
        lower.contains('duit saya') ||
        lower.contains('duit ku') ||
        lower.contains('duit ada berapa') ||
        lower.contains('saldo') ||
        lower.contains('kekayaan') ||
        lower.contains('tabungan saya') ||
        lower.contains('kas saya') ||
        (lower.contains('berapa') &&
            (lower.contains('dana') ||
                lower.contains('uang') ||
                lower.contains('duit')));

    // --- Intent 0: Greetings & Casual Chit-Chat (Offline Fallback) ---
    final isGreeting =
        lower == 'hai' ||
        lower == 'halo' ||
        lower == 'hello' ||
        lower == 'hey' ||
        lower == 'pagi' ||
        lower == 'siang' ||
        lower == 'malam' ||
        lower == 'tes' ||
        lower == 'test' ||
        lower.startsWith('hai ') ||
        lower.startsWith('halo ') ||
        lower.contains('apa kabar') ||
        lower.contains('lagi apa') ||
        lower.contains('siapa kamu');

    if (isGreeting) {
      final greeting = strictnessLevel >= 4
          ? 'Woi anjing! Dompet lu masih napas apa udah mampus sekarat bangsat?! Gausah sok hedon ngentot. Mau nanya apaan lu? Mau curhat boncos apa mau pamer kemiskinan lu ke gua?!'
          : 'Woi santai! Ada apaan nih? Mau cek saldo dompet, hitung barang idaman, apa mau tobat dari jajan boros?';

      return (
        reply: greeting,
        extractedTx: null,
        needsClarification: false,
        missingFields: <String>[],
      );
    }

    // --- Intent D: Active Debts & Installment Prioritization Inquiry (TC-13) ---
    final isDebtInquiry =
        (lower.contains('cicilan') ||
            lower.contains('utang') ||
            lower.contains('hutang')) &&
        (isQuestion ||
            lower.contains('punya cicilan') ||
            lower.contains('lunasin') ||
            lower.contains('lunasi') ||
            lower.contains('duluan') ||
            lower.contains('prioritas') ||
            lower.contains('apa aja') ||
            lower.contains('apa saja'));

    if (isDebtInquiry) {
      if (activeDebts.isEmpty) {
        return (
          reply:
              'Saat ini kamu bebas dari komitmen cicilan aktif (DSR 0%). Seluruh uang dingin siap pakaimu sebesar ${_formatRp(freeCash)} bisa langsung difokuskan ke Dana Darurat dan investasi.',
          extractedTx: null,
          needsClarification: false,
          missingFields: <String>[],
        );
      }

      final sortedByInterest = [...activeDebts]
        ..sort((a, b) {
          final cmp = b.annualInterestRate.compareTo(a.annualInterestRate);
          if (cmp != 0) return cmp;
          return b.remainingAmount.compareTo(a.remainingAmount);
        });

      final totalMonthlyObligation = activeDebts.fold<double>(
        0.0,
        (s, d) => s + d.monthlyPayment,
      );
      final dsrPct = effectiveIncome > 0
          ? (totalMonthlyObligation / effectiveIncome) * 100
          : 0.0;

      final buf = StringBuffer();
      buf.writeln(
        'Berikut rincian cicilan aktifmu saat ini (Total beban: ${_formatRp(totalMonthlyObligation)}/bulan | DSR ${dsrPct.toStringAsFixed(0)}%):',
      );
      for (final d in activeDebts) {
        final rateStr = d.annualInterestRate > 0
            ? 'Bunga ${d.annualInterestRate.toStringAsFixed(0)}%/tahun'
            : 'Bunga 0%';
        final compoundNote = d.appliedInterestAmount > 0
            ? ' (termasuk akumulasi bunga tahunan +${_formatRp(d.appliedInterestAmount)} setelah ${d.appliedYears} tahun)'
            : '';
        buf.writeln(
          '- **${d.name}**: ${_formatRp(d.monthlyPayment)}/bln | Sisa ${d.remainingTenorMonths} dari ${d.totalTenorMonths} bulan | Sisa Utang: **${_formatRp(d.remainingAmount)}** ($rateStr$compoundNote)',
        );
      }

      final topDebt = sortedByInterest.first;
      buf.writeln('\n### Strategi Prioritas Pelunasan (Metode Debt Avalanche)');
      if (topDebt.annualInterestRate > 0) {
        buf.writeln(
          'Prioritaskan melunasi **${topDebt.name}** terlebih dahulu karena memiliki **bunga ${topDebt.annualInterestRate.toStringAsFixed(0)}%/tahun** yang terus menambah beban sisa utangmu menjadi ${_formatRp(topDebt.remainingAmount)} jika melewati 1 tahun.',
        );
        if (sortedByInterest.length > 1) {
          final secondDebt = sortedByInterest.last;
          buf.writeln(
            'Untuk **${secondDebt.name}** (${secondDebt.annualInterestRate == 0 ? "Bunga 0%" : "Bunga ${secondDebt.annualInterestRate.toStringAsFixed(0)}%"}), cukup bayar sesuai jadwal bulanan (${_formatRp(secondDebt.monthlyPayment)}/bln) sampai lunas tanpa perlu dipercepat.',
          );
        }
      } else {
        buf.writeln(
          'Semua cicilanmu memiliki bunga 0%. Prioritaskan melunasi **${topDebt.name}** sesuai jadwal jatuh tempo.',
        );
      }

      return (
        reply: buf.toString().trim(),
        extractedTx: null,
        needsClarification: false,
        missingFields: <String>[],
      );
    }

    // --- Intent S: Stock Signals & Hybrid On-Demand Analysis (Local Fallback) ---
    final stockTickerMap = <String, ({double price, String signal, String notes})>{
      'BBCA': (
        price: 9250,
        signal: 'BUY',
        notes:
            'Fundamental perbankan paling kokoh (ROE ~21%, PBV ~4.5x), akumulasi di area support MA20.',
      ),
      'BBRI': (
        price: 4450,
        signal: 'BUY',
        notes:
            'Valuasi murah dengan dividend yield tinggi (~6.5%), rebound dari support kuat.',
      ),
      'BMRI': (
        price: 6150,
        signal: 'BUY',
        notes:
            'Pertumbuhan kredit korporasi solid (ROE ~20%), tren uptrend di atas MA50.',
      ),
      'BBNI': (
        price: 4850,
        signal: 'BUY',
        notes:
            'Valuasi paling diskon di antara Big 4 Bank (PER ~8.2x, PBV ~1.1x, Dividend Yield ~5.8%), sangat menarik untuk akumulasi bertahap.',
      ),
      'BRIS': (
        price: 2720,
        signal: 'BUY',
        notes:
            'Pemimpin perbankan syariah dengan pertumbuhan laba agresif, momentum teknikal bullish.',
      ),
      'TLKM': (
        price: 2780,
        signal: 'HOLD',
        notes:
            'Valuasi murah & dividen rutin (~6%), sedang konsolidasi di area support kunci.',
      ),
      'ASII': (
        price: 4920,
        signal: 'BUY',
        notes:
            'PER sangat rendah (~6.2x) dengan kas tebal & dividen jumbo (~8.5%), menguji resisten 5.000.',
      ),
      'GOTO': (
        price: 68,
        signal: 'HOLD / HIGH RISK',
        notes:
            'Harga 1 lot sangat terjangkau (~Rp6.800), volatilitas tinggi, cocok hanya untuk porsi spekulatif kecil.',
      ),
      'BUMI': (
        price: 124,
        signal: 'HOLD / SPECULATIVE',
        notes:
            'Saham komoditas batubara berfluktuasi tinggi (high beta), wajib pasang batas cut loss ketat.',
      ),
      'ADRO': (
        price: 3680,
        signal: 'BUY',
        notes:
            'Emiten energi dengan kas sangat tebal dan rasio valuasi PER ~4.5x.',
      ),
      'ICBP': (
        price: 11400,
        signal: 'BUY',
        notes:
            'Saham consumer defensif tahan resesi dengan margin laba stabil.',
      ),
      'ANTM': (
        price: 1560,
        signal: 'BUY',
        notes:
            'Sentimen komoditas emas & hilirisasi nikel mendukung tren menengah.',
      ),
    };

    final matchedTickers = <String>[];
    for (final ticker in stockTickerMap.keys) {
      if (RegExp('\\b${ticker.toLowerCase()}\\b').hasMatch(lower)) {
        matchedTickers.add(ticker);
      }
    }

    final isStockQuery =
        matchedTickers.isNotEmpty ||
        lower.contains('saham') ||
        lower.contains('sinyal') ||
        lower.contains('tradingview') ||
        lower.contains('emiten') ||
        lower.contains('ihsg') ||
        lower.contains('investasi saham');

    if (isStockQuery) {
      final investableCash = freeCash > 0 ? freeCash : (actualLiquidCash * 0.2);
      final buffer = StringBuffer();

      if (matchedTickers.isNotEmpty) {
        buffer.writeln('Analisa Saham Hybrid (Data Pasar & Fundamental):');
        for (final t in matchedTickers) {
          final info = stockTickerMap[t]!;
          final lotPrice = info.price * 100;
          final maxLots = investableCash >= lotPrice
              ? (investableCash / lotPrice).floor()
              : 0;
          buffer.writeln(
            '\n• **$t** — Harga ~${_formatRp(info.price)}/lembar (**${_formatRp(lotPrice)}/lot**) | Status: **${info.signal}**\n'
            '  - Prospek & Teknikal: ${info.notes}\n'
            '  - Kecocokan Modal: Dengan uang dingin lu ${_formatRp(investableCash)}, ${maxLots > 0 ? "cukup buat serok maksimal **$maxLots lot**." : "harga 1 lot (${_formatRp(lotPrice)}) masih di atas uang dingin bulanan lu, jadi kumpulin dulu di celengan investasi."}',
          );
        }
      } else {
        buffer.writeln(
          'Rekomendasi Saham Hybrid Sesuai Profil & Uang Dingin Lu (${_formatRp(investableCash)}/bulan):',
        );
        buffer.writeln(
          '\n1. **Watchlist Radar Utama (Bluechip & Dividen)**:\n'
          '• **BBRI** (~Rp445.000/lot) — BUY: Fundamental kuat, dividen rutin ~6.5%.\n'
          '• **TLKM** (~Rp278.000/lot) — HOLD/Cicil: Defensif dan ramah buat modal ratusan ribu.\n'
          '• **BBCA** (~Rp925.000/lot) — BUY: Raja perbankan buat tabungan saham jangka panjang.',
        );
        buffer.writeln(
          '\n2. **Rekomendasi Pasar Live (On-Demand IDX Sesuai Modal Lu)**:\n'
          '• **BBNI** (~Rp485.000/lot) — BUY: Valuasi PBV ~1.1x paling diskon di jajaran Big 4 Bank.\n'
          '• **BRIS** (~Rp272.000/lot) — BUY: Pertumbuhan bank syariah agresif & harga 1 lot ramah di kantong.\n'
          '• **GOTO** (~Rp6.800/lot) — HIGH RISK: Harga lot receh, tapi batasi maksimal 5-10% dari uang dingin.',
        );
      }

      return (
        reply: buffer.toString(),
        extractedTx: null,
        needsClarification: false,
        missingFields: <String>[],
      );
    }

    // --- Intent A: Wealth, Funds & Liquid Balance Inquiry ---
    // Example: "berapa dana yang saya miliki sekarang", "cek saldo saya", "uang saya ada berapa"
    if (isWealthQuery) {
      final buffer = StringBuffer();
      buffer.writeln('Ringkasan Saldo & Duit Lu Saat Ini:');
      buffer.writeln(
        '• Duit di Kas / Dompet Utama: ${_formatRp(actualLiquidCash)}',
      );

      if (accounts.isNotEmpty) {
        for (final acc in accounts) {
          buffer.writeln('  - ${acc.name}: ${_formatRp(acc.openingBalance)}');
        }
      }

      if (totalGoalsSaved > 0) {
        buffer.writeln(
          '• Duit di Target Tabungan: ${_formatRp(totalGoalsSaved)}',
        );
        for (final g in goals) {
          buffer.writeln('  - ${g.name}: ${_formatRp(g.currentAmount)}');
        }
      }

      if (initialEmergencyFund > 0) {
        buffer.writeln(
          '• Dana Darurat Awal: ${_formatRp(initialEmergencyFund)}',
        );
      }

      buffer.writeln('• Sisa Uang Bersih Bulan Ini: ${_formatRp(netCashFlow)}');
      buffer.writeln(
        '\nTotal Duit & Tabungan: ${_formatRp(actualLiquidCash + totalGoalsSaved)}.',
      );

      if (netCashFlow >= 0) {
        buffer.writeln(
          'Kondisi keuangan lu bulan ini masih surplus dan selamat terkendali.',
        );
      } else {
        if (strictnessLevel >= 4) {
          buffer.writeln(
            'Mode Kritis: Dompet lu lagi tekor ${_formatRp(netCashFlow.abs())} tolol! Rem jajan lu dongo, jangan banyak gaya!',
          );
        } else {
          buffer.writeln(
            'Awas cok: Bulan ini lu boncos tekor ${_formatRp(netCashFlow.abs())}! Sadar diri mbut, tahan dulu nafsu belanjanya.',
          );
        }
      }

      return (
        reply: buffer.toString(),
        extractedTx: null,
        needsClarification: false,
        missingFields: <String>[],
      );
    }

    // --- Intent B: Purchase Consultation via Chat ---
    // Example 1: "mau beli mobil kira kira bisa gak?" (without price)
    // Example 2: "boleh beli gadget 3 juta?", "mau beli mobil seharga 150 juta bisa gak?" (with price)
    // Example 3: User replies "200jt" after coach asks for price
    if (isPurchaseConsultation) {
      final targetItem = previousConsultationItem ?? _detectItemName(lower);

      if (extractedAmount == null || extractedAmount <= 0) {
        if (strictnessLevel >= 4) {
          return (
            reply:
                'Mau beli $targetItem? Ngaca anjing, miskin kaga tau diri banget lu! Cek dulu isi dompet lu yang sekarat itu mbut!\n\n'
                'Berapa harga $targetItem yang lu taksir atau cicilannya sebulan? Tulis yang jelas bangsat!\n'
                'Saldo kas lu sekarang: ${_formatRp(actualLiquidCash)} ama uang dingin lu: ${_formatRp(freeCash)}.\n\n'
                'Ketik harganya (misal: "Harganya 200 juta"), biar gua telanjangi ama gua anjing-anjingin otak tolol lu kalo kaga sanggup beli!',
            extractedTx: null,
            needsClarification: false,
            missingFields: <String>[],
          );
        }

        return (
          reply:
              'Rencana beli $targetItem? Sini gue itungin biar kaga dongo:\n\n'
              '• Uang dingin sebulan: ${_formatRp(freeCash)}\n'
              '• Saldo kas siap pakai: ${_formatRp(actualLiquidCash)}\n'
              '• Tabungan lu: ${_formatRp(totalGoalsSaved)}\n\n'
              'Berapa harga $targetItem atau cicilannya?\n'
              'Ketik nominalnya (misal: "Harganya 150 juta" atau "Cicilan 2.5 juta"), jangan sok sanggup dulu tod!',
          extractedTx: null,
          needsClarification: false,
          missingFields: <String>[],
        );
      }

      // If price is specified: Run mathematical financial evaluation
      final price = extractedAmount;
      final remainingCash = freeCash - price;
      final ratio = freeCash > 0 ? (price / freeCash * 100).toInt() : 999;

      final months = (price / (freeCash > 0 ? freeCash : 1000000)).ceil();
      final years = (months / 12).toStringAsFixed(1);
      final dp = price * 0.2;
      final monthsForDp = (dp / (freeCash > 0 ? freeCash : 1000000)).ceil();
      final estCicilan = price >= 50000000 ? (price * 1.25 / 48) : (price / 12);

      // Strictness 4-5 or when user's cash is deficit/severely limited: Trigger Savage Roast Mode
      if (strictnessLevel >= 4 ||
          actualLiquidCash <= 0 ||
          price > freeCash * 3) {
        final buffer = StringBuffer();
        buffer.writeln('Mau Beli $targetItem (${_formatRp(price)}):');
        buffer.writeln('Waduh ${_formatRp(price)}?! Sadar diri lu anjing!');
        if (actualLiquidCash <= 0) {
          buffer.writeln(
            'Saldo kas lu aja MINUS (${_formatRp(actualLiquidCash)}), uang dingin sebulan cuma ${_formatRp(freeCash)}!',
          );
        } else {
          buffer.writeln(
            'Saldo kas lu cuma ${_formatRp(actualLiquidCash)} dan uang dingin cuma ${_formatRp(freeCash)}!',
          );
        }
        buffer.writeln('\nCoba liat hitungan matematikanya tod:');
        buffer.writeln(
          '• Beli Tunai: Lu butuh puasa nabung $months bulan ($years TAHUN) tanpa makan enak demi $targetItem!',
        );
        buffer.writeln(
          '• Mau Kredit? DP 20% aja ${_formatRp(dp)} (butuh $monthsForDp bulan ngumpulin DP doang kocak).',
        );
        buffer.writeln(
          '• Estimasi Cicilan: Sekitar ${_formatRp(estCicilan)}/bulan. Duit dingin lu cuma ${_formatRp(freeCash)}, mau nombok pake ginjal lu, cok?!',
        );
        if (dependentsCount > 0) {
          buffer.writeln(
            '• Lu punya $dependentsCount tanggungan keluarga cok, mikir keluarga sebelum gaya!',
          );
        }
        if (primaryGoalSummary.isNotEmpty) {
          buffer.writeln(
            '• Target utama lu "$primaryGoalSummary" apa kabar tod? Malah mau buang duit buat $targetItem!',
          );
        }
        buffer.writeln('\nSaran Tegas Coach:');
        buffer.writeln(
          'Hapus mimpi lu tod! Lunasin minus, kumpulin dana darurat, dan naikin income dulu. Jangan sok elit tapi dompet menjerit!',
        );

        return (
          reply: buffer.toString(),
          extractedTx: null,
          needsClarification: false,
          missingFields: <String>[],
        );
      }

      if (price > freeCash) {
        return (
          reply:
              'Saran Coach: Tahan Dulu Dongo! ($targetItem - ${_formatRp(price)})\n\n'
              '• Harganya ngelebihin uang dingin bulanan lu (${_formatRp(freeCash)}).\n'
              '• Maksa beli sekarang = dompet jebol tekor ${_formatRp(remainingCash.abs())} anjir.\n'
              '• Duit segitu setara ${(price / 1500000).toStringAsFixed(1)} bulan alokasi dana darurat lu.\n\n'
              'Nabung dulu di menu Goals, jangan barbar goblok!',
          extractedTx: null,
          needsClarification: false,
          missingFields: <String>[],
        );
      } else if (price > freeCash * 0.5) {
        return (
          reply:
              'Saran Coach: Pikir Pake Otak Dulu blok ($targetItem - ${_formatRp(price)})\n\n'
              'Barang ini makan $ratio% uang dingin bulanan lu (${_formatRp(freeCash)}). Sisa tinggal ${_formatRp(remainingCash)} doang.\n\n'
              'Tahan 48 jam! Kalo lu masih ngebet dan ga mati tanpanya, baru lu bungkus.',
          extractedTx: null,
          needsClarification: false,
          missingFields: <String>[],
        );
      } else {
        return (
          reply:
              'Saran Coach: Aman, Sikat Aja Cok!\n\n'
              'Beli $targetItem seharga ${_formatRp(price)} cuma makan $ratio% uang dingin bulanan lu (${_formatRp(freeCash)}).\n'
              'Masih sisa ${_formatRp(remainingCash)} buat nabung. Gas tapi jangan kalap!',
          extractedTx: null,
          needsClarification: false,
          missingFields: <String>[],
        );
      }
    }

    // --- Intent F: Transaction Recording (Evaluated BEFORE temporal inquiries so "makan bakso 10k tadi" or "Catat: Nasi padang 25rb" are not misidentified as questions) ---
    if (extractedAmount != null &&
        extractedAmount > 0 &&
        !isQuestion &&
        !isPurchaseConsultation) {
      final wantsEmergencyDeposit = RegExp(
        r'(?:tambah|tambahin|tambahkan|isi|masukin|masukkan|setor|setorin|nabung|tabung|top\s*up|alokasi(?:kan)?)\s+(?:saldo\s+)?(?:ke\s+|untuk\s+|di\s+)?(?:uang|dana)\s+darurat|(?:uang|dana)\s+darurat(?:\s+\w+){0,3}\s+(?:tambah|tambahin|tambahkan|isi|setor|nabung)',
      ).hasMatch(lower);

      final isIncome =
          !wantsEmergencyDeposit &&
          (lower.contains('gaji') ||
              lower.contains('terima') ||
              lower.contains('masuk') ||
              lower.contains('bonus') ||
              lower.contains('upah') ||
              lower.contains('profit') ||
              lower.contains('cuan') ||
              lower.contains('untung') ||
              lower.contains('dividen') ||
              lower.contains('imbal hasil') ||
              lower.contains('pemasukan') ||
              lower.contains('penjualan') ||
              lower.contains('honor') ||
              lower.contains('royalti') ||
              lower.contains('dapat') ||
              lower.contains('dapet') ||
              lower.contains('cair') ||
              lower.contains('saham') ||
              lower.contains('crypto') ||
              lower.contains('kripto') ||
              lower.contains('reksadana'));

      final itemLabel = text
          .replaceAll(
            RegExp(
              r'(?:rp\.?\s*)?(\d{1,3}(?:\.\d{3})+|\d+)(?:\s*(?:juta|jt|ribu|rb|k))?',
              caseSensitive: false,
            ),
            '',
          )
          .replaceAll(
            RegExp(
              r'(catat:?|tadi|siang|malam|pagi|beli|buat|sebesar|rp|ke|di)',
              caseSensitive: false,
            ),
            '',
          )
          .trim();

      final hasKeywords =
          lower.contains('makan') ||
          lower.contains('minum') ||
          lower.contains('kopi') ||
          lower.contains('bensin') ||
          lower.contains('transport') ||
          lower.contains('pulsa') ||
          lower.contains('listrik') ||
          lower.contains('gaji') ||
          lower.contains('bonus') ||
          lower.contains('nonton') ||
          lower.contains('belanja') ||
          lower.contains('obat') ||
          lower.contains('parkir') ||
          lower.contains('tagihan') ||
          lower.contains('freelance') ||
          lower.contains('proyek') ||
          lower.contains('pemasukan') ||
          lower.contains('usaha') ||
          lower.contains('jual') ||
          lower.contains('investasi') ||
          lower.contains('dividen') ||
          lower.contains('saham') ||
          lower.contains('profit') ||
          lower.contains('cuan') ||
          lower.contains('untung') ||
          lower.contains('crypto') ||
          lower.contains('kripto') ||
          lower.contains('reksadana') ||
          lower.contains('tambal') ||
          lower.contains('ban') ||
          lower.contains('servis') ||
          lower.contains('bengkel') ||
          lower.contains('darurat');

      if (!hasKeywords && itemLabel.isEmpty) {
        return (
          reply:
              'Duit ${_formatRp(extractedAmount)} ini buat apaan njir? Yang jelas napa dongo! Contoh ketik: "Beli bensin ${_formatRp(extractedAmount)}" atau "Makan ${_formatRp(extractedAmount)}".',
          extractedTx: null,
          needsClarification: true,
          missingFields: ['kategori/catatan'],
        );
      }

      String cleanNote = itemLabel.isEmpty
          ? (isIncome ? 'Pemasukan' : 'Makan & Minum')
          : itemLabel;
      if (lower.contains('saham')) {
        cleanNote =
            lower.contains('profit') ||
                lower.contains('cuan') ||
                lower.contains('untung')
            ? 'Profit Saham'
            : 'Investasi Saham';
      } else if (lower.contains('crypto') || lower.contains('kripto')) {
        cleanNote = 'Profit Kripto';
      } else if (lower.contains('dividen')) {
        cleanNote = 'Dividen Saham';
      } else if (lower.contains('freelance')) {
        cleanNote = 'Pemasukan Freelance';
      }

      String categorySuggestion = 'Makan & Minum';
      if (isIncome) {
        if (lower.contains('saham') ||
            lower.contains('investasi') ||
            lower.contains('dividen') ||
            lower.contains('profit') ||
            lower.contains('cuan') ||
            lower.contains('crypto') ||
            lower.contains('kripto') ||
            lower.contains('reksadana')) {
          categorySuggestion = 'Investasi & Dividen';
        } else if (lower.contains('freelance') ||
            lower.contains('proyek') ||
            lower.contains('jual') ||
            lower.contains('usaha') ||
            lower.contains('bisnis') ||
            lower.contains('klien')) {
          categorySuggestion = 'Penjualan & Usaha';
        } else if (lower.contains('bonus') ||
            lower.contains('thr') ||
            lower.contains('hadiah')) {
          categorySuggestion = 'Bonus & THR';
        } else {
          categorySuggestion = 'Gaji & Upah';
        }
      } else if (lower.contains('bensin') ||
          lower.contains('transport') ||
          lower.contains('gojek') ||
          lower.contains('grab') ||
          lower.contains('tol') ||
          lower.contains('parkir') ||
          lower.contains('ban') ||
          lower.contains('tambal') ||
          lower.contains('bengkel') ||
          lower.contains('servis')) {
        categorySuggestion = 'Transportasi';
      } else if (lower.contains('listrik') ||
          lower.contains('wifi') ||
          lower.contains('pulsa') ||
          lower.contains('air') ||
          lower.contains('tagihan')) {
        categorySuggestion = 'Tagihan & Utilitas';
      } else if (lower.contains('nonton') ||
          lower.contains('kopi') ||
          lower.contains('game') ||
          lower.contains('hibur')) {
        categorySuggestion = 'Hiburan';
      } else if (lower.contains('obat') ||
          lower.contains('dokter') ||
          lower.contains('sehat') ||
          lower.contains('apotek')) {
        categorySuggestion = 'Kesehatan';
      } else if (lower.contains('belanja') ||
          lower.contains('supermarket') ||
          lower.contains('alfa') ||
          lower.contains('indo')) {
        categorySuggestion = 'Belanja Harian';
      }

      final wantsEmergencyFund = !isIncome &&
          !wantsEmergencyDeposit &&
          RegExp(
            r'(?:pakai|pake|ambil|gunakan|gunain|menggunakan|potong|tarik|dari)\s+(?:uang|dana)\s+darurat',
          ).hasMatch(lower);

      final emergencyGoalCurrent = goals
          .where(
            (g) =>
                g.goalType == GoalType.emergencyFund ||
                g.name.toLowerCase().contains('dana darurat'),
          )
          .fold(0.0, (s, g) => s + g.currentAmount);
      final effectiveEmergencyBalance =
          emergencyGoalCurrent > initialEmergencyFund
              ? emergencyGoalCurrent
              : initialEmergencyFund;

      final formattedAmt = _formatRp(extractedAmount);
      final isEmergencyUsable =
          wantsEmergencyFund && effectiveEmergencyBalance >= extractedAmount;
      final effectiveCategory = (wantsEmergencyDeposit || isEmergencyUsable)
          ? 'Dana Darurat'
          : categorySuggestion;
      final effectiveType = wantsEmergencyDeposit
          ? 'goal_deposit'
          : (isIncome ? 'income' : 'expense');
      final effectiveFundingSource = wantsEmergencyDeposit
          ? 'emergency_fund_deposit'
          : (isEmergencyUsable ? 'emergency_fund' : 'regular');
      final replyText = wantsEmergencyDeposit
          ? (strictnessLevel >= 4
              ? 'Oke, gua siapin draf setoran $formattedAmt ke Dana Darurat lu (saldo sekarang di database: ${_formatRp(effectiveEmergencyBalance)}). Klik "Simpan" di kartu bawah biar beneran masuk ke celengan Dana Darurat, bukan cuma omong kosong!'
              : 'Draf setoran $formattedAmt ke celengan Dana Darurat sudah disiapkan (saldo saat ini: ${_formatRp(effectiveEmergencyBalance)}). Klik "Simpan" di bawah untuk menambahkan ke Dana Darurat.')
          : isEmergencyUsable
          ? (strictnessLevel >= 4
              ? 'Duh, $formattedAmt buat "$cleanNote" aja udah nyentuh Dana Darurat (${_formatRp(effectiveEmergencyBalance)})? Padahal pos $categorySuggestion lu masih bisa diandelin biar Dana Darurat utuh! Tapi karena lu minta, draf penarikan Dana Darurat udah gua siapin — cek sumber dananya di kartu bawah sebelum klik Simpan!'
              : 'Catatan: Pengeluaran $formattedAmt untuk "$cleanNote" sebenarnya lebih disarankan memakai pos $categorySuggestion agar Dana Daruratmu (${_formatRp(effectiveEmergencyBalance)}) tetap terjaga. Namun draf penarikan Dana Darurat sudah disiapkan—kamu dapat memilih sumber dananya di kartu bawah lalu klik Simpan.')
          : (strictnessLevel >= 4
              ? 'Nih draf transaksi ${isIncome ? 'pemasukan (tumben lu dapet duit anjing)' : 'pengeluaran (belanja mulu lu bangsat)'} "$cleanNote" senilai $formattedAmt di pos $effectiveCategory udah gua bikinin.\n\nCek kartu di bawah terus klik "Simpan" buat masukin ke database, ato klik "Batal" kalo otak tolol lu tiba-tiba sadar kagak jadi!'
              : 'Draf transaksi ${isIncome ? 'pemasukan' : 'pengeluaran'} "$cleanNote" senilai $formattedAmt di pos $effectiveCategory sudah disiapkan.\n\nSilakan cek kartu di bawah lalu ketuk "Simpan" untuk mencatat ke database, atau "Batal" jika tidak jadi.');

      return (
        reply: replyText,
        extractedTx: {
          'amount': extractedAmount,
          'type': effectiveType,
          'note': wantsEmergencyDeposit ? 'Setoran Dana Darurat' : cleanNote,
          'category_suggestion': effectiveCategory,
          'funding_source': effectiveFundingSource,
          if (isEmergencyUsable) 'fallback_category_suggestion': categorySuggestion,
          'confidence': 0.95,
        },
        needsClarification: false,
        missingFields: <String>[],
      );
    }

    // --- Intent B.1: Temporal Inquiries (Kemarin, Hari Ini) ---
    // Example: "saya total makan berapa hari kemarin", "kemarin pengeluaran saya berapa", "tadi habis belanja apa", "kalau hari ini"
    String lastUserMessageContent = '';
    for (int i = _localChatHistory.length - 2; i >= 0; i--) {
      if (_localChatHistory[i].isUser) {
        lastUserMessageContent = _localChatHistory[i].content.toLowerCase();
        break;
      }
    }
    final previousHadFoodContext =
        lastUserMessageContent.contains('makan') ||
        lastUserMessageContent.contains('minum') ||
        lastUserMessageContent.contains('kuliner');

    // Temporal Inquiries: Both Today & Yesterday
    // Example: "berapa pengeluaran saya hari ini dan kemarin", "pengeluaran kemarin dan hari ini"
    final isBothTodayAndYesterdayQuery =
        (lower.contains('hari ini') || lower.contains('tadi')) &&
        (lower.contains('kemarin') || lower.contains('kemaren'));

    if (isBothTodayAndYesterdayQuery) {
      final isFoodQuery =
          lower.contains('makan') ||
          lower.contains('minum') ||
          lower.contains('kuliner') ||
          previousHadFoodContext;

      final todayTarget = isFoodQuery
          ? todayTxs.where(isFoodTx).toList()
          : todayTxs
                .where((tx) => tx.transactionType == TransactionType.expense)
                .toList();

      final yesterdayTarget = isFoodQuery
          ? yesterdayTxs.where(isFoodTx).toList()
          : yesterdayTxs
                .where((tx) => tx.transactionType == TransactionType.expense)
                .toList();

      final totalToday = todayTarget.fold(0.0, (s, t) => s + t.amount);
      final totalYesterday = yesterdayTarget.fold(0.0, (s, t) => s + t.amount);
      final combinedTotal = totalToday + totalYesterday;

      final buffer = StringBuffer();
      final dateYesterdayStr =
          '${yesterday.day.toString().padLeft(2, '0')}/${yesterday.month.toString().padLeft(2, '0')}';
      final dateTodayStr =
          '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}';

      buffer.writeln(
        isFoodQuery
            ? 'Rincian Pengeluaran Makan Kemarin & Hari Ini:'
            : 'Rincian Pengeluaran Kemarin & Hari Ini:',
      );
      buffer.writeln(
        '• Kemarin ($dateYesterdayStr): ${_formatRp(totalYesterday)}',
      );
      if (yesterdayTarget.isNotEmpty) {
        for (final tx in yesterdayTarget) {
          final note = tx.note != null && tx.note!.isNotEmpty
              ? ' (${tx.note})'
              : '';
          buffer.writeln(
            '  - ${tx.category?.name ?? 'Makan & Minum'}$note: ${_formatRp(tx.amount)}',
          );
        }
      } else {
        buffer.writeln('  (Tidak ada catatan pengeluaran)');
      }

      buffer.writeln('• Hari Ini ($dateTodayStr): ${_formatRp(totalToday)}');
      if (todayTarget.isNotEmpty) {
        for (final tx in todayTarget) {
          final note = tx.note != null && tx.note!.isNotEmpty
              ? ' (${tx.note})'
              : '';
          buffer.writeln(
            '  - ${tx.category?.name ?? 'Makan & Minum'}$note: ${_formatRp(tx.amount)}',
          );
        }
      } else {
        buffer.writeln('  (Tidak ada catatan pengeluaran)');
      }

      buffer.writeln(
        '\nTotal ${isFoodQuery ? 'makan' : 'pengeluaran'} kemarin + hari ini: ${_formatRp(combinedTotal)}.',
      );
      buffer.writeln(
        'Total seluruh pengeluaran bulan ini di Home: ${_formatRp(totalExpense)} (Sisa Uang Bersih: ${_formatRp(netCashFlow)}).',
      );

      return (
        reply: buffer.toString(),
        extractedTx: null,
        needsClarification: false,
        missingFields: <String>[],
      );
    }

    final isYesterdayQuery =
        lower == 'kemarin' ||
        lower == 'kemaren' ||
        lower == 'kalau kemarin' ||
        lower == 'kalo kemarin' ||
        lower.startsWith('kalau kemarin') ||
        lower.startsWith('kalo kemarin') ||
        ((lower.contains('kemarin') || lower.contains('kemaren')) &&
            (lower.contains('makan') ||
                lower.contains('pengeluaran') ||
                lower.contains('belanja') ||
                lower.contains('transaksi') ||
                lower.contains('total') ||
                lower.contains('berapa') ||
                lower.contains('apa') ||
                lower.contains('gimana') ||
                lower.contains('gmn')));

    if (isYesterdayQuery) {
      final isFoodQuery =
          lower.contains('makan') ||
          lower.contains('minum') ||
          lower.contains('kuliner') ||
          previousHadFoodContext;
      final targetTxs = isFoodQuery
          ? yesterdayTxs.where(isFoodTx).toList()
          : yesterdayTxs
                .where((tx) => tx.transactionType == TransactionType.expense)
                .toList();

      final buffer = StringBuffer();
      final dateStr =
          '${yesterday.day.toString().padLeft(2, '0')}/${yesterday.month.toString().padLeft(2, '0')}/${yesterday.year}';

      if (targetTxs.isEmpty) {
        if (isFoodQuery) {
          buffer.writeln(
            'Kemarin ($dateStr) gak ada catatan pengeluaran makan & minum yang tercatat di sistem.',
          );
          if (yesterdayTxs.isNotEmpty) {
            buffer.writeln('\nTapi ada transaksi lain kemarin:');
            for (final tx in yesterdayTxs) {
              final sign = tx.transactionType == TransactionType.income
                  ? '+'
                  : '-';
              buffer.writeln(
                '• ${tx.note ?? tx.category?.name ?? 'Transaksi'}: $sign${_formatRp(tx.amount)}',
              );
            }
          } else {
            buffer.writeln(
              'Dompet lu kemarin anteng, belum ada transaksi yang kecatat.',
            );
          }
        } else {
          buffer.writeln(
            'Kemarin ($dateStr) lu belum ada catatan transaksi pengeluaran di sistem FinGuard.',
          );
        }
      } else {
        final totalTarget = targetTxs.fold(0.0, (sum, tx) => sum + tx.amount);
        buffer.writeln(
          isFoodQuery
              ? 'Rincian Pengeluaran Makan & Minum Kemarin ($dateStr):'
              : 'Rincian Pengeluaran Kemarin ($dateStr):',
        );
        for (final tx in targetTxs) {
          final note = tx.note != null && tx.note!.isNotEmpty
              ? ' (${tx.note})'
              : '';
          buffer.writeln(
            '• ${tx.category?.name ?? 'Makan & Minum'}$note: ${_formatRp(tx.amount)}',
          );
        }
        buffer.writeln(
          '\nTotal ${isFoodQuery ? 'makan & minum' : 'pengeluaran'} kemarin: ${_formatRp(totalTarget)}.',
        );
      }

      if (strictnessLevel >= 4) {
        buffer.writeln(
          '\nNoh data lu kecatat lengkap ampe ke detik-detiknya di FinGuard tod, jadi kaga usah nanya sambil suudzon lagi!',
        );
      } else {
        buffer.writeln(
          '\nTenang aja, semua transaksi lu tersimpan lengkap dengan tanggal dan jamnya di FinGuard.',
        );
      }

      return (
        reply: buffer.toString(),
        extractedTx: null,
        needsClarification: false,
        missingFields: <String>[],
      );
    }

    final isTodayQuery =
        lower == 'hari ini' ||
        lower == 'kalau hari ini' ||
        lower == 'kalo hari ini' ||
        lower.startsWith('kalau hari ini') ||
        lower.startsWith('kalo hari ini') ||
        lower.startsWith('gimana hari ini') ||
        lower.contains('hari ini gimana') ||
        ((lower.contains('hari ini') || lower.contains('tadi')) &&
            (lower.contains('makan') ||
                lower.contains('pengeluaran') ||
                lower.contains('belanja') ||
                lower.contains('transaksi') ||
                lower.contains('total') ||
                lower.contains('berapa') ||
                lower.contains('apa') ||
                lower.contains('gimana') ||
                lower.contains('gmn')));

    if (isTodayQuery) {
      final isFoodQuery =
          lower.contains('makan') ||
          lower.contains('minum') ||
          lower.contains('kuliner') ||
          previousHadFoodContext;
      final targetTxs = isFoodQuery
          ? todayTxs.where(isFoodTx).toList()
          : todayTxs
                .where((tx) => tx.transactionType == TransactionType.expense)
                .toList();

      final buffer = StringBuffer();
      final dateStr =
          '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

      if (targetTxs.isEmpty) {
        buffer.writeln(
          strictnessLevel >= 4
              ? 'Hari ini ($dateStr) belum ada catatan ${isFoodQuery ? 'makan' : 'pengeluaran'} yang lu masukin anjing. Tumben amat lu anteng bangsat, apa otak tolol lu lupa nyatet gara-gara sibuk halu ngentot?!'
              : 'Hari ini ($dateStr) belum ada catatan ${isFoodQuery ? 'makan & minum' : 'pengeluaran'} yang lu masukin.',
        );
      } else {
        final totalTarget = targetTxs.fold(0.0, (sum, tx) => sum + tx.amount);
        buffer.writeln(
          isFoodQuery
              ? 'Catatan Pengeluaran Makan & Minum Hari Ini ($dateStr):'
              : 'Catatan Pengeluaran Hari Ini ($dateStr):',
        );
        for (final tx in targetTxs) {
          final note = tx.note != null && tx.note!.isNotEmpty
              ? ' (${tx.note})'
              : '';
          buffer.writeln(
            '• ${tx.category?.name ?? 'Makan & Minum'}$note: ${_formatRp(tx.amount)}',
          );
        }
        buffer.writeln(
          '\nTotal ${isFoodQuery ? 'makan' : 'pengeluaran'} hari ini: ${_formatRp(totalTarget)}.',
        );
        if (strictnessLevel >= 4) {
          buffer.writeln(
            'Inget tod, ini baru hari ini doang udah ludes segitu, jangan sok kaya!',
          );
        }
      }

      return (
        reply: buffer.toString(),
        extractedTx: null,
        needsClarification: false,
        missingFields: <String>[],
      );
    }

    // --- Intent B.2: Longevity & Budget Pacing Projection ---
    // Example: "budget makan saya sampai tanggal berapa", "tahan berapa hari", "awet berapa lama"
    final isLongevityQuery =
        lower.contains('tahan berapa') ||
        lower.contains('sampai tanggal') ||
        lower.contains('sampai kapan') ||
        lower.contains('awet berapa') ||
        lower.contains('habis tanggal') ||
        lower.contains('habis kapan') ||
        (lower.contains('budget') &&
            (lower.contains('berapa hari') ||
                lower.contains('sampai kapan'))) ||
        (lower.contains('jatah') &&
            (lower.contains('berapa hari') || lower.contains('sampai kapan')));

    if (isLongevityQuery) {
      BudgetEntity? targetBudget;
      for (final b in budgets) {
        final catNameLower = (b.categoryName ?? '').toLowerCase();
        if (catNameLower.isNotEmpty &&
            lower.contains(catNameLower.split(' ').first)) {
          targetBudget = b;
          break;
        }
      }
      targetBudget ??= budgets
          .where((b) => (b.categoryName ?? '').toLowerCase().contains('makan'))
          .firstOrNull;
      targetBudget ??= budgets.isNotEmpty ? budgets.first : null;

      if (targetBudget != null) {
        final spent = targetBudget.spentAmount;
        final limit = targetBudget.limitAmount;
        final remaining = (limit - spent).clamp(0.0, double.infinity);

        // Find elapsed days in month to calculate daily pacing
        final daysElapsed = now.day.clamp(1, 31);
        final dailyAvg = spent > 0 ? (spent / daysElapsed) : 0.0;
        final effectiveDaily = dailyAvg > 0 ? dailyAvg : (limit / 30);

        final daysLeft = effectiveDaily > 0
            ? (remaining / effectiveDaily).round()
            : 30;
        final projectedDate = now.add(Duration(days: daysLeft));
        final projectedStr =
            '${projectedDate.day} ${_monthName(projectedDate.month)} ${projectedDate.year}';

        final buffer = StringBuffer();
        buffer.writeln(
          '📊 Proyeksi Daya Tahan Jatah "${targetBudget.categoryName}":',
        );
        buffer.writeln('• Total Jatah: ${_formatRp(limit)}');
        buffer.writeln('• Terpakai Sejauh Ini: ${_formatRp(spent)}');
        buffer.writeln('• Sisa Jatah Tersedia: ${_formatRp(remaining)}');
        buffer.writeln(
          '• Rata-rata Pemakaian: ${_formatRp(effectiveDaily)}/hari (berdasarkan ritme $daysElapsed hari bulan ini)\n',
        );

        if (remaining <= 0) {
          buffer.writeln(
            strictnessLevel >= 4
                ? '⚠️ Jatah kategori ini udah ludes lu babat habis anjing! Puasa lu sekarang bangsat, kagak usah banyak gaya belanja lagi ngentot, miskin kaga tau diri!'
                : '⚠️ Jatah kategori ini sudah habis! Lu kudu rem total pengeluaran di pos ini sampai bulan depan!',
          );
        } else if (strictnessLevel >= 4) {
          buffer.writeln('💡 Hitungan Realistis Buat Lu:');
          buffer.writeln(
            'Dengan gaya makan/belanja lu yang rata-rata ${_formatRp(effectiveDaily)}/hari, sisa jatah lu bakal ludes sekitar $daysLeft hari lagi (kira-kira tanggal $projectedStr).\nKalo lu masih barbar foya-foya ya siap-siap aja makan promag di akhir bulan, njir!',
          );
        } else {
          buffer.writeln('💡 Hasil Hitungan:');
          buffer.writeln(
            'Dengan kecepatan belanja saat ini (~${_formatRp(effectiveDaily)}/hari), sisa jatah lu diproyeksikan bakal tahan sekitar $daysLeft hari ke depan.',
          );
          buffer.writeln('Estimasi aman sampai sekitar tanggal $projectedStr.');
        }

        return (
          reply: buffer.toString(),
          extractedTx: null,
          needsClarification: false,
          missingFields: <String>[],
        );
      }
    }

    // --- Intent C: Budget Inquiry & Calculation ---
    // Example: "sisa budget makan berapa?", "status budget saya"
    if (lower.contains('budget') ||
        lower.contains('anggaran') ||
        lower.contains('jatah')) {
      // Check for specific category query
      BudgetEntity? targetBudget;
      for (final b in budgets) {
        final catNameLower = (b.categoryName ?? '').toLowerCase();
        if (catNameLower.isNotEmpty &&
            lower.contains(catNameLower.split(' ').first)) {
          targetBudget = b;
          break;
        }
      }

      if (targetBudget != null) {
        final spent = targetBudget.spentAmount;
        final limit = targetBudget.limitAmount;
        final remaining = limit - spent;
        final ratio = limit > 0 ? (spent / limit * 100).toInt() : 0;
        final statusText = ratio > 100
            ? 'JEBOL TOLOL: Jatah lu udah babat habis lewat batas!'
            : ratio >= 85
            ? 'AWAS TOLOL: Jatah lu sekarat sisa dikit lagi!'
            : 'Masih aman, tumben lu waras tod.';

        return (
          reply:
              '📊 Cek Jatah Belanja: "${targetBudget.categoryName}"\n'
              '• Jatah sebulan: ${_formatRp(limit)}\n'
              '• Udah kepakai: ${_formatRp(spent)} ($ratio%)\n'
              '• Sisa jatah: ${_formatRp(remaining > 0 ? remaining : 0)}'
              '${remaining < 0 ? ' (Jebol ${_formatRp(remaining.abs())} njir!)' : ''}\n\n'
              'Kondisi: $statusText\n'
              '${remaining <= 0 ? '⚠️ Jatah kategori ini udah ludes dongo! Puasa dulu di pos ini sampai awal bulan!' : '👍 Masih ada sisa, tapi jangan gatel mau dihabisin cok.'}',
          extractedTx: null,
          needsClarification: false,
          missingFields: <String>[],
        );
      }

      // Overall budgets overview
      final totalBudgetLimit = budgets.fold<double>(
        0,
        (sum, b) => sum + b.limitAmount,
      );
      final totalBudgetSpent = budgets.fold<double>(
        0,
        (sum, b) => sum + b.spentAmount,
      );
      final overallRatio = totalBudgetLimit > 0
          ? (totalBudgetSpent / totalBudgetLimit * 100).toInt()
          : 0;

      final buffer = StringBuffer();
      buffer.writeln('📊 Status Jatah Belanja Bulanan:');
      buffer.writeln('• Total Jatah: ${_formatRp(totalBudgetLimit)}');
      buffer.writeln(
        '• Udah Kepakai: ${_formatRp(totalBudgetSpent)} ($overallRatio%)',
      );
      buffer.writeln(
        '• Sisa Jatah Tersedia: ${_formatRp(totalBudgetLimit - totalBudgetSpent)}\n',
      );
      buffer.writeln('Rincian Pos Belanja:');

      for (final b in budgets) {
        final bRatio = b.limitAmount > 0
            ? (b.spentAmount / b.limitAmount * 100).toInt()
            : 0;
        final icon = bRatio > 100
            ? '🔴'
            : bRatio >= 85
            ? '🟡'
            : '🟢';
        buffer.writeln(
          '$icon ${b.categoryName}: ${_formatRp(b.spentAmount)} / ${_formatRp(b.limitAmount)} ($bRatio%)',
        );
      }

      buffer.writeln(
        '\n💡 Saran Coach: Pos bertanda merah udah jebol anjir, rem sekarang mbut sebelum lu ngemis di akhir bulan!',
      );

      return (
        reply: buffer.toString(),
        extractedTx: null,
        needsClarification: false,
        missingFields: <String>[],
      );
    }

    // --- Intent D: Goals & Savings Status (Dana Darurat, Tabungan, Impian) ---
    // Example: "bagaimana dana darurat saya?", "cek tabungan saya"
    if (lower.contains('dana darurat') ||
        lower.contains('tabungan') ||
        lower.contains('tujuan') ||
        lower.contains('target') ||
        lower.contains('goals') ||
        lower.contains('impian')) {
      if (goals.isEmpty) {
        return (
          reply:
              'Lu belum bikin celengan apa-apa anjing! Bikin pos tabungan (minimal "Dana Darurat") di menu Goals biar kaga minjem pinjol pas apes!',
          extractedTx: null,
          needsClarification: false,
          missingFields: <String>[],
        );
      }

      final buffer = StringBuffer();
      buffer.writeln('🎯 Progres Tabungan & Target Lu Tod:');
      for (final g in goals) {
        final progress = g.progressPercentage * 100;
        final remaining = g.remainingAmount;
        buffer.writeln('\n• ${g.name} (${g.goalType.displayName}):');
        buffer.writeln(
          '  Udah kekumpul: ${_formatRp(g.currentAmount)} dari target ${_formatRp(g.targetAmount)} (${progress.toInt()}%)',
        );
        buffer.writeln('  Kurang: ${_formatRp(remaining)} lagi');
      }

      if (contributions.isNotEmpty) {
        buffer.writeln('\nRiwayat Setoran Tabungan Terakhir:');
        for (final c in contributions.take(4)) {
          final gName = (c['financial_goals'] is Map)
              ? c['financial_goals']['name']
              : 'Celengan';
          final amt = (c['amount'] as num?)?.toDouble() ?? 0.0;
          final dt = c['contribution_date']?.toString() ?? '';
          final note = c['note'] != null && c['note'].toString().isNotEmpty
              ? ' ("${c['note']}")'
              : '';
          buffer.writeln('• [$dt] $gName$note: +${_formatRp(amt)}');
        }
      }

      buffer.writeln(
        '\n💡 Saran Coach: Beresin dulu Dana Darurat minimal 3-6 bulan biaya hidup tod, baru mikir flexing!',
      );

      return (
        reply: buffer.toString(),
        extractedTx: null,
        needsClarification: false,
        missingFields: <String>[],
      );
    }

    // --- Intent D.2: Monthly Review / Evaluasi Bulanan ---
    // Example: "gimana evaluasi bulan lalu?", "cek evaluasi bulanan", "laporan bulan kemarin"
    if (lower.contains('evaluasi') ||
        (lower.contains('review') && lower.contains('bulan')) ||
        (lower.contains('laporan') && lower.contains('bulan'))) {
      if (latestReview != null) {
        final period =
            '${latestReview['period_start']} s/d ${latestReview['period_end']}';
        final narrative =
            latestReview['narrative']?.toString() ??
            'Evaluasi bulanan sudah tercatat.';
        return (
          reply:
              '📑 Evaluasi Bulanan FinGuard ($period):\n\n'
              '$narrative\n\n'
              'Bisa dicek selengkapnya di menu "Evaluasi Bulanan" tod!',
          extractedTx: null,
          needsClarification: false,
          missingFields: <String>[],
        );
      } else {
        return (
          reply:
              'Belum ada laporan evaluasi bulanan yang tersimpan tod. Evaluasi bakal otomatis dibikin tiap akhir/awal bulan atau bisa kamu cek di menu Evaluasi Bulanan!',
          extractedTx: null,
          needsClarification: false,
          missingFields: <String>[],
        );
      }
    }

    // --- Intent E: Arus Kas, Pengeluaran & Pemasukan ---
    // Example: "berapa pengeluaran saya?", "gimana arus kas saya?", "cek pemasukan"
    if (lower.contains('pengeluaran') ||
        lower.contains('pemasukan') ||
        lower.contains('arus kas') ||
        lower.contains('cashflow') ||
        lower.contains('transaksi') ||
        lower.contains('belanjaan')) {
      final sortedCategories = categoryExpenseMap.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final topCat = sortedCategories.isNotEmpty
          ? sortedCategories.first
          : null;

      final buffer = StringBuffer();
      buffer.writeln('📈 Ringkasan Duit Masuk & Keluar Bulan Ini:');
      buffer.writeln('• Total Pemasukan: ${_formatRp(totalIncome)}');
      buffer.writeln('• Total Pengeluaran: ${_formatRp(totalExpense)}');
      buffer.writeln(
        '• Sisa Duit Bersih: ${_formatRp(netCashFlow)} (${netCashFlow >= 0 ? 'Surplus / Masih Selamat' : 'Boncos / Defisit Anjir'})',
      );

      if (topCat != null) {
        buffer.writeln(
          '• Pos Paling Boros: ${topCat.key} (${_formatRp(topCat.value)})',
        );
      }

      if (transactions.isNotEmpty) {
        buffer.writeln('\nTransaksi Terakhir:');
        for (final tx in transactions.take(3)) {
          final sign = tx.transactionType == TransactionType.income ? '+' : '-';
          buffer.writeln(
            '  • ${tx.note ?? tx.category?.name ?? 'Transaksi'}: $sign${_formatRp(tx.amount)}',
          );
        }
      }

      return (
        reply: buffer.toString(),
        extractedTx: null,
        needsClarification: false,
        missingFields: <String>[],
      );
    }

    // --- Intent G: Financial Advice & Health Check ---
    // Example: "beri saran keuangan", "tips hemat", "gimana kondisi keuangan saya?", "Kasih masukan dong buat dompet gue"
    final isAdviceQuery =
        lower.contains('saran') ||
        lower.contains('masukan') ||
        lower.contains('evaluasi') ||
        lower.contains('kondisi keuangan') ||
        lower.contains('keuangan gue') ||
        lower.contains('keuangan saya') ||
        lower.contains('dompet gue') ||
        lower.contains('dompet saya') ||
        lower.contains('tips hemat') ||
        lower.contains('rekomendasi keuangan') ||
        lower.contains('kesehatan finansial') ||
        lower.contains('nasihat');

    if (isAdviceQuery) {
      final savingsRate = totalIncome > 0
          ? (netCashFlow / totalIncome * 100).toInt()
          : 0;
      final overBudgets = budgets
          .where((b) => b.spentAmount > b.limitAmount)
          .toList();

      final buffer = StringBuffer();
      if (strictnessLevel >= 4) {
        buffer.writeln('Evaluasi Finansial Lu Tod:');
        buffer.writeln(
          '1. Arus Kas: ${netCashFlow >= 0 ? 'Surplus ${_formatRp(netCashFlow)}' : 'Tekor ${_formatRp(netCashFlow.abs())} anjir'} (Porsi tabungan: $savingsRate%).',
        );
        if (overBudgets.isNotEmpty) {
          buffer.writeln(
            '2. Jatah Belanja: Pos "${overBudgets.map((b) => b.categoryName).join(', ')}" udah jebol tolol!',
          );
        } else {
          buffer.writeln('2. Jatah Belanja: Masih aman, tumben otak lu jalan.');
        }
        buffer.writeln(
          '3. Profil & Laju Finansial: Profil $riskProfile | Frekuensi Pemasukan: $incomeFrequency.',
        );
        buffer.writeln('4. Prioritas: Amankan Dana Darurat lu dulu tod!');
        buffer.writeln(
          '\nAda yang mau lu tanyain lagi gak tod, sebelum dompet lu nangis?',
        );
      } else {
        buffer.writeln('Evaluasi Keuangan Kamu:');
        buffer.writeln(
          '1. Arus Kas: ${netCashFlow >= 0 ? 'Surplus ${_formatRp(netCashFlow)}' : 'Defisit ${_formatRp(netCashFlow.abs())}'} (Rasio tabungan: $savingsRate%).',
        );
        if (overBudgets.isNotEmpty) {
          buffer.writeln(
            '2. Anggaran: Pos "${overBudgets.map((b) => b.categoryName).join(', ')}" melebihi batas yang direncanakan.',
          );
        } else {
          buffer.writeln(
            '2. Anggaran: Seluruh alokasi pos anggaran masih dalam batas aman.',
          );
        }
        buffer.writeln(
          '3. Profil Risiko: $riskProfile | Frekuensi Pemasukan: $incomeFrequency.',
        );
        buffer.writeln(
          '4. Prioritas: Pertahankan porsi tabungan dan tingkatkan dana darurat.',
        );
        buffer.writeln('\nAda yang ingin kamu diskusikan lagi?');
      }

      return (
        reply: buffer.toString(),
        extractedTx: null,
        needsClarification: false,
        missingFields: <String>[],
      );
    }

    // --- Intent H: Offline Fallback for Unrecognized / Casual Queries ---
    final fallbackReply = strictnessLevel >= 4
        ? 'Otak AI gua lagi ngelag apa internet lu yang ampas gembel sih anjing?! Buat bacot santai atau analisa ribet butuh internet stabil, tolol!\n\nTapi untung gua masih pinter, catat transaksi, cek jatah belanja, saldo kas, ama ngitung boncosnya dompet lu tetep bisa gua kerjain lokal tanpa internet. Ulangi chat lu yang bener ato buruan tanyain soal duit lu yang sekarat itu bangsat!'
        : 'Koneksi ke AI Coach sedang terganggu atau jaringan internet sedang lambat. Untuk percakapan santai atau analisa cerdas, pastikan koneksi internet stabil ya.\n\nKamu tetap bisa mencatat pengeluaran/pemasukan, cek sisa anggaran, dan melihat status dompetmu secara langsung. Silakan coba kirim ulang pesanmu!';

    return (
      reply: fallbackReply,
      extractedTx: null,
      needsClarification: false,
      missingFields: <String>[],
    );
  }

  /// Parses multiple Indonesian nominal expressions:
  /// "150 juta", "3.5 jt", "50rb", "35k", "Rp 35.000", "50000"
  double? _extractAmount(String text) {
    // 1. Check for "juta" / "jt"
    final jutaRegex = RegExp(
      r'(\d+(?:[.,]\d+)?)\s*(?:juta|jt)',
      caseSensitive: false,
    );
    final jutaMatch = jutaRegex.firstMatch(text);
    if (jutaMatch != null) {
      final numStr = jutaMatch.group(1)!.replaceAll(',', '.');
      final val = double.tryParse(numStr);
      if (val != null) return val * 1000000;
    }

    // 2. Check for "ribu" / "rb" / "k"
    final ribuRegex = RegExp(
      r'(\d+(?:[.,]\d+)?)\s*(?:ribu|rb|k)',
      caseSensitive: false,
    );
    final ribuMatch = ribuRegex.firstMatch(text);
    if (ribuMatch != null) {
      final numStr = ribuMatch.group(1)!.replaceAll(',', '.');
      final val = double.tryParse(numStr);
      if (val != null) return val * 1000;
    }

    // 3. Check for standard dotted/raw numbers: "35.000", "50000", "Rp 1.500.000"
    final numRegex = RegExp(
      r'(?:rp\.?\s*)?(\d{1,3}(?:\.\d{3})+|\d{4,})',
      caseSensitive: false,
    );
    final numMatch = numRegex.firstMatch(text);
    if (numMatch != null) {
      final rawNum = numMatch.group(1)!.replaceAll('.', '');
      return double.tryParse(rawNum);
    }

    return null;
  }

  String _detectItemName(String lower) {
    if (lower.contains('mobil')) return 'Mobil';
    if (lower.contains('motor')) return 'Motor';
    if (lower.contains('rumah')) return 'Rumah';
    if (lower.contains('gadget') || lower.contains('hp')) {
      return 'Gadget / Smartphone';
    }
    if (lower.contains('laptop')) return 'Laptop';
    if (lower.contains('sepatu')) return 'Sepatu';
    return 'Barang Idaman';
  }

  String _formatRp(double num) {
    return 'Rp${num.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }

  String _monthName(int month) {
    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    if (month >= 1 && month <= 12) return months[month - 1];
    return '';
  }

  @override
  void clearLocalHistory() {
    _localChatHistory.clear();
    _pendingGetOrCreate = null;
    _cachedConversationId = null;
  }
}
