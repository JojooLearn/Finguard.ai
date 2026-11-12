import 'dart:async';
import 'package:finguard/core/services/push_notification_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'PushNotificationService catches missing native plugins without leaking unhandled async DartErrors',
    () async {
      SharedPreferences.setMockInitialValues({});
      final service = PushNotificationService();

      Object? uncaughtError;
      await runZonedGuarded(
        () async {
          await service.initialize();
          await service.requestPermission();
          await service.login('00000000-0000-0000-0000-000000000001');
          await service.setPushEnabled(false);
          final shown = await service.showStatusBarNotification(
            id: 'test-notif',
            title: 'Test',
            body: 'Body',
          );
          expect(shown, isFalse);
          await service.logout();
        },
        (error, stack) {
          uncaughtError = error;
        },
      );

      // Give microtasks a chance to surface any unawaited MethodChannel exceptions.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(uncaughtError, isNull);
    },
  );
}

