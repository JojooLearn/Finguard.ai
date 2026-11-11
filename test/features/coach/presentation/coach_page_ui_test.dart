import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:finguard/features/coach/domain/entities/chat_message_entity.dart';
import 'package:finguard/features/coach/domain/services/voice_io_service.dart';
import 'package:finguard/features/coach/presentation/cubit/coach_cubit.dart';
import 'package:finguard/features/coach/presentation/cubit/coach_state.dart';
import 'package:finguard/features/coach/presentation/pages/coach_page.dart';

class MockCoachCubit extends Mock implements CoachCubit {}

class MockFlutterTts extends Mock implements FlutterTts {}

void main() {
  late MockCoachCubit mockCoachCubit;
  late MockFlutterTts mockFlutterTts;

  setUp(() {
    mockCoachCubit = MockCoachCubit();
    mockFlutterTts = MockFlutterTts();

    when(() => mockFlutterTts.setLanguage(any())).thenAnswer((_) async => 1);
    when(() => mockFlutterTts.setPitch(any())).thenAnswer((_) async => 1);
    when(() => mockFlutterTts.setSpeechRate(any())).thenAnswer((_) async => 1);
    when(() => mockFlutterTts.setVolume(any())).thenAnswer((_) async => 1);
    when(() => mockFlutterTts.speak(any(), focus: any(named: 'focus')))
        .thenAnswer((_) async => 1);
    when(() => mockFlutterTts.stop()).thenAnswer((_) async => 1);
  });

  Widget buildWidget({
    bool isKeyboardOpen = false,
    bool isActive = true,
    List<ChatMessageEntity> messages = const [],
    Stream<CoachState>? stateStream,
    VoiceIoService? voiceIoService,
  }) {
    when(() => mockCoachCubit.state).thenReturn(
      CoachLoaded(
        messages: messages,
        isSending: false,
      ),
    );
    when(() => mockCoachCubit.stream)
        .thenAnswer((_) => stateStream ?? const Stream.empty());
    when(() => mockCoachCubit.sendMessage(
          any(),
          conversationId: any(named: 'conversationId'),
          requestAudio: any(named: 'requestAudio'),
          strictnessLevel: any(named: 'strictnessLevel'),
        )).thenAnswer((_) async {});

    return MaterialApp(
      home: Scaffold(
        body: BlocProvider<CoachCubit>.value(
          value: mockCoachCubit,
          child: CoachPage(
            isKeyboardOpen: isKeyboardOpen,
            isActive: isActive,
            voiceIoService: voiceIoService,
          ),
        ),
      ),
    );
  }

  group('CoachPage UI & Keyboard Responsiveness', () {
    testWidgets('renders quick suggestions right above the message input field',
        (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      // Quick suggestions should exist
      expect(find.text('Catat: Nasi padang 25rb'), findsOneWidget);
      expect(find.text('Sisa jatah jajan makan berapa?'), findsOneWidget);

      // Input field should exist
      expect(find.byType(TextField), findsOneWidget);

      // Verify suggestions are placed above the text field in the layout hierarchy
      final suggestionsCenter =
          tester.getCenter(find.text('Catat: Nasi padang 25rb'));
      final textFieldCenter = tester.getCenter(find.byType(TextField));
      expect(suggestionsCenter.dy, lessThan(textFieldCenter.dy));
    });

    testWidgets(
        'formats long multi-paragraph coach response with proper paragraph spacing and bullets',
        (tester) async {
      final longMessage = ChatMessageEntity(
        id: 'msg_coach_1',
        conversationId: 'c1',
        senderType: ChatSenderType.assistant,
        content:
            'Pengeluaran makan lu udah Rp60.000.\n\nSaran gue:\n- Masak sendiri di kos\n- Bawa tumbler air minum\n\nDompet aman!',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(buildWidget(messages: [longMessage]));
      await tester.pumpAndSettle();

      // Verify all paragraph blocks exist
      expect(find.text('Pengeluaran makan lu udah Rp60.000.'), findsOneWidget);
      expect(find.text('Saran gue:'), findsOneWidget);
      expect(find.text('Masak sendiri di kos'), findsOneWidget);
      expect(find.text('Bawa tumbler air minum'), findsOneWidget);
      expect(find.text('Dompet aman!'), findsOneWidget);

      // Bullet symbols are rendered
      expect(find.text('•'), findsNWidgets(2));
    });

    testWidgets('applies compact padding when keyboard is open',
        (tester) async {
      await tester.pumpWidget(buildWidget(isKeyboardOpen: true));
      await tester.pumpAndSettle();

      // When keyboard is open, suggestions and text field are still visible
      expect(find.text('Catat: Nasi padang 25rb'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });
  });

  group('QA Scenarios 3, 4 & 5: Communication Mirroring & Audio UX Safety', () {
    testWidgets(
        'QA-3 Silent Mode (Text-In -> Text-Out): manual text sends requestAudio=false and NEVER calls flutterTts.speak',
        (tester) async {
      final controller = StreamController<CoachState>.broadcast();
      final voiceIoService = VoiceIoService(flutterTts: mockFlutterTts);

      await tester.pumpWidget(
        buildWidget(
          stateStream: controller.stream,
          voiceIoService: voiceIoService,
        ),
      );
      await tester.pumpAndSettle();

      // Type manually into input field & press Send button
      await tester.enterText(find.byType(TextField), 'Berapa sisa budget saya?');
      await tester.pump();
      await tester.tap(find.byKey(const Key('voice_or_send_action_button')));
      await tester.pump();

      verify(
        () => mockCoachCubit.sendMessage(
          'Berapa sisa budget saya?',
          requestAudio: false,
          strictnessLevel: any(named: 'strictnessLevel'),
        ),
      ).called(1);

      // Simulate text-only reply arriving from Dual-AI backend (autoSpeak: false)
      final silentReply = ChatMessageEntity(
        id: 'ast_silent_1',
        conversationId: 'c1',
        senderType: ChatSenderType.assistant,
        content: 'Sisa budget kamu bulan ini masih aman Rp 1.500.000.',
        createdAt: DateTime.now(),
        autoSpeak: false,
      );
      controller.add(CoachLoaded(messages: [silentReply], isSending: false));
      await tester.pumpAndSettle();

      expect(
        find.text('Sisa budget kamu bulan ini masih aman Rp 1.500.000.'),
        findsOneWidget,
      );
      verifyNever(() => mockFlutterTts.speak(any(), focus: any(named: 'focus')));

      await controller.close();
    });

    testWidgets(
        'QA-4 Interactive Mode (Voice-In -> Voice-Out): Voice reply automatically configures id-ID & speaks via flutter_tts',
        (tester) async {
      final controller = StreamController<CoachState>.broadcast();
      final voiceIoService = VoiceIoService(flutterTts: mockFlutterTts);

      await tester.pumpWidget(
        buildWidget(
          stateStream: controller.stream,
          voiceIoService: voiceIoService,
        ),
      );
      await tester.pumpAndSettle();

      // Simulate Voice-In assistant reply arriving (autoSpeak: true, voice_out: true)
      final voiceReply = ChatMessageEntity(
        id: 'ast_voice_1',
        conversationId: 'c1',
        senderType: ChatSenderType.assistant,
        content: 'Siap, catatan pengeluaran bensin **Rp20.000** udah disiapin.',
        structuredPayload: const {
          'type': 'expense',
          'amount': 20000,
          'category_suggestion': 'Transportasi',
          'note': 'Bensin',
          'voice_out': true,
        },
        createdAt: DateTime.now(),
        autoSpeak: true,
      );

      controller.add(CoachLoaded(messages: [voiceReply], isSending: false));
      await tester.pumpAndSettle();

      // Mini TTS player control should appear in the bubble
      expect(find.byKey(const Key('mini_audio_player_ast_voice_1')), findsOneWidget);

      // Verify Indonesian TTS configuration & automatic speech playback
      verify(() => mockFlutterTts.setLanguage('id-ID')).called(1);
      verify(() => mockFlutterTts.setPitch(1.0)).called(1);
      verify(() => mockFlutterTts.setSpeechRate(any())).called(1);
      verify(
        () => mockFlutterTts.speak(
          'Siap, catatan pengeluaran bensin 20.000 rupiah udah disiapin.',
          focus: any(named: 'focus'),
        ),
      ).called(1);

      await controller.close();
    });

    testWidgets(
        'QA-5 Audio Interruption (UX Safety): leaving CoachPage to Home stops flutter_tts immediately',
        (tester) async {
      final controller = StreamController<CoachState>.broadcast();
      final voiceIoService = VoiceIoService(flutterTts: mockFlutterTts);

      Widget harness({required bool isActive}) {
        when(() => mockCoachCubit.state).thenReturn(
          const CoachLoaded(messages: [], isSending: false),
        );
        when(() => mockCoachCubit.stream).thenAnswer((_) => controller.stream);
        return MaterialApp(
          home: Scaffold(
            body: BlocProvider<CoachCubit>.value(
              value: mockCoachCubit,
              child: CoachPage(
                isActive: isActive,
                voiceIoService: voiceIoService,
              ),
            ),
          ),
        );
      }

      await tester.pumpWidget(harness(isActive: true));
      await tester.pumpAndSettle();

      // Trigger long Voice-Out speech
      final longVoiceReply = ChatMessageEntity(
        id: 'ast_voice_long',
        conversationId: 'c1',
        senderType: ChatSenderType.assistant,
        content: 'Ini analisis finansial lengkap bulan ini yang panjang sekali.',
        structuredPayload: const {'voice_out': true},
        createdAt: DateTime.now(),
        autoSpeak: true,
      );
      controller.add(CoachLoaded(messages: [longVoiceReply], isSending: false));
      await tester.pumpAndSettle();

      verify(
        () => mockFlutterTts.speak(
          'Ini analisis finansial lengkap bulan ini yang panjang sekali.',
          focus: any(named: 'focus'),
        ),
      ).called(1);

      clearInteractions(mockFlutterTts);

      // User presses Back / switches back to Home tab (isActive -> false)
      await tester.pumpWidget(harness(isActive: false));
      await tester.pumpAndSettle();

      // Voice-Out MUST stop immediately!
      verify(() => mockFlutterTts.stop()).called(greaterThanOrEqualTo(1));

      await controller.close();
    });

    testWidgets(
        'QA-5b Audio Interruption on Route Pop: popping pushed CoachPage stops flutter_tts immediately',
        (tester) async {
      final controller = StreamController<CoachState>.broadcast();
      final voiceIoService = VoiceIoService(flutterTts: mockFlutterTts);
      when(() => mockCoachCubit.state).thenReturn(
        const CoachLoaded(messages: [], isSending: false),
      );
      when(() => mockCoachCubit.stream).thenAnswer((_) => controller.stream);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => Scaffold(
                        body: BlocProvider<CoachCubit>.value(
                          value: mockCoachCubit,
                          child: CoachPage(voiceIoService: voiceIoService),
                        ),
                      ),
                    ),
                  );
                },
                child: const Text('Go to Coach'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Go to Coach'));
      await tester.pumpAndSettle();

      final voiceMsg = ChatMessageEntity(
        id: 'ast_pop_test',
        conversationId: 'c1',
        senderType: ChatSenderType.assistant,
        content: 'Penjelasan anggaran lengkap untuk bulan ini.',
        structuredPayload: const {'voice_out': true},
        createdAt: DateTime.now(),
        autoSpeak: true,
      );
      controller.add(CoachLoaded(messages: [voiceMsg], isSending: false));
      await tester.pumpAndSettle();

      clearInteractions(mockFlutterTts);

      // User presses Back / pops route back to Home
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pop();
      await tester.pumpAndSettle();

      verify(() => mockFlutterTts.stop()).called(greaterThanOrEqualTo(1));

      await controller.close();
    });
  });
}
