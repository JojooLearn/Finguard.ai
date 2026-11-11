import 'dart:async';
import 'package:bloc_test/bloc_test.dart';
import 'package:finguard/features/coach/domain/entities/chat_message_entity.dart';
import 'package:finguard/features/coach/domain/services/voice_io_service.dart';
import 'package:finguard/features/coach/presentation/cubit/coach_cubit.dart';
import 'package:finguard/features/coach/presentation/cubit/coach_state.dart';
import 'package:finguard/features/coach/presentation/pages/coach_page.dart';
import 'package:finguard/features/profile/domain/entities/profile_entity.dart';
import 'package:finguard/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:finguard/features/profile/presentation/cubit/profile_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:mocktail/mocktail.dart';

class _MockCoachCubit extends MockCubit<CoachState> implements CoachCubit {}

class _MockProfileCubit extends MockCubit<ProfileState>
    implements ProfileCubit {}

class _MockFlutterTts extends Mock implements FlutterTts {}

void main() {
  group('VoiceIoService Character-Tuned Fallback', () {
    late _MockFlutterTts mockTts;
    late VoiceIoService service;

    setUp(() {
      mockTts = _MockFlutterTts();
      service = VoiceIoService(flutterTts: mockTts);

      when(() => mockTts.setLanguage(any())).thenAnswer((_) async => 1);
      when(() => mockTts.setVolume(any())).thenAnswer((_) async => 1);
      when(() => mockTts.setPitch(any())).thenAnswer((_) async => 1);
      when(() => mockTts.setSpeechRate(any())).thenAnswer((_) async => 1);
      when(() => mockTts.setVoice(any())).thenAnswer((_) async => 1);
      when(() => mockTts.speak(any(), focus: any(named: 'focus')))
          .thenAnswer((_) async => 1);
      when(() => mockTts.stop()).thenAnswer((_) async => 1);
      when(() => mockTts.getVoices).thenAnswer(
        (_) async => [
          {'name': 'id-id-x-idc-local', 'locale': 'id-ID', 'gender': 'female'},
          {'name': 'id-id-x-dfz-local', 'locale': 'id-ID', 'gender': 'male'},
        ],
      );
    });

    test('resolveLocalVoiceParams maps Suportif, Pro, and Roast differently', () {
      final suportif = VoiceIoService.resolveLocalVoiceParams(1);
      final pro = VoiceIoService.resolveLocalVoiceParams(3);
      final roast = VoiceIoService.resolveLocalVoiceParams(5);

      expect(suportif.characterTier, 'suportif');
      expect(suportif.pitch, greaterThan(pro.pitch));
      expect(suportif.speechRate, lessThan(pro.speechRate));

      expect(pro.characterTier, 'pro');
      expect(pro.pitch, 1.0);
      expect(pro.speechRate, 0.48);

      expect(roast.characterTier, 'roast');
      expect(roast.pitch, lessThan(pro.pitch));
      expect(roast.speechRate, greaterThan(pro.speechRate));
    });

    test('speak selects Indonesian device voice and pitch/rate per character', () async {
      await service.speak('Halo teman!', strictnessLevel: 2);
      verify(() => mockTts.setPitch(1.12)).called(1);
      verify(() => mockTts.setSpeechRate(0.45)).called(1);
      verify(
        () => mockTts.setVoice({
          'name': 'id-id-x-idc-local',
          'locale': 'id-ID',
        }),
      ).called(1);

      await service.speak('Duit lu boncos!', strictnessLevel: 5);
      verify(() => mockTts.setPitch(0.88)).called(1);
      verify(() => mockTts.setSpeechRate(0.54)).called(1);
      verify(
        () => mockTts.setVoice({
          'name': 'id-id-x-dfz-local',
          'locale': 'id-ID',
        }),
      ).called(1);
    });
  });

  group('CoachPage Active Character Audio Integration', () {
    testWidgets(
      'displays character voice caption and tunes fallback TTS when ProfileCubit strictness is Roast (5)',
      (tester) async {
        final mockCoachCubit = _MockCoachCubit();
        final mockProfileCubit = _MockProfileCubit();
        final mockTts = _MockFlutterTts();
        final stateController = StreamController<CoachState>.broadcast();

        when(() => mockTts.setLanguage(any())).thenAnswer((_) async => 1);
        when(() => mockTts.setVolume(any())).thenAnswer((_) async => 1);
        when(() => mockTts.setPitch(any())).thenAnswer((_) async => 1);
        when(() => mockTts.setSpeechRate(any())).thenAnswer((_) async => 1);
        when(() => mockTts.getVoices).thenAnswer((_) async => []);
        when(() => mockTts.speak(any(), focus: any(named: 'focus')))
            .thenAnswer((_) async => 1);
        when(() => mockTts.stop()).thenAnswer((_) async => 1);

        final voiceIo = VoiceIoService(flutterTts: mockTts);

        when(() => mockProfileCubit.state).thenReturn(
          const ProfileLoaded(
            ProfileEntity(
              id: 'u1',
              displayName: 'Budi',
              email: 'budi@finguard.id',
              strictnessLevel: 5,
            ),
          ),
        );
        const initialLoaded = CoachLoaded(messages: [], isSending: false);
        when(() => mockCoachCubit.state).thenReturn(initialLoaded);
        whenListen(
          mockCoachCubit,
          stateController.stream,
          initialState: initialLoaded,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MultiBlocProvider(
                providers: [
                  BlocProvider<CoachCubit>.value(value: mockCoachCubit),
                  BlocProvider<ProfileCubit>.value(value: mockProfileCubit),
                ],
                child: CoachPage(voiceIoService: voiceIo),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final roastMsg = ChatMessageEntity(
          id: 'ast_roast_1',
          conversationId: 'c1',
          senderType: ChatSenderType.assistant,
          content: 'Dompet lu sekarat bro!',
          structuredPayload: const {
            'voice_out': true,
            'voice_character': 'Roast',
          },
          createdAt: DateTime.now(),
          autoSpeak: true,
        );

        final nextLoaded = CoachLoaded(messages: [roastMsg], isSending: false);
        when(() => mockCoachCubit.state).thenReturn(nextLoaded);
        stateController.add(nextLoaded);
        await tester.pumpAndSettle();

        // Auto-speak begins immediately with Roast character tuning
        expect(find.text('Memutar suara Coach...'), findsOneWidget);
        expect(find.text('Ketuk untuk jeda'), findsOneWidget);
        verify(() => mockTts.setPitch(0.88)).called(1);
        verify(() => mockTts.setSpeechRate(0.54)).called(1);

        // Pausing stops TTS and displays active character badge caption
        await tester.tap(find.byKey(const Key('mini_audio_player_ast_roast_1')));
        await tester.pumpAndSettle();

        verify(() => mockTts.stop()).called(greaterThanOrEqualTo(1));
        expect(find.text('Suara Roast • Ketuk untuk dengar'), findsOneWidget);

        await stateController.close();
      },
    );
  });
}

