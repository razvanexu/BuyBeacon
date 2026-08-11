import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationChannelService {
  static const AndroidNotificationChannel androidReminderChannel =
      AndroidNotificationChannel(
        'buybeacon_reminders_channel_id',
        'Nearby Stores Reminder',
        description: 'Notifications for product reminders near stores',
        importance: Importance.max,
        playSound: true,
      );

  static const AndroidNotificationChannel
  androidForegroundServiceChannel = AndroidNotificationChannel(
    'buybeacon_service_channel_id',
    'Background Service Status',
    description:
        'Persistent notification required by Android for background location tracking.',
    importance: Importance.low,
    playSound: false,
  );

  List<AndroidNotificationChannel> get notificationChannels => [
    androidReminderChannel,
    androidForegroundServiceChannel,
  ];
}
