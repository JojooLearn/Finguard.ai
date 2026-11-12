import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';

void main() {
  testWidgets(
    'ai_coach_typing.json renders across full loop without Gradient.linear disposal errors',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 34,
                height: 34,
                child: Lottie.asset(
                  'assets/animations/ai_coach_typing.json',
                  repeat: true,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
      );

      // Allow asset bundle loading to complete
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Step through full 1.4s loop (35 frames @ 25fps) in fine increments
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 75));
      }

      expect(tester.takeException(), isNull);
    },
  );
}

