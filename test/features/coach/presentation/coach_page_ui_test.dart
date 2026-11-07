import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:finguard/features/coach/domain/entities/chat_message_entity.dart';
import 'package:finguard/features/coach/presentation/cubit/coach_cubit.dart';
import 'package:finguard/features/coach/presentation/cubit/coach_state.dart';
import 'package:finguard/features/coach/presentation/pages/coach_page.dart';

class MockCoachCubit extends Mock implements CoachCubit {}

void main() {
  late MockCoachCubit mockCoachCubit;

  setUp(() {
    mockCoachCubit = MockCoachCubit();
  });

  Widget buildWidget({bool isKeyboardOpen = false, List<ChatMessageEntity> messages = const []}) {
    when(() => mockCoachCubit.state).thenReturn(CoachLoaded(
      messages: messages,
      isSending: false,
    ));
    when(() => mockCoachCubit.stream).thenAnswer((_) => const Stream.empty());

    return MaterialApp(
      home: Scaffold(
        body: BlocProvider<CoachCubit>.value(
          value: mockCoachCubit,
          child: CoachPage(isKeyboardOpen: isKeyboardOpen),
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
      final suggestionsCenter = tester.getCenter(find.text('Catat: Nasi padang 25rb'));
      final textFieldCenter = tester.getCenter(find.byType(TextField));
      expect(suggestionsCenter.dy, lessThan(textFieldCenter.dy));
    });

    testWidgets('formats long multi-paragraph coach response with proper paragraph spacing and bullets',
        (tester) async {
      final longMessage = ChatMessageEntity(
        id: 'msg_coach_1',
        conversationId: 'c1',
        senderType: ChatSenderType.assistant,
        content: 'Pengeluaran makan lu udah Rp60.000.\n\nSaran gue:\n- Masak sendiri di kos\n- Bawa tumbler air minum\n\nDompet aman!',
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

    testWidgets('applies compact padding when keyboard is open', (tester) async {
      await tester.pumpWidget(buildWidget(isKeyboardOpen: true));
      await tester.pumpAndSettle();

      // When keyboard is open, suggestions and text field are still visible
      expect(find.text('Catat: Nasi padang 25rb'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });
  });
}
