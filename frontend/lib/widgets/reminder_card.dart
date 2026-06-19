import 'package:flutter/material.dart';
import '../models/reminder.dart';
import '../utils/reminder_utils.dart';

class ReminderCard extends StatelessWidget {
  final Reminder reminder;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const ReminderCard({
    super.key,
    required this.reminder,
    this.onTap,
    this.onDelete,
  });

  String get _typeLabel => ReminderType.label(reminder.type);

  String get _timeLabel {
    final local  = reminder.reminderTime.toLocal();
    final hour   = local.hour == 0 ? 12 : local.hour > 12 ? local.hour - 12 : local.hour;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final vmColor  = VmStatus.color(reminder.vmStatus);
    final vmIcon   = VmStatus.icon(reminder.vmStatus);
    final vmLabel  = VmStatus.label(reminder.vmStatus);
    final isVmShown = reminder.vmStatus != VmStatus.notYetStarted;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Leading icon ──────────────────────────────────────────────
              CircleAvatar(
                radius: 24,
                backgroundColor: vmColor.withValues(alpha: 0.15),
                child: Icon(vmIcon, color: vmColor, size: 22),
              ),
              const SizedBox(width: 12),

              // ── Title + subtitle + vm badge ───────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(reminder.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text('$_typeLabel • $_timeLabel',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600)),
                    // Counts row — always show for interval, show if started for others
                    if (reminder.fullCount > 1 || reminder.currentCount > 0) ...[
                      const SizedBox(height: 4),
                      Row(children: [
                        _countChip('Full',    reminder.fullCount,    Colors.indigo),
                        const SizedBox(width: 6),
                        _countChip('Done',    reminder.currentCount, Colors.green),
                        const SizedBox(width: 6),
                        _countChip('Left',    reminder.balanceCount, Colors.orange),
                      ]),
                    ],
                    // VM status badge
                    if (isVmShown) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: vmColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: vmColor.withValues(alpha: 0.35)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(vmIcon, size: 11, color: vmColor),
                            const SizedBox(width: 4),
                            Text(vmLabel,
                                style: TextStyle(
                                    fontSize: 10,
                                    color: vmColor,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // ── Trailing status ───────────────────────────────────────────
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Notification mode icon
                  Icon(
                    ReminderNotificationMode.icon(reminder.notificationMode),
                    size: 14,
                    color: Colors.grey.shade500,
                  ),
                  const SizedBox(height: 6),
                  Icon(
                    _statusIcon(reminder.status),
                    color: _statusColor(reminder.status),
                    size: 22,
                  ),
                  const SizedBox(height: 2),
                  Text(ReminderStatus.label(reminder.status),
                      style: const TextStyle(fontSize: 9)),
                ],
              ),
              if (onDelete != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    color: Colors.red.shade400,
                    size: 20,
                  ),
                  onPressed: () => _showDeleteConfirmDialog(context),
                  tooltip: 'Delete reminder',
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red.shade400),
              const SizedBox(width: 8),
              const Text('Delete Reminder'),
            ],
          ),
          content: Text(
            'Are you sure you want to delete "${reminder.title}"? This action cannot be undone.',
            style: const TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                onDelete?.call();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Widget _countChip(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('$label: $value',
          style: TextStyle(
              fontSize: 10, color: color, fontWeight: FontWeight.w600)),
    );
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case ReminderStatus.completed: return Icons.check_circle;
      case ReminderStatus.snoozed:   return Icons.snooze;
      case ReminderStatus.missed:    return Icons.error_outline;
      default:                       return Icons.radio_button_unchecked;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case ReminderStatus.completed: return Colors.green;
      case ReminderStatus.snoozed:   return Colors.orange;
      case ReminderStatus.missed:    return Colors.red;
      default:                       return Colors.grey.shade600;
    }
  }
}