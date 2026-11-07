import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app/app.dart';
import 'app/di/injection.dart';
import 'core/config/app_config.dart';
import 'core/services/push_notification_service.dart';
import 'features/auth/domain/repositories/auth_repository.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Indonesian locale date formatting for intl
  try {
    await initializeDateFormatting('id_ID', null);
  } catch (e) {
    debugPrint('Date formatting initialization info: $e');
  }

  // Set system UI style (transparent status bar, dark icons for light theme)
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Initialize Supabase Client
  try {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      // ignore: deprecated_member_use
      anonKey: AppConfig.supabaseAnonKey,
    );
  } catch (e) {
    debugPrint('Supabase initialization info: $e');
  }

  // Initialize Service Locator dependencies
  await initDependencies();

  // Initialize OneSignal Push Notification Service
  try {
    final pushService = sl<PushNotificationService>();
    await pushService.initialize();

    // If user is already authenticated, bind external ID
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser != null) {
      await pushService.login(currentUser.id);
    }
  } catch (e) {
    debugPrint('OneSignal push service bootstrap error: $e');
  }

  // If user is already authenticated from Supabase local session, pre-load onboarding status
  try {
    if (sl.isRegistered<AuthRepository>()) {
      await sl<AuthRepository>().loadOnboardingStatus();
    }
  } catch (e) {
    debugPrint('Preload onboarding status error: $e');
  }

  runApp(const FinGuardApp());
}
