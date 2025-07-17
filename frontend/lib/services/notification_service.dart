import 'dart:developer';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService{
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async{
    const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings();

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid,
                                iOS: initializationSettingsIOS);

    await _localNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) async{
          log('Notification tapped: ${response.payload}', name: 'NotificationService');
        });
    log('NotificationService initialized.', name: 'NotificationService');
  }

  Future<void> showNotification ({
    required String title,
    required String body,
    String? payload
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'buybeacon_channel_id',
        'buybeacon_reminders',
         channelDescription: 'Notifications for product reminders near stores',
         importance: Importance.max,
        priority: Priority.high
    );
    const NotificationDetails notificationDetails =
          NotificationDetails(android: androidDetails);

    await _localNotificationsPlugin.show(
      0,
      title,
      body,
      notificationDetails,
      payload: payload
    );
    log('Showing notification $title', name: 'NotificationService');
  }
}