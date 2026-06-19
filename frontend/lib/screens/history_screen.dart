import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/reminder.dart';
import '../providers/auth_provider.dart';
import '../providers/reminder_provider.dart';
import '../widgets/reminder_card.dart';
import '../services/notification_service.dart';
import '../utils/reminder_utils.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String filter = 'today';

  @override
  Widget build(BuildContext context) {
    final prov      = Provider.of<ReminderProvider>(context);
    final now       = DateTime.now();
    final completed = prov.reminders.where((r) => r.completed).toList();

    List<Reminder> filtered = completed.where((r) {
      if (filter == 'today') {
        return r.updatedAt.day   == now.day &&
               r.updatedAt.month == now.month &&
               r.updatedAt.year  == now.year;
      }
      if (filter == 'week')  return now.difference(r.updatedAt).inDays <= 7;
      return now.difference(r.updatedAt).inDays <= 30;
    }).toList();

    // Sort newest first
    filtered.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () async {
              final auth      = Provider.of<AuthProvider>(context, listen: false);
              final reminders = Provider.of<ReminderProvider>(context, listen: false);
              final navigator = Navigator.of(context);
              await NotificationService().cancelAll();
              reminders.clear();
              await auth.signOut();
              if (!mounted) return;
              navigator.pushReplacementNamed('/');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Filter chips ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(children: [
              _filterChip('Today',      'today'),
              const SizedBox(width: 8),
              _filterChip('This Week',  'week'),
              const SizedBox(width: 8),
              _filterChip('This Month', 'month'),
            ]),
          ),

          // ── Summary row ────────────────────────────────────────────────
          if (filtered.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                _summaryChip('${filtered.length} completed',
                    Colors.green, Icons.check_circle_outline),
                const SizedBox(width: 8),
                _summaryChip(
                    '${filtered.where((r) => r.vmStatus == VmStatus.achievement).length} achievements',
                    Colors.purple,
                    Icons.emoji_events),
              ]),
            ),
          const SizedBox(height: 8),

          // ── List ───────────────────────────────────────────────────────
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.history, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text('No completed reminders yet',
                            style: TextStyle(color: Colors.grey.shade500)),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => ReminderCard(reminder: filtered[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final sel = filter == value;
    return GestureDetector(
      onTap: () => setState(() => filter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? const Color(0xFF5C6BC0) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: sel ? const Color(0xFF5C6BC0) : Colors.grey.shade300),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                color: sel ? Colors.white : Colors.black54)),
      ),
    );
  }

  Widget _summaryChip(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 12, color: color, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}