import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../models/reminder_model.dart';
import '../repositories/reminder_repository.dart';
import '../utils/reminder_utils.dart';
import 'api_service.dart';

/// Business logic for reminder notifications and backend voice workflow.
class ReminderService {
  static final ReminderService _instance = ReminderService._internal();
  factory ReminderService() => _instance;
  ReminderService._internal();

  final ApiService _api = ApiService();
  final AudioPlayer _player = AudioPlayer();
  final ReminderRepository _repo = ReminderRepository();

  final Map<String, Timer> _fireTimers = {};
  final Map<String, DateTime> _lastHandledAt = {};

  /// POST /sync-vm-status/
  Future<bool> syncVmStatus({
    required String userId,
    required String reminderId,
    required String vmStatus,
  }) {
    return _api.syncVmStatus(
      userId: userId,
      reminderId: reminderId,
      vmStatus: vmStatus,
    );
  }

  /// GET /generate-audio/{userId}/{reminderId}/
  Future<Map<String, dynamic>?> generateAudio({
    required String userId,
    required String reminderId,
  }) {
    return _api.generateAudio(userId: userId, reminderId: reminderId);
  }

  /// Ringtone mode — plays local asset; backend is not called.
  Future<void> playRingtoneNotification(Reminder reminder) async {
    try {
      await _player.stop();
      final sound = reminder.notificationSound.isNotEmpty
          ? reminder.notificationSound
          : ReminderSound.alarm;
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.play(AssetSource('sounds/$sound.mp3'));
      debugPrint('[Reminder] Playing ringtone: $sound');
    } catch (e) {
      debugPrint('[Reminder] Ringtone playback failed: $e');
    }
  }

  /// Voice mode — sync vmStatus, generate mp3, then stream/play it.
  Future<void> playVoiceNotification(Reminder reminder) async {
    final userId = reminder.userId;
    if (userId.isEmpty) {
      debugPrint('[Reminder] Voice mode skipped: userId is empty');
      return;
    }

    final vmStatus = Reminder.deriveVmStatus(
      reminder.currentCount,
      reminder.fullCount,
      reminder.balanceCount,
    );
    final withStatus = reminder.copyWith(vmStatus: vmStatus);

    final synced = await syncVmStatus(
      userId: userId,
      reminderId: reminder.id,
      vmStatus: withStatus.vmStatus,
    );
    if (!synced) {
      debugPrint('[Reminder] Voice mode aborted: vmStatus sync failed');
      return;
    }

    final result = await generateAudio(
      userId: userId,
      reminderId: reminder.id,
    );
    if (result == null || result['success'] != true) {
      debugPrint('[Reminder] Voice mode aborted: generate-audio failed');
      return;
    }

    final audioUrl = result['audioUrl'] as String?;
    if (audioUrl == null || audioUrl.isEmpty) {
      debugPrint('[Reminder] Voice mode aborted: audioUrl missing');
      return;
    }

    try {
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.stop);
      final resolvedUrl = _api.resolveAudioUrl(audioUrl);
      await _player.play(UrlSource(resolvedUrl));
      debugPrint('[Reminder] Playing generated voice from $resolvedUrl');
    } catch (e) {
      debugPrint('[Reminder] Voice playback failed: $e');
    }
  }

  /// Entry point when a reminder fires at its scheduled time.
  Future<void> handleReminderNotification(Reminder reminder) async {
    if (!_shouldHandle(reminder.id)) {
      debugPrint('[Reminder] Already handled recently: ${reminder.id}');
      return;
    }

    debugPrint(
      '[Reminder] Fired "${reminder.title}" '
      'mode=${reminder.notificationMode}',
    );

    if (reminder.notificationMode == ReminderNotificationMode.ringtone) {
      await playRingtoneNotification(reminder);
      return;
    }

    await playVoiceNotification(reminder);
  }

  /// Arms a one-shot timer so [handleReminderNotification] runs at [scheduledDate].
  void armReminderTrigger(Reminder reminder, DateTime scheduledDate) {
    disarmReminderTrigger(reminder.id);

    final delay = scheduledDate.difference(DateTime.now());
    if (delay.isNegative) {
      unawaited(_fireReminder(reminder));
      return;
    }

    _fireTimers[reminder.id] = Timer(delay, () {
      unawaited(_fireReminder(reminder));
    });

    debugPrint(
      '[Reminder] Armed trigger for ${reminder.title} at $scheduledDate',
    );
  }

  void disarmReminderTrigger(String reminderId) {
    _fireTimers.remove(reminderId)?.cancel();
  }

  void disarmAllTriggers() {
    for (final timer in _fireTimers.values) {
      timer.cancel();
    }
    _fireTimers.clear();
  }

  /// Re-arm timers for pending/snoozed reminders (call after login / app start).
  void armAllPendingTriggers(List<Reminder> reminders) {
    final now = DateTime.now();
    for (final reminder in reminders) {
      if (reminder.status != ReminderStatus.pending &&
          reminder.status != ReminderStatus.snoozed) {
        continue;
      }
      if (reminder.reminderTime.isAfter(now)) {
        armReminderTrigger(reminder, reminder.reminderTime);
      }
    }
  }

  /// Catches reminders that fired while the app was suspended or killed.
  Future<void> checkMissedReminders(List<Reminder> reminders) async {
    final now = DateTime.now();
    for (final reminder in reminders) {
      if (reminder.status != ReminderStatus.pending &&
          reminder.status != ReminderStatus.snoozed) {
        continue;
      }

      final delta = now.difference(reminder.reminderTime);
      if (delta.isNegative) continue;
      if (delta > const Duration(minutes: 5)) continue;

      await handleReminderNotification(reminder);
    }
  }

  Future<void> stopAudio() async {
    await _player.stop();
  }

  Future<void> _fireReminder(Reminder reminder) async {
    final latest = await _loadLatestReminder(reminder.id) ?? reminder;
    await handleReminderNotification(latest);
  }

  Future<Reminder?> _loadLatestReminder(String id) async {
    try {
      final all = await _repo.getAll();
      for (final item in all) {
        if (item.id == id) return item;
      }
    } catch (e) {
      debugPrint('[Reminder] Failed to reload reminder $id: $e');
    }
    return null;
  }

  bool _shouldHandle(String reminderId) {
    final last = _lastHandledAt[reminderId];
    if (last != null &&
        DateTime.now().difference(last) < const Duration(minutes: 2)) {
      return false;
    }
    _lastHandledAt[reminderId] = DateTime.now();
    return true;
  }
}
