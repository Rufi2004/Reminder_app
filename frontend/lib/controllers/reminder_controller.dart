import 'package:flutter/foundation.dart';

import '../models/reminder_model.dart';
import '../services/api_service.dart';
import '../services/reminder_service.dart';

/// Controller layer — UI and providers call this, not [ApiService] directly.
class ReminderController extends ChangeNotifier {
  final ReminderService _service = ReminderService();

  Future<void> handleReminderNotification(Reminder reminder) {
    return _service.handleReminderNotification(reminder);
  }

  Future<bool> syncVmStatus({
    required String userId,
    required String reminderId,
    required String vmStatus,
  }) {
    return _service.syncVmStatus(
      userId: userId,
      reminderId: reminderId,
      vmStatus: vmStatus,
    );
  }

  Future<Map<String, dynamic>?> generateAudio({
    required String userId,
    required String reminderId,
  }) {
    return _service.generateAudio(userId: userId, reminderId: reminderId);
  }

  Future<void> playVoiceNotification(Reminder reminder) {
    return _service.playVoiceNotification(reminder);
  }

  Future<void> playRingtoneNotification(Reminder reminder) {
    return _service.playRingtoneNotification(reminder);
  }

  void armReminderTrigger(Reminder reminder, DateTime scheduledDate) {
    _service.armReminderTrigger(reminder, scheduledDate);
  }

  void disarmReminderTrigger(String reminderId) {
    _service.disarmReminderTrigger(reminderId);
  }

  void armAllPendingTriggers(List<Reminder> reminders) {
    _service.armAllPendingTriggers(reminders);
  }

  Future<void> checkMissedReminders(List<Reminder> reminders) {
    return _service.checkMissedReminders(reminders);
  }

  Future<void> stopAudio() {
    return _service.stopAudio();
  }

  Future<bool> checkBackendConnection() {
    return ApiService().checkHome();
  }
}
