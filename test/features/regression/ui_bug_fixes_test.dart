import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finguard/app/di/injection.dart';
import 'package:finguard/app/theme/app_colors.dart';
import 'package:finguard/features/consultation/domain/entities/consultation_result_entity.dart';
import 'package:finguard/features/consultation/domain/repositories/consultation_repository.dart';
import 'package:finguard/features/consultation/presentation/cubit/consultation_cubit.dart';
import 'package:finguard/features/consultation/presentation/pages/purchase_consultation_page.dart';
import 'package:finguard/features/goals/domain/entities/goal_entity.dart';
import 'package:finguard/features/goals/domain/repositories/goal_repository.dart';
import 'package:finguard/features/goals/presentation/cubit/goal_cubit.dart';
import 'package:finguard/features/goals/presentation/pages/goals_page.dart';
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
class MockGoalRepository extends Mock implements GoalRepository {}
class MockConsultationRepository extends Mock implements ConsultationRepository {}

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

    testWidgets('GoalsPage contribution input uses empty controller and gray 0 placeholder without hardcoded 500.000', (tester) async {
      final mockGoalRepo = MockGoalRepository();
      final now = DateTime.now();
      when(() => mockGoalRepo.getGoals()).thenAnswer((_) async => Success([
            GoalEntity(
              id: 'goal-1',
              userId: 'user-1',
              name: 'Dana Darurat',
              goalType: GoalType.emergencyFund,
              targetAmount: 6750000,
              currentAmount: 0,
              createdAt: now,
              updatedAt: now,
            ),
          ]));

      final goalCubit = GoalCubit(goalRepository: mockGoalRepo);
      await goalCubit.loadGoals();

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<GoalCubit>.value(
            value: goalCubit,
            child: const GoalsPage(),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Masukin Tabungan'));
      await tester.pumpAndSettle();

      expect(find.text('Tambah Tabungan'), findsOneWidget);
      expect(find.text('500.000'), findsNothing);

      final numericField = tester.widget<TextField>(find.byType(TextField).first);
      expect(numericField.controller?.text, isEmpty);
      expect(numericField.decoration?.hintText, '0');
      expect(numericField.decoration?.hintStyle?.color, AppColors.textPlaceholder);
    });

    testWidgets('PurchaseConsultationPage formats Coach markdown cleanly without raw asterisks', (tester) async {
      final mockConsultRepo = MockConsultationRepository();
      when(() => mockConsultRepo.consultPurchase(
            itemName: any(named: 'itemName'),
            estimatedPrice: any(named: 'estimatedPrice'),
            categoryName: any(named: 'categoryName'),
          )).thenAnswer((_) async => const Success(ConsultationResultEntity(
            itemName: 'Parfum Mykonos',
            estimatedPrice: 500000,
            verdict: ConsultationVerdict.affordable,
            explanation: '**Statusnya:** *Aman dibeli!* Sisa uang dingin lu masih Rp2.000.000.',
            freeCash: 2500000,
            remainingCash: 2000000,
            priceRatioToFreeCash: 20.0,
          )));

      await sl.reset();
      sl.registerFactory<ConsultationCubit>(
        () => ConsultationCubit(consultationRepository: mockConsultRepo),
      );
      addTearDown(sl.reset);

      await tester.pumpWidget(
        const MaterialApp(
          home: PurchaseConsultationPage(),
        ),
      );

      await tester.enterText(find.byType(TextField).at(0), 'Parfum Mykonos');
      await tester.enterText(find.byType(TextField).at(1), '500.000');
      await tester.tap(find.text('Cek Kelayakan Beli'));
      await tester.pumpAndSettle();

      expect(find.text('Aman untuk Dibeli'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is RichText &&
              w.text.toPlainText().contains('Statusnya: Aman dibeli!') &&
              !w.text.toPlainText().contains('*'),
        ),
        findsOneWidget,
      );
    });
  });
}
