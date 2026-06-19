import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/reminder.dart';
import '../services/sqlite_service.dart';
import '../services/firebase_service.dart';
import '../services/connectivity_service.dart';
import '../utils/reminder_utils.dart';

class ReminderRepository {
  final SQLiteService _sqlite = SQLiteService();
  final FirebaseService _firebase = FirebaseService();
  final ConnectivityService _connectivity = ConnectivityService();

  Future<List<Reminder>> getAll() async {
    final online = await _connectivity.isOnline();
    final user = _firebase.currentUser;
    if (user == null) return [];

    final localReminders = await _sqlite.getAllReminders(userId: user.uid);

    if (online) {
      try {
        final cloudReminders = await _firebase.fetchAllReminders();
        final localById = {for (var item in localReminders) item.id: item};
        final cloudById = {for (var item in cloudReminders) item.id: item};

        for (final remote in cloudReminders) {
          final local = localById[remote.id];
          if (local == null) {
            await _sqlite.upsertReminder(remote);
            continue;
          }
          if (remote.updatedAt.isAfter(local.updatedAt)) {
            await _sqlite.upsertReminder(remote);
          } else if (local.updatedAt.isAfter(remote.updatedAt)) {
            await _firebase.upsertReminder(local);
          }
        }

        for (final local in localReminders) {
          if (!cloudById.containsKey(local.id)) {
            await _firebase.upsertReminder(local);
          }
        }

        return await _sqlite.getAllReminders(userId: user.uid);
      } catch (_) {
        return localReminders;
      }
    }

    return localReminders;
  }

  Future<void> addOrUpdate(Reminder r) async {
    await _sqlite.upsertReminder(r);
    final online = await _connectivity.isOnline();
    if (online && _firebase.currentUser != null) {
      try {
        await _firebase.upsertReminder(r);
      } catch (e) {
        debugPrint('Firebase upsert failed for ${r.id}: $e');
      }
    }
  }

  Future<void> delete(String id) async {
    await _sqlite.deleteReminder(id);
    final online = await _connectivity.isOnline();
    if (online && _firebase.currentUser != null) {
      try {
        await _firebase.deleteReminder(id);
      } catch (e) {
        debugPrint('Firebase delete failed for $id: $e');
      }
    }
  }

  Future<void> syncOnReconnect() async {
    final online = await _connectivity.isOnline();
    final user = _firebase.currentUser;
    if (!online || user == null) return;

    final local  = await _sqlite.getAllReminders(userId: user.uid);
    final remote = await _firebase.fetchAllReminders();
    final remoteById = {for (var item in remote) item.id: item};

    for (final localEntry in local) {
      final remoteEntry = remoteById[localEntry.id];
      if (remoteEntry == null) {
        await _firebase.upsertReminder(localEntry);
      } else if (localEntry.updatedAt.isAfter(remoteEntry.updatedAt)) {
        await _firebase.upsertReminder(localEntry);
      }
    }

    for (final remoteEntry in remote) {
      final localEntry = local.firstWhere(
        (item) => item.id == remoteEntry.id,
        orElse: () => remoteEntry,
      );
      if (remoteEntry.updatedAt.isAfter(localEntry.updatedAt)) {
        await _sqlite.upsertReminder(remoteEntry);
      }
    }
  }

  Reminder createDraft({
    required String title,
    String description = '',
    required String type,
    required DateTime reminderTime,
  }) {
    final id  = DateTime.now().microsecondsSinceEpoch.toString();
    final now = DateTime.now();
    return Reminder(
      id:                   id,
      userId:               _firebase.currentUser?.uid ?? '',
      title:                title,
      description:          description,
      type:                 type,
      startTime:            '09:00',
      endTime:              '18:00',
      activeDateZone:       ReminderActiveDateZone.daily,
      selectedDays:         [],
      priority:             ReminderPriority.medium,
      category:             ReminderCategory.personal,
      notificationMode:     ReminderNotificationMode.ringtone, // default
      notificationSound:    ReminderSound.alarm,               // always alarm
      maxSnoozeCount:       3,
      currentSnoozeCount:   0,
      snoozeIntervalMinutes:10,
      status:               ReminderStatus.pending,
      reminderTime:         reminderTime,
      completed:            false,
      createdAt:            now,
      updatedAt:            now,
    );
  }
}