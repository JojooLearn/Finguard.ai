import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../app/router/app_router.dart';
import '../config/app_config.dart';

/// Centralized Push & System Status Bar Notification Service.
/// Combines OneSignal remote push notifications with native Android
/// Status Bar & Heads-Up notifications via MethodChannel.
class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  static const MethodChannel _localChannel = MethodChannel(
    'com.finguard.app/local_notifications',
  );

  bool _initialized = false;
  bool _pushEnabled = true;
  String? _currentUserId;

  bool get isInitialized => _initialized;
  String? get currentUserId => _currentUserId;

  /// Initializes OneSignal SDK and binds native Android notification click listener.
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      _pushEnabled = prefs.getBool('push_notifications_enabled') ?? true;

      _localChannel.setMethodCallHandler((call) async {
        if (call.method == 'onNotificationTapped') {
          final args = call.arguments as Map?;
          final route = args?['route']?.toString();
          if (route != null && route.isNotEmpty) {
            handleNotificationNavigation({'screen': route});
          }
        }
      });

      if (kDebugMode) {
        OneSignal.Debug.setLogLevel(OSLogLevel.warn);
      }

      // 1. Initialize OneSignal SDK
      OneSignal.initialize(AppConfig.oneSignalAppId);

      // 2. Foreground notification display listener
      OneSignal.Notifications.addForegroundWillDisplayListener((event) {
        debugPrint('[OneSignal] Foreground notification received: ${event.notification.title}');
        event.notification.display();
      });

      // 3. Notification click listener (Deep Linking)
      OneSignal.Notifications.addClickListener((event) {
        debugPrint('[OneSignal] Notification clicked: ${event.notification.title}');
        final additionalData = event.notification.additionalData;
        if (additionalData != null) {
          handleNotificationNavigation(additionalData);
        }
      });

      _initialized = true;
      debugPrint('[OneSignal] Initialized with App ID: ${AppConfig.oneSignalAppId}');
    } catch (e) {
      debugPrint('[OneSignal] Initialization error: $e');
    }
  }

  /// Requests system notification permissions on Android 13+ (API 33+) & iOS.
  Future<bool> requestPermission() async {
    bool granted = false;
    try {
      final nativeGranted = await _localChannel.invokeMethod<bool>('requestPermission');
      if (nativeGranted == true) {
        granted = true;
      }
    } catch (_) {}

    try {
      final osGranted = await OneSignal.Notifications.requestPermission(true);
      granted = granted || osGranted;
      debugPrint('[OneSignal] Notification permission granted: $granted');
    } catch (e) {
      debugPrint('[OneSignal] Error requesting permission: $e');
    }
    return granted;
  }

  /// Posts a real system notification to the Android Status Bar & Heads-Up banner.
  Future<bool> showStatusBarNotification({
    required String id,
    required String title,
    required String body,
    String route = '/notifications',
  }) async {
    if (!_pushEnabled) return false;
    try {
      final intId = id.hashCode.abs() % 1000000;
      final shown = await _localChannel.invokeMethod<bool>('showNotification', {
        'id': intId,
        'title': title,
        'body': body,
        'route': route,
      });
      return shown ?? false;
    } catch (e) {
      debugPrint('[PushNotificationService] Native status bar error: $e');
      return false;
    }
  }

  /// Binds device to Supabase user UUID as OneSignal External ID.
  Future<void> login(String userId) async {
    if (userId.isEmpty) return;
    _currentUserId = userId;
    try {
      await OneSignal.login(userId);
      debugPrint('[OneSignal] User logged in with External ID: $userId');
    } catch (e) {
      debugPrint('[OneSignal] Login error: $e');
    }
  }

  /// Unbinds device on user logout to prevent notification cross-contamination.
  Future<void> logout() async {
    _currentUserId = null;
    try {
      await OneSignal.logout();
      debugPrint('[OneSignal] User logged out from OneSignal.');
    } catch (e) {
      debugPrint('[OneSignal] Logout error: $e');
    }
  }

  /// Toggles push subscription on or off.
  Future<void> setPushEnabled(bool enabled) async {
    _pushEnabled = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('push_notifications_enabled', enabled);
      if (enabled) {
        await OneSignal.User.pushSubscription.optIn();
      } else {
        await OneSignal.User.pushSubscription.optOut();
      }
      debugPrint('[OneSignal] Push subscription set to: $enabled');
    } catch (e) {
      debugPrint('[OneSignal] Subscription error: $e');
    }
  }

  /// Checks if push subscription is currently active.
  bool isPushOptedIn() {
    try {
      return OneSignal.User.pushSubscription.optedIn ?? _pushEnabled;
    } catch (_) {
      return _pushEnabled;
    }
  }

  /// Routes the user to the appropriate screen according to payload metadata.
  void handleNotificationNavigation(Map<dynamic, dynamic> data) {
    try {
      final rawScreen = (data['screen'] ?? data['target_screen'] ?? data['type'])
          ?.toString()
          .toLowerCase()
          .replaceAll('/', '');
      debugPrint('[OneSignal] Deep link navigation to: $rawScreen');

      switch (rawScreen) {
        case 'chat':
        case 'coach':
          appRouter.push('/coach');
          break;
        case 'budget':
          appRouter.push('/budget');
          break;
        case 'review':
        case 'monthly_review':
          appRouter.push('/review');
          break;
        case 'goals':
        case 'goal':
          appRouter.push('/goals');
          break;
        case 'transactions':
        case 'transaction':
          appRouter.push('/transactions');
          break;
        case 'blueprint':
          appRouter.push('/blueprint');
          break;
        default:
          appRouter.push('/notifications');
          break;
      }
    } catch (e) {
      debugPrint('[OneSignal] Navigation error: $e');
    }
  }
}
