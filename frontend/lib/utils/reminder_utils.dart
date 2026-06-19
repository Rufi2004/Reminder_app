import 'package:flutter/material.dart';

class ReminderType {
  static const interval = 'interval';
  static const daily = 'daily';
  static const monthly = 'monthly';

  static const values = [interval, daily, monthly];

  static String label(String type) {
    switch (type) {
      case interval: return 'Interval';
      case daily:    return 'Daily';
      case monthly:  return 'Monthly';
      default:       return 'Reminder';
    }
  }
}

class ReminderStatus {
  static const pending   = 'pending';
  static const completed = 'completed';
  static const snoozed   = 'snoozed';
  static const missed    = 'missed';

  static const values = [pending, completed, snoozed, missed];

  static String label(String status) {
    switch (status) {
      case completed: return 'Completed';
      case snoozed:   return 'Snoozed';
      case missed:    return 'Missed';
      default:        return 'Pending';
    }
  }
}

class ReminderPriority {
  static const low    = 'low';
  static const medium = 'medium';
  static const high   = 'high';

  static const values = [low, medium, high];

  static String label(String p) {
    switch (p) {
      case low:    return 'Low';
      case medium: return 'Medium';
      case high:   return 'High';
      default:     return 'Medium';
    }
  }

  static Color color(String p) {
    switch (p) {
      case low:    return Colors.green;
      case medium: return Colors.orange;
      case high:   return Colors.red;
      default:     return Colors.orange;
    }
  }
}

class ReminderCategory {
  static const health   = 'Health';
  static const work     = 'Work';
  static const personal = 'Personal';
  static const study    = 'Study';
  static const finance  = 'Finance';
  static const custom   = 'Custom';

  static const values = [health, work, personal, study, finance, custom];

  static IconData icon(String c) {
    switch (c) {
      case health:   return Icons.health_and_safety;
      case work:     return Icons.work;
      case personal: return Icons.person;
      case study:    return Icons.school;
      case finance:  return Icons.attach_money;
      default:       return Icons.category;
    }
  }

  static String label(String c) => values.contains(c) ? c : custom;

  static Color color(String c) {
    switch (c) {
      case health:   return Colors.teal;
      case work:     return Colors.indigo;
      case personal: return Colors.purple;
      case study:    return Colors.blue;
      case finance:  return Colors.green;
      default:       return Colors.grey;
    }
  }
}

// ── Notification mode ──────────────────────────────────────────────────────
class ReminderNotificationMode {
  static const voice    = 'voice';
  static const ringtone = 'ringtone';

  static const values = [voice, ringtone];

  static String label(String mode) {
    switch (mode) {
      case voice:    return 'Voice';
      case ringtone: return 'Ringtone';
      default:       return 'Ringtone';
    }
  }

  static IconData icon(String mode) {
    switch (mode) {
      case voice:    return Icons.record_voice_over;
      case ringtone: return Icons.notifications_active;
      default:       return Icons.notifications_active;
    }
  }
}

// ── Notification sound ─────────────────────────────────────────────────────
class ReminderSound {
  static const alarm     = 'alarm';
  static const values    = [alarm];

  static String label(String s) => 'Alarm';
}

// ── VM Status ──────────────────────────────────────────────────────────────
class VmStatus {
  static const notYetStarted  = 'not yet started';
  static const notStartedUrgent = 'not started urgent';
  static const inProgress     = 'in progress';
  static const slowProgress   = 'slow progress';
  static const nearCompletion = 'near completion';
  static const completed      = 'completed';
  static const achievement    = 'achievement';

  static const values = [
    notYetStarted,
    notStartedUrgent,
    inProgress,
    slowProgress,
    nearCompletion,
    completed,
    achievement,
  ];

  static String label(String s) {
    switch (s) {
      case notYetStarted:    return 'Not Yet Started';
      case notStartedUrgent: return 'Not Started (Urgent)';
      case inProgress:       return 'In Progress';
      case slowProgress:     return 'Slow Progress';
      case nearCompletion:   return 'Near Completion';
      case completed:        return 'Completed';
      case achievement:      return 'Achievement!';
      default:               return 'Not Yet Started';
    }
  }

  static Color color(String s) {
    switch (s) {
      case notYetStarted:    return Colors.grey;
      case notStartedUrgent: return Colors.red.shade400;
      case inProgress:       return Colors.blue;
      case slowProgress:     return Colors.orange;
      case nearCompletion:   return Colors.teal;
      case completed:        return Colors.green;
      case achievement:      return Colors.purple;
      default:               return Colors.grey;
    }
  }

