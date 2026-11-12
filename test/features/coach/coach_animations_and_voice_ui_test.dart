import 'dart:async';
import 'dart:io';
import 'package:bloc_test/bloc_test.dart';
import 'package:finguard/features/coach/domain/entities/chat_message_entity.dart';
import 'package:finguard/features/coach/domain/services/voice_io_service.dart';
import 'package:finguard/features/coach/presentation/cubit/coach_cubit.dart';
import 'package:finguard/features/coach/presentation/cubit/coach_state.dart';
import 'package:finguard/features/coach/presentation/pages/coach_page.dart';
import 'package:finguard/features/coach/presentation/widgets/voice_listening_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';
import 'package:mocktail/mocktail.dart';

class _MockCoachCubit extends MockCubit<CoachState> implements CoachCubit {}

class _MockVoiceIoService extends Mock implements VoiceIoService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Lottie Animation Assets Validation', () {
    test(
      'all 5 FinGuard Lottie animations parse cleanly and splash embeds Piggy Bank',
      () async {
        final paths = [
          'assets/animations/scr01_splash_initial_loading.json',
          'assets/animations/piggy_bank.json',
          'assets/animations/piggy_bank_broken.json',
          'assets/animations/ai_coach_typing.json',
          'assets/animations/voice_listening.json',
        ];

        for (final path in paths) {
          final bytes = await File(path).readAsBytes();
          final comp = await LottieComposition.fromBytes(bytes);
          expect(
            comp.duration,
            greaterThan(Duration.zero),
            reason: '$path should have positive Lottie duration',
          );
        }

        final splashRaw = await File(
          'assets/animations/scr01_splash_initial_loading.json',
        ).readAsString();
        expect(splashRaw.contains('comp_piggy'), isTrue);
        expect(splashRaw.contains('Piggy Bank Hero'), isTrue);
        expect(splashRaw.contains('Inner Glow Aura'), isTrue);
        expect(splashRaw.contains('Outer Glow Pulse'), isTrue);
        expect(splashRaw.contains('Bouncy Gold Coin'), isFalse);
        expect(splashRaw.contains('Chat Bubble AI Gradient'), isFalse);

        final brokenRaw = await File(
          'assets/animations/piggy_bank_broken.json',
        ).readAsString();
        expect(brokenRaw.contains('Piggy Left Half'), isTrue);
        expect(brokenRaw.contains('Piggy Right Half'), isTrue);
        expect(brokenRaw.contains('Crack Bolt'), isTrue);

        // Guard against Lottie 3.3.3 CanvasKit crash ("Gradient.linear was disposed")
        // caused by GradientStroke ('ty':'gs') combined with animated zero-scale keyframes.
        final typingRaw = await File(
          'assets/animations/ai_coach_typing.json',
        ).readAsString();
        expect(typingRaw.contains('"ty":"gs"'), isFalse);
      },
    );
  });

  group('VoiceListeningModal UI & Lottie Replacement', () {
    testWidgets(
      'uses voice_listening.json Lottie and removes redundant Batal and close (X) buttons',
      (tester) async {
        final mockVoice = _MockVoiceIoService();
        when(() => mockVoice.isSpeaking).thenReturn(false);
        when(() => mockVoice.stopSpeaking()).thenAnswer((_) async {});
        when(() => mockVoice.stopListening()).thenAnswer((_) async {});
        when(() => mockVoice.cancelListening()).thenAnswer((_) async {});
        when(
          () => mockVoice.startListening(
            onResult: any(named: 'onResult'),
            onStatus: any(named: 'onStatus'),
            onError: any(named: 'onError'),
            onSoundLevelChange: any(named: 'onSoundLevelChange'),
            localeId: any(named: 'localeId'),
          ),
        ).thenAnswer((_) async => true);

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    VoiceListeningModal.show(
                      context: context,
                      voiceIoService: mockVoice,
                      onSend: (_) {},
                    );
                  },
                  child: const Text('Open Voice'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Voice'));
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.byType(VoiceListeningModal), findsOneWidget);
        expect(find.text('Mendengarkan Suara...'), findsOneWidget);

        // New voice Lottie asset is rendered
        final lottieFinder = find.byWidgetPredicate(
          (w) =>
              w is LottieBuilder &&
              w.lottie is AssetLottie &&
              (w.lottie as AssetLottie).assetName ==
                  'assets/animations/voice_listening.json',
        );
        expect(lottieFinder, findsOneWidget);

        // Both redundant exit controls removed
        expect(find.text('Batal'), findsNothing);
        expect(find.byIcon(Icons.close), findsNothing);

        // Tap outside modal dismisses bottom sheet cleanly
        await tester.tapAt(const Offset(10, 10));
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(VoiceListeningModal), findsNothing);
      },
    );
  });

  group('CoachPage Animations & Income/Expense Popups', () {
    late _MockCoachCubit mockCoachCubit;
    late _MockVoiceIoService mockVoiceIo;
    late StreamController<CoachState> stateController;

    setUp(() {
      mockCoachCubit = _MockCoachCubit();
      mockVoiceIo = _MockVoiceIoService();
      stateController = StreamController<CoachState>.broadcast();

      when(() => mockVoiceIo.isSpeaking).thenReturn(false);
      when(() => mockVoiceIo.stopSpeaking()).thenAnswer((_) async {});
      when(() => mockVoiceIo.stopListening()).thenAnswer((_) async {});
      when(() => mockCoachCubit.clearConfirmFeedback()).thenReturn(null);
    });

    tearDown(() async {
      await stateController.close();
    });

    Widget buildCoachPage() {
      return MaterialApp(
        home: Scaffold(
          body: BlocProvider<CoachCubit>.value(
            value: mockCoachCubit,
            child: CoachPage(
              voiceIoService: mockVoiceIo,
            ),
          ),
        ),
      );
    }

    testWidgets(
      'displays ai_coach_typing.json Lottie while Coach is typing',
      (tester) async {
        const sendingState = CoachLoaded(
          messages: [],
          isSending: true,
        );
        when(() => mockCoachCubit.state).thenReturn(sendingState);
        whenListen(mockCoachCubit, stateController.stream, initialState: sendingState);

        await tester.pumpWidget(buildCoachPage());
        await tester.pump(const Duration(milliseconds: 200));

        // Pump across full typing animation cycle to verify all keyframes render cleanly
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 250));
        }

        expect(tester.takeException(), isNull);
        expect(find.text('Wait, Sabar Boss...'), findsOneWidget);
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is LottieBuilder &&
                w.lottie is AssetLottie &&
                (w.lottie as AssetLottie).assetName ==
                    'assets/animations/ai_coach_typing.json',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'shows Piggy Bank popup on newly confirmed income and broken Piggy Bank popup on newly confirmed expense without popping up historical messages',
      (tester) async {
        final now = DateTime.now();
        final historicalIncome = ChatMessageEntity(
          id: 'hist_inc_1',
          conversationId: 'c1',
          senderType: ChatSenderType.assistant,
          content: 'Gaji lama tercatat.',
          createdAt: now.subtract(const Duration(days: 1)),
          isConfirmed: true,
          structuredPayload: const {
            'type': 'income',
            'amount': 2000000,
            'note': 'Gaji bulan lalu',
            'confirmed': true,
          },
        );

        final initialState = CoachLoaded(
          messages: [historicalIncome],
          isSending: false,
        );
        when(() => mockCoachCubit.state).thenReturn(initialState);
        whenListen(
          mockCoachCubit,
          stateController.stream,
          initialState: initialState,
        );

        await tester.pumpWidget(buildCoachPage());
        await tester.pump(const Duration(milliseconds: 200));

        // Historical message on initial load MUST NOT trigger popup
        expect(find.text('Pemasukan Tercatat!'), findsNothing);
        expect(find.text('Pengeluaran Tercatat!'), findsNothing);

        // Emit newly confirmed income
        final newIncome = ChatMessageEntity(
          id: 'new_inc_1',
          conversationId: 'c1',
          senderType: ChatSenderType.assistant,
          content: 'Bonus project tercatat!',
          createdAt: now,
          isConfirmed: true,
          structuredPayload: const {
            'type': 'income',
            'amount': 500000,
            'note': 'Bonus freelance',
            'confirmed': true,
          },
        );
        final incomeState = CoachLoaded(
          messages: [historicalIncome, newIncome],
          isSending: false,
        );
        when(() => mockCoachCubit.state).thenReturn(incomeState);
        stateController.add(incomeState);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Pemasukan Tercatat!'), findsOneWidget);
        expect(find.text('+Rp500.000'), findsOneWidget);
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is LottieBuilder &&
                w.lottie is AssetLottie &&
                (w.lottie as AssetLottie).assetName ==
                    'assets/animations/piggy_bank.json',
          ),
          findsOneWidget,
        );

        // Auto-dismisses cleanly after 2.2s
        await tester.pump(const Duration(milliseconds: 2300));
        await tester.pumpAndSettle();
        expect(find.text('Pemasukan Tercatat!'), findsNothing);

        // Emit newly confirmed expense
        final newExpense = ChatMessageEntity(
          id: 'new_exp_1',
          conversationId: 'c1',
          senderType: ChatSenderType.assistant,
          content: 'Kopi tercatat.',
          createdAt: now,
          isConfirmed: true,
          structuredPayload: const {
            'type': 'expense',
            'amount': 35000,
            'note': 'Ngopi sore',
            'confirmed': true,
          },
        );
        final expenseState = CoachLoaded(
          messages: [historicalIncome, newIncome, newExpense],
          isSending: false,
        );
        when(() => mockCoachCubit.state).thenReturn(expenseState);
        stateController.add(expenseState);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Pengeluaran Tercatat!'), findsOneWidget);
        expect(find.text('-Rp35.000'), findsOneWidget);
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is LottieBuilder &&
                w.lottie is AssetLottie &&
                (w.lottie as AssetLottie).assetName ==
                    'assets/animations/piggy_bank_broken.json',
          ),
          findsOneWidget,
        );

        // Auto-dismisses cleanly after 2.2s
        await tester.pump(const Duration(milliseconds: 2300));
        await tester.pumpAndSettle();
        expect(find.text('Pengeluaran Tercatat!'), findsNothing);
      },
    );
  });
}
