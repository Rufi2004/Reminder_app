// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/reminder.dart';
import '../providers/auth_provider.dart';
import '../providers/reminder_provider.dart';
import '../services/notification_service.dart';
import '../utils/reminder_utils.dart';

class ReminderDetailsScreen extends StatelessWidget {
  const ReminderDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final arg  = ModalRoute.of(context)!.settings.arguments;
    final prov = Provider.of<ReminderProvider>(context);

    final Reminder reminder;
    if (arg is Reminder) {
      reminder = arg;
    } else if (arg is String) {
      final matches = prov.reminders.where((e) => e.id == arg).toList();
      if (matches.isNotEmpty) {
        reminder = matches.first;
      } else {
        return Scaffold(
            body: Center(
                child: Text('Reminder not found',
                    style: Theme.of(context).textTheme.titleMedium)));
      }
    } else {
      return Scaffold(
          body: Center(
              child: Text('Reminder not found',
                  style: Theme.of(context).textTheme.titleMedium)));
    }

    final navigator = Navigator.of(context);
    final vmColor   = VmStatus.color(reminder.vmStatus);

    return Scaffold(
      appBar: AppBar(
        title: Text(reminder.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () async {
              final auth      = Provider.of<AuthProvider>(context, listen: false);
              final reminders = Provider.of<ReminderProvider>(context, listen: false);
              final nav       = Navigator.of(context);
              await NotificationService().cancelAll();
              reminders.clear();
              await auth.signOut();
              if (context.mounted) nav.pushReplacementNamed('/');
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Description
          Text(
            reminder.description.isEmpty
                ? 'No description provided.'
                : reminder.description,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),

          // ── Status chips ─────────────────────────────────────────────────
          Wrap(spacing: 8, runSpacing: 8, children: [
            Chip(label: Text(ReminderType.label(reminder.type))),
            Chip(
              label: Text(reminder.category),
              backgroundColor:
                  ReminderCategory.color(reminder.category).withValues(alpha: 0.15),
            ),
            Chip(
              label: Text(ReminderStatus.label(reminder.status)),
              backgroundColor: Colors.grey.shade200,
            ),
            // Notification mode chip
            Chip(
              avatar: Icon(
                  ReminderNotificationMode.icon(reminder.notificationMode),
                  size: 16),
              label:
                  Text(ReminderNotificationMode.label(reminder.notificationMode)),
              backgroundColor: Colors.indigo.shade50,
            ),
          ]),
          const SizedBox(height: 16),

          // ── VM Status banner ─────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: vmColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: vmColor.withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              Icon(VmStatus.icon(reminder.vmStatus), color: vmColor, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('VM Status',
                      style: TextStyle(
                          fontSize: 11,
                          color: vmColor,
                          fontWeight: FontWeight.w600)),
                  Text(VmStatus.label(reminder.vmStatus),
                      style: TextStyle(
                          fontSize: 16,
                          color: vmColor,
                          fontWeight: FontWeight.bold)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 16),

          // ── Count cards ──────────────────────────────────────────────────
          Row(children: [
            Expanded(
                child: _countCard('Full Count', reminder.fullCount,
                    Colors.indigo, Icons.format_list_numbered)),
            const SizedBox(width: 10),
            Expanded(
                child: _countCard('Completed', reminder.currentCount,
                    Colors.green, Icons.check_circle_outline)),
            const SizedBox(width: 10),
            Expanded(
                child: _countCard('Balance', reminder.balanceCount,
                    Colors.orange, Icons.pending_outlined)),
          ]),
          const SizedBox(height: 16),

          // ── Detail items ─────────────────────────────────────────────────
          _buildDetailItem(context, 'Next alert',
              reminder.reminderTime.toLocal().toString()),
          _buildDetailItem(context, 'Active window',
              '${formatTimeHHmm(reminder.startTime)} — ${formatTimeHHmm(reminder.endTime)}'),
          _buildDetailItem(context, 'Active zone',
              ReminderActiveDateZone.label(reminder.activeDateZone)),
          if (reminder.activeDateZone == ReminderActiveDateZone.custom)
            _buildDetailItem(
                context, 'Days', reminder.selectedDays.join(', ')),
          _buildDetailItem(
              context, 'Max snooze', reminder.maxSnoozeCount.toString()),
          _buildDetailItem(context, 'Snoozed so far',
              reminder.currentSnoozeCount.toString()),
          const SizedBox(height: 24),

          // ── Action buttons ───────────────────────────────────────────────
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Mark completed'),
                onPressed: reminder.status == ReminderStatus.completed
                    ? null
                    : () async {
                        await prov.completeReminderById(reminder.id);
                        if (context.mounted) navigator.pop();
                      },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                icon: const Icon(Icons.snooze),
                label: const Text('Snooze'),
                onPressed: reminder.status == ReminderStatus.missed ||
                        reminder.currentSnoozeCount >= reminder.maxSnoozeCount
                    ? null
                    : () async {
                        await prov.snoozeReminderById(reminder.id);
                        if (context.mounted) navigator.pop();
                      },
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _countCard(String label, int value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 6),
        Text('$value',
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.8)),
            textAlign: TextAlign.center),
      ]),
    );
  }

  Widget _buildDetailItem(BuildContext context, String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.bodyMedium),
      ]),
    );
  }
}