  static IconData icon(String s) {
    switch (s) {
      case notYetStarted:    return Icons.radio_button_unchecked;
      case notStartedUrgent: return Icons.warning_amber_rounded;
      case inProgress:       return Icons.pending_outlined;
      case slowProgress:     return Icons.trending_down;
      case nearCompletion:   return Icons.flag_outlined;
      case completed:        return Icons.check_circle_outline;
      case achievement:      return Icons.emoji_events;
      default:               return Icons.radio_button_unchecked;
    }
  }

  // Derive vmStatus from counts
  // fullCount=1 (daily/monthly): simple completed or not
  // fullCount>1 (interval): ratio-based
  static String derive(int current, int full, int balance) {
    if (full <= 0) return notYetStarted;
    if (current <= 0) {
      // Nothing done yet — check if balance is critically low (urgent)
      return notYetStarted;
    }
    if (current >= full) {
      // All done — achievement if finished faster than expected
      return balance == 0 ? achievement : completed;
    }
    final ratio = current / full;
    if (ratio < 0.25) return inProgress;
    if (ratio < 0.5)  return slowProgress;
    if (ratio < 0.85) return inProgress;
    return nearCompletion;
  }
}

// ── Active date zone ───────────────────────────────────────────────────────
class ReminderActiveDateZone {
  static const daily    = 'daily';
  static const weekdays = 'weekdays';
  static const weekends = 'weekends';
  static const custom   = 'custom';

  static const values = [daily, weekdays, weekends, custom];

  static String label(String z) {
    switch (z) {
      case weekdays: return 'Weekdays';
      case weekends: return 'Weekends';
      case custom:   return 'Custom';
      default:       return 'Daily';
    }
  }

  static bool isDayAllowed(
      String zone, List<String> selectedDays, DateTime day) {
    switch (zone) {
      case weekdays:
        return day.weekday >= DateTime.monday &&
            day.weekday <= DateTime.friday;
      case weekends:
        return day.weekday == DateTime.saturday ||
            day.weekday == DateTime.sunday;
      case custom:
        return selectedDays.contains(_weekdayName(day.weekday));
      default:
        return true;
    }
  }

  static List<String> availableDays = [
    'Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday',
  ];

  static String _weekdayName(int weekday) => availableDays[weekday - 1];
}

String formatTimeHHmm(String rawTime) {
  try {
    final parts = rawTime.split(':');
    final hour   = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    final period = hour >= 12 ? 'PM' : 'AM';
    final h = hour == 0 ? 12 : hour > 12 ? hour - 12 : hour;
    return '$h:${minute.toString().padLeft(2, '0')} $period';
  } catch (_) {
    return rawTime;
  }
}

DateTime parseTimeOfDay(DateTime baseDate, String rawTime) {
  final parts  = rawTime.split(':');
  final hour   = int.parse(parts[0]);
  final minute = int.parse(parts[1]);
  return DateTime(baseDate.year, baseDate.month, baseDate.day, hour, minute);
}

/// Validates reminder times against the configured active window (HH:mm strings).
class ReminderTimeValidation {
  static int _toMinutes(String rawTime) {
    final parts = rawTime.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  static bool isEndAfterStart(String startTime, String endTime) {
    return _toMinutes(endTime) > _toMinutes(startTime);
  }

  static bool isWithinWindow(String time, String startTime, String endTime) {
    if (!isEndAfterStart(startTime, endTime)) return false;
    final t = _toMinutes(time);
    final start = _toMinutes(startTime);
    final end = _toMinutes(endTime);
    return t >= start && t <= end;
  }

  static bool isDateTimeWithinWindow(
      DateTime dateTime, String startTime, String endTime) {
    final hh = dateTime.hour.toString().padLeft(2, '0');
    final mm = dateTime.minute.toString().padLeft(2, '0');
    return isWithinWindow('$hh:$mm', startTime, endTime);
  }

  static String? validateReminderTime({
    required String type,
    required DateTime reminderTime,
    required String startTime,
    required String endTime,
  }) {
    if (!isEndAfterStart(startTime, endTime)) {
      return 'End time must be after start time.';
    }
    if (type == ReminderType.interval) {
      return null;
    }
    if (type == ReminderType.daily || type == ReminderType.monthly) {
      if (!isDateTimeWithinWindow(reminderTime, startTime, endTime)) {
        return 'Reminder time must be between ${formatTimeHHmm(startTime)} and ${formatTimeHHmm(endTime)}.';
      }
    }
    return null;
  }
}