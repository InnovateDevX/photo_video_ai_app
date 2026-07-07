import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:trail_ai_app/Services/local_storage_service.dart';
import 'package:trail_ai_app/pages/ai_result_screen.dart';
import 'package:trail_ai_app/repositories/user_repository.dart';
import 'package:trail_ai_app/Core/user_session.dart';
import 'package:firebase_core/firebase_core.dart';

/// Top-level background message handler for FCM.
/// Must be outside of any class.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("📩 [FCM] Handling background message: ${message.messageId}");
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  FirebaseMessaging get _fcm => FirebaseMessaging.instance;

  bool _isInitialized = false;

  /// Global key used for navigation when a notification is tapped
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  Future<void> initialize() async {
    if (_isInitialized) return;

    // Request permissions for Android 13+
    if (Platform.isAndroid) {
      await Permission.notification.request();
    }

    // FCM Permissions
    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );

    await _notificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        _onNotificationTapped(response.payload);
      },
    );

    // Create a high importance channel for Android 8+
    if (Platform.isAndroid) {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'ai_generation_channel',
        'AI Generations',
        description:
            'Notifications for completed AI video and image generations',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );

      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(channel);

      // Create a background progress channel
      const AndroidNotificationChannel progressChannel =
          AndroidNotificationChannel(
            'ai_background_progress',
            'AI Background Tasks',
            description: 'Ongoing progress of AI generations',
            importance: Importance.low,
            playSound: false,
            enableVibration: false,
            showBadge: false,
          );

      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(progressChannel);
    }

    // Listen for FCM messages when app is in foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint(
        '📩 [FCM] Foreground message received: ${message.notification?.title}',
      );
      if (message.notification != null) {
        showGenerationCompleteNotification(
          title: message.notification!.title ?? 'Trail AI Studio',
          body: message.notification!.body ?? 'Generation complete!',
          payload: message.data['url'],
        );
      }
    });

    // Handle FCM notification when app is opened from background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('📩 [FCM] App opened from background notification');
      _onNotificationTapped(message.data['url']);
    });

    // Set background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Initial Token Sync (will fail if UID isn't ready, but that's okay,
    // AppInitializer will call syncTokenNow() later).
    syncTokenNow();

    // Listen for Token Refresh
    _fcm.onTokenRefresh.listen((newToken) {
      syncTokenNow(newToken: newToken);
    });

    _isInitialized = true;
  }

  /// Public method to sync the FCM token to Firestore.
  /// Usually called after user authentication is complete.
  Future<void> syncTokenNow({String? newToken}) async {
    final uid = UserSession.instance.uid;
    if (uid == null) {
      debugPrint('📩 [FCM] Skipping token sync: UserSession.uid is null');
      return;
    }

    try {
      final token = newToken ?? await _fcm.getToken();
      if (token != null) {
        debugPrint('📩 [FCM] Syncing token to Firestore for uid: $uid');
        await UserRepository().updateFcmToken(uid, token);
      }
    } catch (e) {
      debugPrint('📩 [FCM] Token sync failed: $e');
    }
  }

  void _onNotificationTapped(String? payload) {
    debugPrint(
      '🔔 [NotificationService] Notification tapped! Payload: $payload',
    );
    if (payload == null) return;

    if (payload == 'OPEN_APP') {
      // Just bring the app to foreground (handled by navigatorKey being global)
      navigatorKey.currentState?.popUntil((route) => route.isFirst);
      return;
    }

    try {
      final assets = LocalStorageService().assetsNotifier.value;
      final asset = assets.firstWhere((a) => a.id == payload);
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (routeContext) => Scaffold(
            backgroundColor:
                Theme.of(routeContext).brightness == Brightness.dark
                ? const Color(0xFF15181C)
                : Colors.white,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: Icon(
                  Icons.arrow_back_ios_new,
                  color: Theme.of(routeContext).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black,
                ),
                onPressed: () => Navigator.pop(routeContext),
              ),
              title: Text(
                'Result',
                style: TextStyle(
                  color: Theme.of(routeContext).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black,
                ),
              ),
            ),
            body: SafeArea(
              child: AIResultScreen(resultImageUrl: asset.filePath),
            ),
          ),
        ),
      );
    } catch (e) {
      debugPrint('🔔 [NotificationService] Asset ID not found locally: $e');
    }
  }

  Future<void> showGenerationCompleteNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_isInitialized) await initialize();

    // Use a more unique ID to avoid collisions (lower 31 bits of epoch)
    final int notificationId = DateTime.now().millisecondsSinceEpoch.remainder(
      1000000,
    );

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'ai_generation_channel',
          'AI Generations',
          channelDescription: 'Notifications for completed AI generations',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          color: const Color(0xFFF16E14), // App Primary Orange
          playSound: true,
          enableVibration: true,
          styleInformation: BigTextStyleInformation(
            body,
            contentTitle: title,
            summaryText: 'Trail AI Studio',
          ),
        );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      id: notificationId,
      title: title,
      body: body,
      notificationDetails: platformChannelSpecifics,
      payload: payload,
    );
  }

  /// Shows a notification with a progress bar.
  /// Used for ongoing background tasks like AI generations.
  Future<void> showProgressNotification({
    required int id,
    required String title,
    required String body,
    int? progress,
    int maxProgress = 100,
    String? payload,
  }) async {
    if (!_isInitialized) await initialize();

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'ai_background_progress',
          'AI Background Tasks',
          channelDescription: 'Ongoing progress of AI generations',
          importance: Importance.low,
          priority: Priority.low,
          onlyAlertOnce: true,
          showProgress: true,
          maxProgress: maxProgress,
          progress: progress ?? 0,
          indeterminate: progress == null,
          ongoing: true,
          autoCancel: false,
          color: const Color(0xFFF16E14),
          icon: '@mipmap/ic_launcher',
          showWhen: true,
          usesChronometer: true, // Shows how long the task has been running
          subText: progress != null ? '$progress%' : 'Starting...',
        );

    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(presentAlert: true),
    );

    await _notificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: platformChannelSpecifics,
      payload: payload,
    );
  }

  /// Cancels a specific notification by ID.
  Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id: id);
  }

  Future<String?> getDeviceToken() async {
    return await _fcm.getToken();
  }
}
