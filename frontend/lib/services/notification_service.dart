import 'dart:developer';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() => _instance;

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel androidChannel = AndroidNotificationChannel(
    'buybeacon_channel_id',
    'buybeacon_reminders',
    description: 'Notifications for product reminders near stores',
    importance: Importance.max,
    playSound: true,
  );

  Future<void> initialize({
    void Function(NotificationResponse response)? onNotificationTap,
    required List<AndroidNotificationChannel> channels,
  }) async {
    final androidPlugin = _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    for (final channel in channels) {
      await androidPlugin?.createNotificationChannel(channel);
    }

    log('Creating android notification channel...', name: 'NotificationService');
    await _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    log('[NotificationService] Initializing...', name: 'NotificationService');
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings();

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    try {
      await _localNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse:
            onNotificationTap ??
            (NotificationResponse response) async {
              log(
                'Notification tapped: ${response.payload}',
                name: 'NotificationService',
              );
            },
      );
      log(
        '[NotificationService] FlutterLocalNotificationsPlugin initialized successfully.',
        name: 'NotificationService',
      );
    } catch (e) {
      log(
        '[NotificationService] ERROR initializing FlutterLocalNotificationsPlugin: $e',
        name: 'NotificationService',
        error: e,
      );
    }
    log('NotificationService initialized.', name: 'NotificationService');
  }

  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    log(
      '[NotificationService] showNotification called. Title: "$title", Body: "$body", Payload: "$payload"',
      name: 'NotificationService',
    );
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'buybeacon_reminders_channel_id',
      'Nearby Store Reminders',
      channelDescription: 'Notifications for product reminders near stores',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );
    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    try {
      await _localNotificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch % 2147483647,
        title,
        body,
        notificationDetails,
        payload: payload,
      );
      log(
        '[NotificationService] Notification SHOWN successfully (or at least attempted). Title: "$title"',
        name: 'NotificationService',
      );
    } catch (e) {
      log(
        '[NotificationService] ERROR showing notification. Title: "$title", Error: $e',
        name: 'NotificationService',
        error: e,
      );
    }
    log('Showing notification $title', name: 'NotificationService');
  }
}
