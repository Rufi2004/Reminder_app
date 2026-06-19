import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences key used to defer notification actions until auth is ready.
const String kPendingNotificationActionKey = 'pending_notification_action';

/// Top-level background handler required by flutter_local_notifications.
/// Must stay public (not private) so release builds do not tree-shake it.
@pragma('vm:entry-point')
void notificationBackgroundTapHandler(NotificationResponse response) async {
  try {
    final actionId = response.actionId ?? 'OPEN_ACTION';
    final payload = response.payload ?? '';
    debugPrint('[NOTIF] BG handler: $actionId | $payload');
    if (payload.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kPendingNotificationActionKey, '$actionId|$payload');
  } catch (e) {
    debugPrint('[NOTIF] BG handler error: $e');
  }
}
