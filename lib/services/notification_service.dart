import 'dart:ui' show Color;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Thin wrapper so the controller can be tested with a fake.
abstract class Notifier {
  Future<void> init();
  Future<void> show(int id, String title, String body, {bool urgent = false});
}

class NotificationService implements Notifier {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  @override
  Future<void> init() async {
    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      await _plugin.initialize(const InitializationSettings(android: android));
      final impl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await impl?.requestNotificationsPermission();
      _ready = true;
    } catch (e) {
      debugPrint('Notification init failed: $e');
    }
  }

  @override
  Future<void> show(int id, String title, String body, {bool urgent = false}) async {
    if (!_ready) return;
    try {
      await _plugin.show(
        id,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            urgent ? 'smart_track_urgent' : 'smart_track_alerts',
            urgent ? 'Urgent plant alerts' : 'Plant alerts',
            channelDescription: 'Smart Track plant, tank, pump and weather alerts',
            importance: urgent ? Importance.max : Importance.high,
            priority: urgent ? Priority.max : Priority.high,
            color: const Color(0xFF22C55E),
          ),
        ),
      );
    } catch (e) {
      debugPrint('Notification failed: $e');
    }
  }
}
