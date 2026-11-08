import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:finguard/core/result/result.dart';
import 'package:finguard/features/coach/domain/entities/chat_conversation_entity.dart';
import 'package:finguard/features/coach/domain/entities/chat_message_entity.dart';
import 'package:finguard/features/coach/domain/repositories/coach_repository.dart';
import 'package:finguard/features/coach/domain/services/voice_io_service.dart';
import 'package:finguard/features/coach/presentation/cubit/coach_cubit.dart';
import 'package:finguard/features/coach/presentation/cubit/coach_state.dart';

class FakeVoiceCoachRepository implements CoachRepository {
  bool? lastRequestAudioFlag;
  String? lastSentMessage;
  int? lastStrictnessLevel;

  @override
  Future<Result<List<ChatMessageEntity>>> getChatHistory({
    String? conversationId,
  }) async {
    return const Success([]);
  }

  @override
  Future<Result<List<ChatConversationEntity>>> getConversations() async {
    return const Success([]);
  }

  @override
  Future<Result<ChatConversationEntity>> createConversation({
    String? title,
  }) async {
    final now = DateTime.now();
    return Success(
      ChatConversationEntity(
        id: 'conv_test_1',
        title: title ?? 'Test',
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  @override
  Future<Result<void>> deleteConversation(String conversationId) async {
    return const Success(null);
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
    lastSentMessage = message;
    lastRequestAudioFlag = requestAudio;
    lastStrictnessLevel = strictnessLevel;

    final isExpenseCommand = message.toLowerCase().contains('catat makan');
    String replyText;
    if (strictnessLevel != null && strictnessLevel >= 4) {
      replyText = isExpenseCommand
          ? 'Makan mulu lu anjing, lambung lu karet apa gimana bangsat?! Tuh draf makan Rp20.000 udah gua bikinin, buruan konfirmasi sebelum dompet lu mampus gembel!'
          : 'Gaya lu elit tapi dompet melintir anjing! Mau nanya apaan lu? Mending ngaca dulu, duit lu udah sekarat total tolol!';
    } else if (strictnessLevel != null && strictnessLevel <= 2) {
      replyText = isExpenseCommand
          ? 'Wah semangat ya! Pengeluaran makan Rp20.000 sudah disiapkan drafnya. Cek dulu yuk sebelum disimpan.'
          : 'Halo! Senang bisa nemenin kamu atur keuangan hari ini.';
    } else {
      replyText = isExpenseCommand
          ? 'Siap! Draf pengeluaran makan Rp20.000 sudah gue siapkan di bawah.'
          : 'Halo juga! Ada yang bisa Coach bantu hari ini?';
    }

    final audioPayload = requestAudio
        ? VoiceIoService.generateSynthesizedCoachVoiceWavBase64(replyText)
        : null;

    return Success(
      ChatMessageEntity(
        id: 'ast_${DateTime.now().millisecondsSinceEpoch}',
        conversationId: conversationId ?? 'conv_test_1',
        senderType: ChatSenderType.assistant,
        content: replyText,
        createdAt: DateTime.now(),
        structuredPayload: isExpenseCommand
            ? {
                'type': 'expense',
                'amount': 20000,
                'category_suggestion': 'Makan & Minum',
                'note': 'Makan',
                'audio_base64': ?audioPayload,
              }
            : null,
        audioBase64: audioPayload,
      ),
    );
  }

  @override
  Future<void> updateMessageMetadata({
    required String messageId,
    required Map<String, dynamic> metadata,
  }) async {}

  @override
  void clearLocalHistory() {}
}

void main() {
  group('Contextual Voice I/O (STT & AI Voice-Out) Feature Verification', () {
    late FakeVoiceCoachRepository fakeRepository;
    late CoachCubit coachCubit;

    setUp(() {
      fakeRepository = FakeVoiceCoachRepository();
      coachCubit = CoachCubit(coachRepository: fakeRepository);
    });

    tearDown(() async {
      await coachCubit.close();
    });

    test(
      'AC-1 & AC-3 (Logika 1: Teks -> Teks & Isolasi Beban): Manual text input sends requestAudio: false and returns NO audio_base64',
      () async {
        await coachCubit.sendMessage('Halo coach', requestAudio: false);

        expect(fakeRepository.lastSentMessage, equals('Halo coach'));
        expect(fakeRepository.lastRequestAudioFlag, isFalse);

        final state = coachCubit.state as CoachLoaded;
        final aiReply = state.messages.last;
        expect(aiReply.isUser, isFalse);
        expect(aiReply.audioBase64, isNull);
        expect(aiReply.effectiveAudioBase64, isNull);
        expect(aiReply.hasAudio, isFalse);
      },
    );

    test(
      'AC-2 (Logika 2: Suara -> Teks+Suara): Voice STT input ("Catat makan 20 ribu") sends requestAudio: true and returns text, structured transaction, AND audio_base64',
      () async {
        await coachCubit.sendMessage('Catat makan 20 ribu', requestAudio: true);

        expect(fakeRepository.lastSentMessage, equals('Catat makan 20 ribu'));
        expect(fakeRepository.lastRequestAudioFlag, isTrue);

        final state = coachCubit.state as CoachLoaded;
        final aiReply = state.messages.last;
        expect(aiReply.isUser, isFalse);
        expect(aiReply.hasPendingExtraction, isTrue);
        expect(aiReply.structuredPayload?['amount'], equals(20000));
        expect(aiReply.hasAudio, isTrue);
        expect(aiReply.effectiveAudioBase64, isNotNull);
        expect(aiReply.effectiveAudioBase64!.isNotEmpty, isTrue);
      },
    );

    test(
      'AC-4 (In-Memory Audio Decode): InMemoryWavAudioSource decodes Base64 audio and wraps raw PCM16 into valid RIFF WAVE stream in memory',
      () async {
        // Test raw PCM16 wrapping
        final rawPcm = Uint8List.fromList(List<int>.filled(480, 0));
        final rawPcmB64 = base64Encode(rawPcm);

        final source = InMemoryWavAudioSource.fromBase64(rawPcmB64);
        expect(source.contentType, equals('audio/wav'));
        expect(source.audioBytes.length, equals(44 + rawPcm.length));

        // Verify RIFF WAVE header magic bytes
        final header = ascii.decode(source.audioBytes.sublist(0, 4));
        final waveTag = ascii.decode(source.audioBytes.sublist(8, 12));
        expect(header, equals('RIFF'));
        expect(waveTag, equals('WAVE'));

        // Verify StreamAudioSource request slices bytes strictly from memory
        final response = await source.request(0, 44);
        expect(response.sourceLength, equals(44 + rawPcm.length));
        expect(response.contentLength, equals(44));
        expect(response.contentType, equals('audio/wav'));
        final streamedChunk = await response.stream.first;
        expect(streamedChunk.length, equals(44));
      },
    );
    test(
      'AC-5 (Persona Roast / Toxic Level 5): Strictness Level 5 activates Savage Roast persona and routes correctly',
      () async {
        await coachCubit.sendMessage(
          'Mau beli iPhone 16 Pro',
          requestAudio: false,
          strictnessLevel: 5,
        );

        expect(
          fakeRepository.lastSentMessage,
          equals('Mau beli iPhone 16 Pro'),
        );
        expect(fakeRepository.lastStrictnessLevel, equals(5));

        final state = coachCubit.state as CoachLoaded;
        final aiReply = state.messages.last;
        expect(aiReply.isUser, isFalse);
        expect(aiReply.content, contains('Gaya lu elit tapi dompet melintir'));
      },
    );

    test(
      'AC-6 (Persona Suportif Level 2): Strictness Level 2 activates Supportive persona and routes correctly',
      () async {
        await coachCubit.sendMessage(
          'Catat makan 20 ribu',
          requestAudio: false,
          strictnessLevel: 2,
        );

        expect(fakeRepository.lastSentMessage, equals('Catat makan 20 ribu'));
        expect(fakeRepository.lastStrictnessLevel, equals(2));

        final state = coachCubit.state as CoachLoaded;
        final aiReply = state.messages.last;
        expect(aiReply.isUser, isFalse);
        expect(aiReply.content, contains('Wah semangat ya!'));
      },
    );

    test(
      'AC-7 (Combined Voice-In + Roast Level 5): Voice STT input with Roast persona produces Savage text AND audio',
      () async {
        await coachCubit.sendMessage(
          'Catat makan 20 ribu',
          requestAudio: true,
          strictnessLevel: 5,
        );

        expect(fakeRepository.lastSentMessage, equals('Catat makan 20 ribu'));
        expect(fakeRepository.lastRequestAudioFlag, isTrue);
        expect(fakeRepository.lastStrictnessLevel, equals(5));

        final state = coachCubit.state as CoachLoaded;
        final aiReply = state.messages.last;
        expect(aiReply.isUser, isFalse);
        expect(aiReply.hasAudio, isTrue);
        expect(aiReply.content, contains('lambung lu karet'));
        expect(aiReply.effectiveAudioBase64, isNotNull);
      },
    );
  });
}
