import 'dart:convert';
import '../utils/reminder_utils.dart';

class Reminder {
  final String id;
  final String userId;
  final String title;
  final String description;
  final String type;
  final String startTime;
  final String endTime;
  final String activeDateZone;
  final List<String> selectedDays;
  final String priority;
  final String category;

  // ── Notification ───────────────────────────────────────────────────────────
  final String notificationMode;  // 'voice' | 'ringtone'
  final String notificationSound; // always 'alarm'

  final int maxSnoozeCount;
  final int currentSnoozeCount;
  final int snoozeIntervalMinutes;
  final String status;
  final DateTime reminderTime;
  final bool completed;
  final DateTime createdAt;
  final DateTime updatedAt;

  final int repeatEveryMinutes;
  final int dayOfMonth;
  final bool lastDayOfMonth;

  // ── Counts ─────────────────────────────────────────────────────────────────
  final int fullCount;
  final int currentCount;
  final int balanceCount;

  // ── VM Status ──────────────────────────────────────────────────────────────
  final String vmStatus;

  Reminder({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.type,
    required this.startTime,
    required this.endTime,
    required this.activeDateZone,
    required this.selectedDays,
    required this.priority,
    required this.category,
    this.notificationMode  = ReminderNotificationMode.ringtone,
    this.notificationSound = ReminderSound.alarm,
    required this.maxSnoozeCount,
    required this.currentSnoozeCount,
    required this.snoozeIntervalMinutes,
    required this.status,
    required this.reminderTime,
    required this.completed,
    required this.createdAt,
    required this.updatedAt,
    this.repeatEveryMinutes = 60,
    this.dayOfMonth         = 1,
    this.lastDayOfMonth     = false,
    this.fullCount          = 1,
    this.currentCount       = 0,
    this.balanceCount       = 1,
    this.vmStatus           = VmStatus.notYetStarted,
  });

  // Convenience: derive vmStatus from counts
  static String deriveVmStatus(int current, int full, int balance) =>
      VmStatus.derive(current, full, balance);

