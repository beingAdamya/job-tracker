import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  // Set the plugin up once per isolate (the app and the background worker
  // each have their own)
  static Future<void> init() async {
    if (_ready) return;
    const android = AndroidInitializationSettings('@drawable/ic_notification');
    await _plugin.initialize(
      settings: const InitializationSettings(android: android),
    );
    _ready = true;
  }

  // Android 13+ asks the user for permission. true = allowed.
  static Future<bool> requestPermission() async {
    try {
      await init();
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await android?.requestNotificationsPermission() ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> show({
    required int id,
    required String title,
    required String body,
  }) async {
    await init();

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'new_jobs',                       // channel id
        'New jobs',                       // channel name (shown in phone settings)
        channelDescription: 'Alerts about newly listed jobs',
        importance: Importance.high,
        priority: Priority.high,
        styleInformation: BigTextStyleInformation(body), // allows several lines
      ),
    );

    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }
}