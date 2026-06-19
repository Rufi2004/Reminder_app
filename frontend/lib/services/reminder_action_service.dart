import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import '../models/reminder.dart';
import '../repositories/reminder_repository.dart';
import '../services/connectivity_service.dart';
import '../services/firebase_service.dart';
import '../services/notification_service.dart';
import '../services/tts_service.dart';
import '../services/reminder_service.dart';
import '../utils/reminder_utils.dart';

/// Executes reminder actions without requiring a [BuildContext] / Provider.
/// Used by notification taps (foreground, background, and cold start).
class ReminderActionService {
  static final ReminderActionService _instance =
      ReminderActionService._internal();
  factory ReminderActionService() => _instance;
  ReminderActionService._internal();
  final ReminderRepository _repo = ReminderRepository();
  final NotificationService _notif = NotificationService();
  final FirebaseService _firebase = FirebaseService();
  final TtsService _tts = TtsService();
  final ReminderService _reminderService = ReminderService();
  final ConnectivityService _connectivity = ConnectivityService();

  final Map<String, Timer> _resetTimers = {};

  /// Called after any DB/Firebase update so [ReminderProvider] can refresh UI.
  void Function(Reminder reminder)? onReminderChanged;

  void _emit(Reminder reminder) => onReminderChanged?.call(reminder);

  /// Parses `"ACTION|reminderId"` payloads from notification callbacks.
  static ({String action, String id})? parsePayload(String raw) {
    final parts = raw.split('|');
    if (parts.length < 2) return null;
    final id = parts[1].trim();
    if (id.isEmpty) return null;
    return (action: parts[0].trim(), id: id);
  }

  Future<Reminder?> _findReminder(String id) async {
    await _firebase.init();
    if (_firebase.currentUser == null) return null;
    final all = await _repo.getAll();
    for (final r in all) {
      if (r.id == id) return r;
    }
    return null;
  }

  void _syncVmStatusWithBackend(Reminder reminder) {
  Future(() async {
    try {
      final user = _firebase.currentUser;

      if (user == null) {
        debugPrint('[NOTIF] No authenticated user found');
        return;
      }

      final success = await _reminderService.syncVmStatus(
        userId: user.uid,
        reminderId: reminder.id,
        vmStatus: reminder.vmStatus,
      );

      if (success) {
        debugPrint(
          '[NOTIF] VM Status synced successfully '
          '(${reminder.id} -> ${reminder.vmStatus})',
        );
      } else {
        debugPrint(
          '[NOTIF] VM Status sync failed '
          '(${reminder.id} -> ${reminder.vmStatus})',
        );
      }
    } catch (e) {
      debugPrint('[NOTIF] VM sync error: $e');
    }
  });
}

