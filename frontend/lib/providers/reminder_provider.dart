import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import '../models/reminder.dart';
import '../repositories/reminder_repository.dart';
import '../services/notification_service.dart';
import '../services/connectivity_service.dart';
import '../services/tts_service.dart';
import '../utils/reminder_utils.dart';
import '../services/reminder_service.dart';
import '../services/reminder_action_service.dart';

class ReminderProvider extends ChangeNotifier {
  final ReminderRepository _repo = ReminderRepository();
  final NotificationService _notif = NotificationService();
  final ConnectivityService _connectivity = ConnectivityService();
  final TtsService _tts = TtsService();
  final ReminderService _reminderService = ReminderService();
  final ReminderActionService _actions = ReminderActionService();
  Stream<bool>? _connSub;

  final Map<String, Timer> _resetTimers = {};

  List<Reminder> _reminders = [];
  List<Reminder> get reminders => _reminders;

  /// Keeps in-memory list in sync when [ReminderActionService] updates data.
  void applyReminderUpdate(Reminder reminder) {
    final idx = _reminders.indexWhere((e) => e.id == reminder.id);
    if (idx >= 0) {
      _reminders[idx] = reminder;
    } else {
      _reminders.add(reminder);
    }
    notifyListeners();
  }

  Future<void> refreshFromRepository() async {
    _reminders = await _repo.getAll();
    notifyListeners();
  }

  Future<void> loadAll() async {
    _reminders = [];
    notifyListeners();
    await _tts.init();
    _reminders = await _repo.getAll();
    _connSub = _connectivity.onConnectivityChanged;
    _connSub?.listen((online) async {
      if (online) await _repo.syncOnReconnect();
    });
    await _resetOverdueCompletedReminders();
    await _schedulePendingReminders();
    _rearmAllResetTimers();
    _reminderService.armAllPendingTriggers(_reminders);
    notifyListeners();
  }

  void _syncVmStatusWithBackend(Reminder reminder) {
  Future(() async {
    try {
      final userId = reminder.userId;

      if (userId.isEmpty) {
        debugPrint('Cannot sync VM status: userId is empty');
        return;
      }

      final success = await _reminderService.syncVmStatus(
        userId: userId,
        reminderId: reminder.id,
        vmStatus: reminder.vmStatus,
      );

      if (success) {
        debugPrint(
          'VM Status synced successfully '
          '(${reminder.id} -> ${reminder.vmStatus})',
        );
      } else {
        debugPrint(
          'VM Status sync failed '
          '(${reminder.id} -> ${reminder.vmStatus})',
        );
      }
    } catch (e) {
      debugPrint('Error syncing VM status to backend: $e');
    }
  });
}

  Future<void> add(Reminder r) async {
    final validationError = ReminderTimeValidation.validateReminderTime(
      type: r.type,
      reminderTime: r.reminderTime,
      startTime: r.startTime,
      endTime: r.endTime,
    );
    if (validationError != null) {
      throw Exception(validationError);
    }

    final now = DateTime.now();
    final scheduled = _nextReminderTime(r, now);
    final full = _calculateFullCount(r);
    final reminder = r.copyWith(
      reminderTime: scheduled,
      status: ReminderStatus.pending,
      currentSnoozeCount: 0,
      completed: false,
      createdAt: now,
      updatedAt: now,
      fullCount: full,
      currentCount: 0,
      balanceCount: full,
      vmStatus: Reminder.deriveVmStatus(0, full, full),
    );
    await _repo.addOrUpdate(reminder);
    _reminders.removeWhere((e) => e.id == reminder.id);
    _reminders.add(reminder);
    await _notif.scheduleReminder(
        reminder: reminder, scheduledDate: scheduled, payload: reminder.id);
    _syncVmStatusWithBackend(reminder);
    notifyListeners();
  }

  Future<void> clear() async {
    for (final t in _resetTimers.values) {
      t.cancel();
    }
    _resetTimers.clear();
    _reminders = [];
    notifyListeners();
  }

  Future<void> updateReminder(Reminder reminder) async {
    final validationError = ReminderTimeValidation.validateReminderTime(
      type: reminder.type,
      reminderTime: reminder.reminderTime,
      startTime: reminder.startTime,
      endTime: reminder.endTime,
    );
    if (validationError != null) {
      throw Exception(validationError);
    }

    final updated = reminder.copyWith(
      updatedAt: DateTime.now(),
      vmStatus: Reminder.deriveVmStatus(
          reminder.currentCount, reminder.fullCount, reminder.balanceCount),
    );
    await _repo.addOrUpdate(updated);
    final idx = _reminders.indexWhere((e) => e.id == updated.id);
    if (idx >= 0) {
      _reminders[idx] = updated;
    } else {
      _reminders.add(updated);
    }
    await _notif.scheduleReminder(
        reminder: updated,
        scheduledDate: updated.reminderTime,
        payload: updated.id);
    _syncVmStatusWithBackend(updated);
    notifyListeners();
  }