  Reminder copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    String? type,
    String? startTime,
    String? endTime,
    String? activeDateZone,
    List<String>? selectedDays,
    String? priority,
    String? category,
    String? notificationMode,
    String? notificationSound,
    int? maxSnoozeCount,
    int? currentSnoozeCount,
    int? snoozeIntervalMinutes,
    String? status,
    DateTime? reminderTime,
    bool? completed,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? repeatEveryMinutes,
    int? dayOfMonth,
    bool? lastDayOfMonth,
    int? fullCount,
    int? currentCount,
    int? balanceCount,
    String? vmStatus,
  }) {
    return Reminder(
      id:                   id                   ?? this.id,
      userId:               userId               ?? this.userId,
      title:                title                ?? this.title,
      description:          description          ?? this.description,
      type:                 type                 ?? this.type,
      startTime:            startTime            ?? this.startTime,
      endTime:              endTime              ?? this.endTime,
      activeDateZone:       activeDateZone       ?? this.activeDateZone,
      selectedDays:         selectedDays         ?? List.from(this.selectedDays),
      priority:             priority             ?? this.priority,
      category:             category             ?? this.category,
      notificationMode:     notificationMode     ?? this.notificationMode,
      notificationSound:    notificationSound    ?? this.notificationSound,
      maxSnoozeCount:       maxSnoozeCount       ?? this.maxSnoozeCount,
      currentSnoozeCount:   currentSnoozeCount   ?? this.currentSnoozeCount,
      snoozeIntervalMinutes:snoozeIntervalMinutes?? this.snoozeIntervalMinutes,
      status:               status               ?? this.status,
      reminderTime:         reminderTime         ?? this.reminderTime,
      completed:            completed            ?? this.completed,
      createdAt:            createdAt            ?? this.createdAt,
      updatedAt:            updatedAt            ?? this.updatedAt,
      repeatEveryMinutes:   repeatEveryMinutes   ?? this.repeatEveryMinutes,
      dayOfMonth:           dayOfMonth           ?? this.dayOfMonth,
      lastDayOfMonth:       lastDayOfMonth       ?? this.lastDayOfMonth,
      fullCount:            fullCount            ?? this.fullCount,
      currentCount:         currentCount         ?? this.currentCount,
      balanceCount:         balanceCount         ?? this.balanceCount,
      vmStatus:             vmStatus             ?? this.vmStatus,
    );
  }

  factory Reminder.fromMap(Map<String, dynamic> m) {
    final selectedDaysRaw = m['selectedDays'];
    final List<String> selectedDays = selectedDaysRaw is String
        ? List<String>.from(jsonDecode(selectedDaysRaw) as List<dynamic>)
        : selectedDaysRaw is List
            ? List<String>.from(selectedDaysRaw)
            : <String>[];

    final rawStatus = m['status'] as String? ?? ReminderStatus.pending;
    var completedValue = false;
    final completedRaw = m['completed'];
    if (completedRaw is int) {
      completedValue = completedRaw == 1;
    } else if (completedRaw is bool) completedValue = completedRaw;
    if (!completedValue && rawStatus == ReminderStatus.completed) completedValue = true;

    String rawType = m['type'] as String? ?? ReminderType.daily;
    if (rawType == 'hourly') rawType = ReminderType.interval;

    final fullCount    = (m['fullCount']    as int?) ?? 1;
    final currentCount = (m['currentCount'] as int?) ?? 0;
    final balanceCount = (m['balanceCount'] as int?) ?? (fullCount - currentCount);
    final vmStatus     = m['vmStatus']      as String? ??
        VmStatus.derive(currentCount, fullCount, balanceCount);

    return Reminder(
      id:                   m['id']    as String,
      userId:               m['userId'] as String? ?? '',
      title:                m['title'] as String,
      description:          m['description']          as String? ?? '',
      type:                 rawType,
      startTime:            m['startTime']            as String? ?? '09:00',
      endTime:              m['endTime']              as String? ?? '18:00',
      activeDateZone:       m['activeDateZone']       as String? ?? ReminderActiveDateZone.daily,
      selectedDays:         selectedDays,
      priority:             m['priority']             as String? ?? ReminderPriority.medium,
      category:             m['category']             as String? ?? ReminderCategory.personal,
      notificationMode:     m['notificationMode']     as String? ?? ReminderNotificationMode.ringtone,
      notificationSound:    m['notificationSound']    as String? ?? ReminderSound.alarm,
      maxSnoozeCount:       (m['maxSnoozeCount']       as int?) ?? 3,
      currentSnoozeCount:   (m['currentSnoozeCount']   as int?) ?? 0,
      snoozeIntervalMinutes:(m['snoozeIntervalMinutes'] as int?) ?? 10,
      status:               rawStatus,
      reminderTime:         DateTime.parse(m['reminderTime'] as String),
      completed:            completedValue,
      createdAt:            DateTime.parse(m['createdAt'] as String),
      updatedAt:            m['updatedAt'] != null
          ? DateTime.parse(m['updatedAt'] as String)
          : DateTime.parse(m['createdAt'] as String),
      repeatEveryMinutes:   (m['repeatEveryMinutes'] as int?) ?? 60,
      dayOfMonth:           (m['dayOfMonth']         as int?) ?? 1,
      lastDayOfMonth:       m['lastDayOfMonth'] == true || m['lastDayOfMonth'] == 1,
      fullCount:            fullCount,
      currentCount:         currentCount,
      balanceCount:         balanceCount,
      vmStatus:             vmStatus,
    );
  }

  Map<String, dynamic> toMap() => {
    'id':                   id,
    'userId':               userId,
    'title':                title,
    'description':          description,
    'type':                 type,
    'startTime':            startTime,
    'endTime':              endTime,
    'activeDateZone':       activeDateZone,
    'selectedDays':         jsonEncode(selectedDays),
    'priority':             priority,
    'category':             category,
    'notificationMode':     notificationMode,
    'notificationSound':    notificationSound,
    'maxSnoozeCount':       maxSnoozeCount,
    'currentSnoozeCount':   currentSnoozeCount,
    'snoozeIntervalMinutes':snoozeIntervalMinutes,
    'status':               status,
    'reminderTime':         reminderTime.toIso8601String(),
    'completed':            completed ? 1 : 0,
    'createdAt':            createdAt.toIso8601String(),
    'updatedAt':            updatedAt.toIso8601String(),
    'repeatEveryMinutes':   repeatEveryMinutes,
    'dayOfMonth':           dayOfMonth,
    'lastDayOfMonth':       lastDayOfMonth ? 1 : 0,
    'fullCount':            fullCount,
    'currentCount':         currentCount,
    'balanceCount':         balanceCount,
    'vmStatus':             vmStatus,
  };

  Map<String, dynamic> toFirestore() => {
    'id':                   id,
    'userId':               userId,
    'title':                title,
    'description':          description,
    'type':                 type,
    'startTime':            startTime,
    'endTime':              endTime,
    'activeDateZone':       activeDateZone,
    'selectedDays':         selectedDays,
    'priority':             priority,
    'category':             category,
    'notificationMode':     notificationMode,
    'notificationSound':    notificationSound,
    'maxSnoozeCount':       maxSnoozeCount,
    'currentSnoozeCount':   currentSnoozeCount,
    'snoozeIntervalMinutes':snoozeIntervalMinutes,
    'status':               status,
    'reminderTime':         reminderTime.toIso8601String(),
    'completed':            completed,
    'createdAt':            createdAt.toIso8601String(),
    'updatedAt':            updatedAt.toIso8601String(),
    'repeatEveryMinutes':   repeatEveryMinutes,
    'dayOfMonth':           dayOfMonth,
    'lastDayOfMonth':       lastDayOfMonth,
    'fullCount':            fullCount,
    'currentCount':         currentCount,
    'balanceCount':         balanceCount,
    'vmStatus':             vmStatus,
  };
}