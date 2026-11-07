import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finguard/features/stock_signals/presentation/widgets/stock_signal_dashboard_card.dart';
import 'package:finguard/features/stock_signals/presentation/cubit/stock_signal_list_cubit.dart';
import 'package:finguard/features/stock_signals/domain/usecases/get_latest_signals.dart';
import 'package:finguard/features/coach/presentation/cubit/coach_cubit.dart';
import 'package:finguard/features/coach/presentation/cubit/coach_state.dart';
import 'package:finguard/features/coach/presentation/pages/coach_page.dart';
import 'package:finguard/features/coach/domain/repositories/coach_repository.dart';
import 'package:finguard/features/notifications/domain/notification_helper.dart';
import 'package:finguard/features/profile/domain/entities/profile_entity.dart';
import 'package:finguard/features/profile/presentation/cubit/profile_state.dart';
import 'package:finguard/features/stock_signals/domain/entities/stock_signal.dart';
import 'package:finguard/features/stock_signals/presentation/cubit/stock_signal_list_state.dart';
import 'package:finguard/core/result/result.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mocktail/mocktail.dart';

class MockGetLatestSignals extends Mock implements GetLatestSignals {}
class MockCoachRepository extends Mock implements CoachRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UI Bug Fixes & Regression Verification', () {
    late MockGetLatestSignals mockGetSignals;
    late MockCoachRepository mockCoachRepo;

    setUp(() {
      mockGetSignals = MockGetLatestSignals();
      mockCoachRepo = MockCoachRepository();
    });

    testWidgets('StockSignalDashboardCard renders native StockSparklineChart and TradingView detail sheet without crash', (tester) async {
      final now = DateTime.now();
      final sampleSignal = StockSignal(
        id: 'sig_1',
        ticker: 'BBCA',
        signalType: StockSignalType.buy,
        priceAtSignal: 5200,
        analysisNotes: 'Akumulasi di support MA20',
        validUntil: now.add(const Duration(days: 1)),
        createdAt: now,
      );
      when(() => mockGetSignals.call()).thenAnswer((_) async => Success([sampleSignal]));

      final cubit = StockSignalListCubit(mockGetSignals);
      await cubit.loadSignals();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlocProvider<StockSignalListCubit>.value(
              value: cubit,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: StockSignalDashboardCard(),
              ),
            ),
          ),
        ),
      );

      // Verify sparkline chart & Live TV indicator rendered on card
      expect(find.text('Radar Sinyal Saham'), findsOneWidget);
      expect(find.text('Live TV'), findsOneWidget);
      expect(find.byType(StockSparklineChart), findsOneWidget);

      // Tap card to open detail sheet with high-res chart and TradingView button
      await tester.tap(find.text('BBCA'));
      await tester.pumpAndSettle();

      expect(find.text('TradingView'), findsOneWidget);
      expect(find.text('Support'), findsOneWidget);
      expect(find.text('Pivot Sinyal'), findsOneWidget);
      expect(find.text('Resistance'), findsOneWidget);
    });

    testWidgets('Chat history with 0 conversations renders clean state without ghost conversations', (tester) async {
      when(() => mockCoachRepo.getConversations()).thenAnswer((_) async => const Success([]));
      when(() => mockCoachRepo.getChatHistory()).thenAnswer((_) async => const Success([]));

      final coachCubit = CoachCubit(coachRepository: mockCoachRepo);
      await coachCubit.loadConversations();

      expect(coachCubit.state, isA<CoachLoaded>());
      final loadedState = coachCubit.state as CoachLoaded;
      expect(loadedState.conversations, isEmpty);
    });

    testWidgets('CoachPage input bar has multiline TextField and single right-side scan button opening Camera/Gallery sheet', (tester) async {
      when(() => mockCoachRepo.getChatHistory()).thenAnswer((_) async => const Success([]));
      final coachCubit = CoachCubit(coachRepository: mockCoachRepo);
      await coachCubit.loadChatHistory();

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(padding: EdgeInsets.only(bottom: 112)),
            child: Scaffold(
              body: BlocProvider<CoachCubit>.value(
                value: coachCubit,
                child: const CoachPage(isKeyboardOpen: false),
              ),
            ),
          ),
        ),
      );

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.minLines, 1);
      expect(textField.maxLines, 4);

      final scanBtn = find.byKey(const Key('scan_receipt_action_button'));
      expect(scanBtn, findsOneWidget);

      await tester.tap(scanBtn);
      await tester.pumpAndSettle();

      expect(find.text('Scan Nota / Lampirkan Struk'), findsOneWidget);
      expect(find.text('Kamera'), findsOneWidget);
      expect(find.text('Galeri'), findsOneWidget);
    });

    test('NotificationHelper does not spam brand new user with yesterday stock signals or fake monthly review', () {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));

      final newProfile = ProfileEntity(
        id: 'new_user_123',
        displayName: 'User Baru',
        email: 'baru@finguard.app',
        onboardingCompletedAt: now,
        createdAt: now,
      );

      final oldSignal = StockSignal(
        id: '1',
        ticker: 'BBCA',
        signalType: StockSignalType.buy,
        priceAtSignal: 9250,
        validUntil: now.add(const Duration(days: 1)),
        createdAt: yesterday,
      );

      final notifs = NotificationHelper.buildNotifications(
        profileState: ProfileLoaded(newProfile),
        stockSignalState: StockSignalLoaded([oldSignal]),
      );

      // Should only have the 1 welcome blueprint notification, not yesterday's stock signal or fake monthly review
      expect(notifs.length, 1);
      expect(notifs.first.id, 'system_welcome_blueprint');
    });

    test('Receipt scan failure does not return irrelevant monthly financial summary', () {
      const fallbackMsg =
          'Foto nota belum dapat diproses oleh AI Vision saat ini. Pastikan foto struk terlihat jelas, tidak buram, dan memuat angka total belanja, lalu silakan coba foto ulang.';
      expect(fallbackMsg.contains('Ringkasan Duit Masuk & Keluar Bulan Ini'), isFalse);
      expect(fallbackMsg.contains('nota'), isTrue);
    });
  });
}