  int _calculateFullCount(Reminder reminder) {
    if (reminder.type == ReminderType.interval) {
      final startParts = reminder.startTime.split(':');
      final endParts = reminder.endTime.split(':');
      final startMinutes =
          int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
      final endMinutes = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);
      final windowMinutes = endMinutes - startMinutes;
      if (windowMinutes <= 0 || reminder.repeatEveryMinutes <= 0) return 1;
      return (windowMinutes / reminder.repeatEveryMinutes).floor() + 1;
    }
    return 1;
  }

  DateTime _parseTimeOfDay(DateTime base, String rawTime) {
    final parts = rawTime.split(':');
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    return DateTime(base.year, base.month, base.day, hour, minute);
  }

  bool _isDayAllowed(Reminder reminder, DateTime date) {
    return ReminderActiveDateZone.isDayAllowed(
        reminder.activeDateZone, reminder.selectedDays, date);
  }

  DateTime _nextAllowedDayAtStartTime(Reminder reminder, DateTime from) {
    var candidate = _parseTimeOfDay(from, reminder.startTime);
    while (!_isDayAllowed(reminder, candidate)) {
      candidate = candidate.add(const Duration(days: 1));
      candidate = _parseTimeOfDay(candidate, reminder.startTime);
    }
    return candidate;
  }

  DateTime _nextReminderTime(Reminder reminder, DateTime from) {
    if (reminder.type == ReminderType.interval) {
      final start = _parseTimeOfDay(from, reminder.startTime);
      final end = _parseTimeOfDay(from, reminder.endTime);
      final intervalMinutes =
          reminder.repeatEveryMinutes > 0 ? reminder.repeatEveryMinutes : 60;
      DateTime candidate;
      if (from.isBefore(start)) {
        candidate = start;
      } else {
        final diffMinutes = from.difference(start).inMinutes;
        final ticks = (diffMinutes ~/ intervalMinutes) + 1;
        candidate = start.add(Duration(minutes: ticks * intervalMinutes));
      }
      if (candidate.isAfter(end) || !_isDayAllowed(reminder, candidate)) {
        final nextDay = from.add(const Duration(days: 1));
        candidate = _nextAllowedDayAtStartTime(reminder, nextDay);
      }
      return candidate;
    }

    if (reminder.type == ReminderType.daily) {
      var candidate = _parseTimeOfDay(from, _dailyTriggerTime(reminder));
      if (!candidate.isAfter(from)) {
        candidate = candidate.add(const Duration(days: 1));
      }
      while (!_isDayAllowed(reminder, candidate)) {
        candidate = candidate.add(const Duration(days: 1));
      }
      return candidate;
    }

    final baseDay = reminder.lastDayOfMonth
        ? -1
        : reminder.dayOfMonth > 0
            ? reminder.dayOfMonth
            : reminder.reminderTime.day;
    var month = from.month;
    var year = from.year;

    DateTime buildCandidate(int y, int m) {
      final lastDay = DateTime(y, m + 1, 0).day;
      final day = (baseDay == -1) ? lastDay : min(baseDay, lastDay);
      final trigger = _dailyTriggerTime(reminder);
      final parts = trigger.split(':');
      return DateTime(y, m, day, int.parse(parts[0]), int.parse(parts[1]));
    }

    DateTime candidate = buildCandidate(year, month);
    if (!candidate.isAfter(from)) {
      month += 1;
      if (month > 12) {
        month = 1;
        year += 1;
      }
      candidate = buildCandidate(year, month);
    }
    while (!_isDayAllowed(reminder, candidate)) {
      month += 1;
      if (month > 12) {
        month = 1;
        year += 1;
      }
      candidate = buildCandidate(year, month);
    }
    return candidate;
  }

  String _dailyTriggerTime(Reminder reminder) {
    final h = reminder.reminderTime.hour.toString().padLeft(2, '0');
    final m = reminder.reminderTime.minute.toString().padLeft(2, '0');
    final picked = '$h:$m';
    if (ReminderTimeValidation.isWithinWindow(
        picked, reminder.startTime, reminder.endTime)) {
      return picked;
    }
    return reminder.startTime;
  }

  DateTime _resetTime(Reminder reminder) {
    final now = DateTime.now();
    switch (reminder.type) {
      case ReminderType.daily:
        return DateTime(now.year, now.month, now.day + 1, 0, 0, 0);
      case ReminderType.interval:
        final minutes =
            reminder.repeatEveryMinutes > 0 ? reminder.repeatEveryMinutes : 60;
        return now.add(Duration(minutes: minutes));
      case ReminderType.monthly:
        final next = _nextReminderTime(reminder, now);
        return DateTime(next.year, next.month, next.day, 0, 0, 0);
      default:
        return DateTime(now.year, now.month, now.day + 1, 0, 0, 0);
    }
  }

  void scheduleResetTimer(Reminder reminder, void Function(Reminder) onReset) {
    _resetTimers[reminder.id]?.cancel();
    final resetAt = _resetTime(reminder);
    final delay = resetAt.difference(DateTime.now());
    if (delay.isNegative) {
      onReset(reminder);
      return;
    }
    _resetTimers[reminder.id] = Timer(delay, () => onReset(reminder));
  }

  Future<Reminder?> completeById(String id) async {
    final reminder = await _findReminder(id);
    if (reminder == null) return null;

    await _notif.cancelById(id);

    final isRecurring = reminder.type == ReminderType.daily ||
        reminder.type == ReminderType.interval ||
        reminder.type == ReminderType.monthly;

    final newCurrentCount = reminder.currentCount + 1;
    final newBalanceCount =
        (reminder.fullCount - newCurrentCount).clamp(0, reminder.fullCount);

    final updated = reminder.copyWith(
      status: ReminderStatus.completed,
      completed: true,
      updatedAt: DateTime.now(),
      currentCount: newCurrentCount,
      balanceCount: newBalanceCount,
      vmStatus: Reminder.deriveVmStatus(
          newCurrentCount, reminder.fullCount, newBalanceCount),
    );

    await _repo.addOrUpdate(updated);
    _syncVmStatusWithBackend(updated);
    _emit(updated);

    if (isRecurring) {
      scheduleResetTimer(updated, (_) async {
        final reset = await resetRecurringById(id);
        if (reset != null) _emit(reset);
      });
    }

    return updated;
  }

  Future<Reminder?> snoozeById(String id) async {
    final reminder = await _findReminder(id);
    if (reminder == null) return null;

    final nextSnoozeCount = reminder.currentSnoozeCount + 1;
    if (nextSnoozeCount >= reminder.maxSnoozeCount) {
      final missed = reminder.copyWith(
        status: ReminderStatus.missed,
        updatedAt: DateTime.now(),
      );
      await _repo.addOrUpdate(missed);
      await _notif.cancelById(id);
      _syncVmStatusWithBackend(missed);
      _emit(missed);
      return missed;
    }

    await _notif.cancelById(id);

    final snoozedAt =
        DateTime.now().add(Duration(minutes: reminder.snoozeIntervalMinutes));
    final updated = reminder.copyWith(
      status: ReminderStatus.snoozed,
      currentSnoozeCount: nextSnoozeCount,
      reminderTime: snoozedAt,
      updatedAt: DateTime.now(),
    );
    await _repo.addOrUpdate(updated);
    await _notif.scheduleReminder(
      reminder: updated,
      scheduledDate: snoozedAt,
      payload: updated.id,
    );
    await _tts.init();
    await _tts
        .speak('Reminder snoozed for ${updated.snoozeIntervalMinutes} minutes.');
    _syncVmStatusWithBackend(updated);
    _emit(updated);
    return updated;
  }

  Future<Reminder?> stopById(String id) async {
    final reminder = await _findReminder(id);
    if (reminder == null) return null;

    await _notif.cancelById(id);

    Reminder updated = reminder;
    if (reminder.status == ReminderStatus.snoozed) {
      updated = reminder.copyWith(
        status: ReminderStatus.pending,
        updatedAt: DateTime.now(),
      );
      await _repo.addOrUpdate(updated);
      _syncVmStatusWithBackend(updated);
      _emit(updated);
    }

    return updated;
  }

  Future<Reminder?> resetRecurringById(String id) async {
    final reminder = await _findReminder(id);
    if (reminder == null) return null;
    if (reminder.status != ReminderStatus.completed) return reminder;

    final now = DateTime.now();
    final nextTime = _nextReminderTime(reminder, now);
    final full = _calculateFullCount(reminder);
    final reset = reminder.copyWith(
      status: ReminderStatus.pending,
      completed: false,
      currentSnoozeCount: 0,
      reminderTime: nextTime,
      updatedAt: now,
      currentCount: 0,
      balanceCount: full,
      fullCount: full,
      vmStatus: Reminder.deriveVmStatus(0, full, full),
    );
    await _repo.addOrUpdate(reset);
    await _notif.scheduleReminder(
      reminder: reset,
      scheduledDate: nextTime,
      payload: reset.id,
    );
    _resetTimers.remove(id);
    _syncVmStatusWithBackend(reset);
    return reset;
  }

  /// Runs a notification action end-to-end. Returns `false` when auth is not ready.
  Future<bool> executePayload(String rawPayload) async {
    final parsed = parsePayload(rawPayload);
    if (parsed == null) return true;

    await _firebase.init();
    if (_firebase.currentUser == null) {
      debugPrint('[NOTIF] Auth not ready — deferring $rawPayload');
      return false;
    }

    Reminder? result;
    switch (parsed.action) {
      case 'COMPLETE_ACTION':
        result = await completeById(parsed.id);
        break;
      case 'SNOOZE_ACTION':
        result = await snoozeById(parsed.id);
        break;
      case 'STOP_ACTION':
        result = await stopById(parsed.id);
        break;
      case 'OPEN_ACTION':
        debugPrint('[NOTIF] Open action for ${parsed.id}');
        final opened = await _findReminder(parsed.id);
        if (opened != null) {
          await _reminderService.handleReminderNotification(opened);
        }
        break;
      default:
        debugPrint('[NOTIF] Unknown action ${parsed.action}');
    }

    if (result != null) {
      debugPrint('[NOTIF] Action ${parsed.action} applied to ${result.title}');
    }
    return true;
  }

  Future<bool> get isOnline => _connectivity.isOnline();
}
