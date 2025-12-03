import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    // Request permissions
    await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // On iOS/macOS allow showing notifications when app is in foreground
    await _firebaseMessaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Initialize local notifications for Android/iOS foreground display
    final AndroidInitializationSettings androidSettings =
      const AndroidInitializationSettings('@mipmap/ic_launcher');

    final DarwinInitializationSettings iosSettings =
      const DarwinInitializationSettings();

    final InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(initSettings);

    // Create a channel for Android (required for Android 8+)
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel', // id
      'High Importance Notifications', // title
      description: 'This channel is used for important notifications.',
      importance: Importance.high,
    );

    await _localNotifications
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showForegroundNotification(message);
    });

    // Optional: handle messages opened from a terminated state
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        if (kDebugMode) print('Initial message: ${message.messageId}');
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      if (kDebugMode) print('Message opened app: ${message.messageId}');
    });
  }

  static Future<void> _showForegroundNotification(RemoteMessage message) async {
    // Prefer the platform notification payload, but fall back to data payload
    final String? title = message.notification?.title ?? message.data['title'];
    final String? body = message.notification?.body ?? message.data['body'];

    if (title == null && body == null) return;

    final androidDetails = AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',
      channelDescription: 'This channel is used for important notifications.',
      importance: Importance.high,
      priority: Priority.high,
    );

    final platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(),
    );

    await _localNotifications.show(
      title.hashCode ^ (body?.hashCode ?? 0),
      title,
      body,
      platformDetails,
      payload: message.data.isNotEmpty ? message.data.toString() : null,
    );
  }

  // Get FCM Token for testing
  static Future<String?> getToken() async {
    final token = await _firebaseMessaging.getToken();
    if (kDebugMode) print('FCM Token: $token');
    return token;
  }
}