  Future<void> completeReminderById(String id) async {
    final updated = await _actions.completeById(id);
    if (updated != null) applyReminderUpdate(updated);
  }

  Future<void> snoozeReminderById(String id) async {
    final updated = await _actions.snoozeById(id);
    if (updated != null) applyReminderUpdate(updated);
  }

  Future<void> stopReminderById(String id) async {
    final updated = await _actions.stopById(id);
    if (updated != null) applyReminderUpdate(updated);
  }

  Future<void> deleteReminder(String id) async {
    await _notif.cancelById(id);
    _resetTimers[id]?.cancel();
    _resetTimers.remove(id);
    await _repo.delete(id);
    _reminders.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  Reminder createDraft({
    required String title,
    String description = '',
    required String type,
    required DateTime reminderTime,
  }) {
    return _repo.createDraft(
        title: title,
        description: description,
        type: type,
        reminderTime: reminderTime);
  }

  int _calculateFullCount(Reminder reminder) {
    if (reminder.type == ReminderType.interval) {
      final startParts = reminder.startTime.split(':');
      final endParts = reminder.endTime.split(':');
      final startMinutes =
          int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
      final endMinutes =
          int.parse(endParts[0]) * 60 + int.parse(endParts[1]);
      final windowMinutes = endMinutes - startMinutes;
      if (windowMinutes <= 0 || reminder.repeatEveryMinutes <= 0) return 1;
      return (windowMinutes / reminder.repeatEveryMinutes).floor() + 1;
    }
    return 1;
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

  void _scheduleResetTimer(Reminder reminder) {
    _resetTimers[reminder.id]?.cancel();
    final resetAt = _resetTime(reminder);
    final delay = resetAt.difference(DateTime.now());
    if (delay.isNegative) {
      _resetReminder(reminder.id);
      return;
    }
    _resetTimers[reminder.id] = Timer(delay, () {
      _resetReminder(reminder.id);
    });
  }

  Future<void> _resetReminder(String id) async {
    final reset = await _actions.resetRecurringById(id);
    if (reset != null) applyReminderUpdate(reset);
    _resetTimers.remove(id);
  }

  Future<void> _resetOverdueCompletedReminders() async {
    final now = DateTime.now();
    for (int i = 0; i < _reminders.length; i++) {
      final reminder = _reminders[i];
      final isRecurring = reminder.type == ReminderType.daily ||
          reminder.type == ReminderType.interval ||
          reminder.type == ReminderType.monthly;
      if (!isRecurring) continue;
      if (reminder.status != ReminderStatus.completed) continue;

      final resetAt = _resetTime(reminder);
      if (resetAt.isBefore(now)) {
        final reset = await _actions.resetRecurringById(reminder.id);
        if (reset != null) _reminders[i] = reset;
      }
    }
  }

  void _rearmAllResetTimers() {
    for (final reminder in _reminders) {
      final isRecurring = reminder.type == ReminderType.daily ||
          reminder.type == ReminderType.interval ||
          reminder.type == ReminderType.monthly;
      if (!isRecurring) continue;
      if (reminder.status != ReminderStatus.completed) continue;
      _scheduleResetTimer(reminder);
    }
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
      return DateTime(
          y, m, day, int.parse(parts[0]), int.parse(parts[1]));
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

  Future<void> _schedulePendingReminders() async {
    final now = DateTime.now();
    for (final reminder in _reminders) {
      if (reminder.status == ReminderStatus.pending ||
          reminder.status == ReminderStatus.snoozed) {
        final target = _nextReminderTime(reminder, now);
        if (target.isAfter(now)) {
          final updated = reminder.copyWith(
              reminderTime: target, updatedAt: DateTime.now());
          await _repo.addOrUpdate(updated);
          final index = _reminders.indexWhere((e) => e.id == reminder.id);
          if (index >= 0) _reminders[index] = updated;
          await _notif.scheduleReminder(
              reminder: updated, scheduledDate: target, payload: updated.id);
        }
      }
    }
  }
}
