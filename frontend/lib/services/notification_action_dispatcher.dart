import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_background_handler.dart';
import 'reminder_action_service.dart';

/// Processes a deferred notification action after Firebase auth is ready.
Future<void> processPendingNotificationAction({
  required ReminderActionService actionService,
  Future<void> Function()? onUiRefresh,
  void Function(String reminderId)? onOpenDetails,
}) async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString(kPendingNotificationActionKey);
  if (saved == null || saved.isEmpty) return;

  await prefs.remove(kPendingNotificationActionKey);
  debugPrint('[NOTIF] Processing pending: $saved');

  final handled = await actionService.executePayload(saved);
  if (!handled) {
    await prefs.setString(kPendingNotificationActionKey, saved);
    return;
  }

  await onUiRefresh?.call();

  final parsed = ReminderActionService.parsePayload(saved);
  if (parsed?.action == 'OPEN_ACTION') {
    onOpenDetails?.call(parsed!.id);
  }
}
