import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/reminder_controller.dart';
import '../providers/auth_provider.dart';
import '../providers/reminder_provider.dart';
import '../services/api_service.dart';
import '../services/firebase_service.dart';
import '../services/notification_service.dart';
import '../services/tts_service.dart';
import '../utils/reminder_utils.dart';
import '../models/reminder.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final TtsService _tts = TtsService();
  final ReminderController _reminderController = ReminderController();
  bool _isLoading = true;
  bool _testingBackend = false;
  bool _testingRingtone = false;
  bool _testingVoice = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final provider = Provider.of<ReminderProvider>(context, listen: false);
    await _tts.init();
    await provider.loadAll();
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  String _formatTime(DateTime value) {
    final hour = value.hour == 0 ? 12 : value.hour > 12 ? value.hour - 12 : value.hour;
    final minute = value.minute.toString().padLeft(2, '0');
    final period = value.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  String _typeLabel(String type) {
    return ReminderType.label(type);
  }

  int _calculateStreak(List<Reminder> reminders) {
    final today = DateTime.now();
    var streak = 0;
    for (var offset = 0; offset < 7; offset++) {
      final day = DateTime(today.year, today.month, today.day)
          .subtract(Duration(days: offset));
      final completed = reminders.where((r) {
        final due = DateTime(
            r.reminderTime.year, r.reminderTime.month, r.reminderTime.day);
        return due == day && r.status == ReminderStatus.completed;
      }).isNotEmpty;
      if (completed) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  double _completionRate(int complete, int total) =>
      total == 0 ? 0 : (complete / total) * 100;

  void _showSnack(String message, {bool success = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? Colors.green.shade700 : Colors.red.shade700,
      ),
    );
  }

  Future<void> _testBackend() async {
    setState(() => _testingBackend = true);
    try {
      final ok = await _reminderController.checkBackendConnection();
      _showSnack(
        ok
            ? 'Backend reachable at ${ApiService.baseUrl}'
            : 'Backend unreachable at ${ApiService.baseUrl}',
        success: ok,
      );
    } finally {
      if (mounted) setState(() => _testingBackend = false);
    }
  }

  Reminder _sampleRingtoneReminder(String userId) {
    final now = DateTime.now();
    return Reminder(
      id: 'test-ringtone',
      userId: userId,
      title: 'Ringtone test',
      description: 'Dashboard test',
      type: ReminderType.daily,
      startTime: '09:00',
      endTime: '18:00',
      activeDateZone: ReminderActiveDateZone.daily,
      selectedDays: const [],
      priority: ReminderPriority.medium,
      category: ReminderCategory.personal,
      notificationMode: ReminderNotificationMode.ringtone,
      notificationSound: ReminderSound.alarm,
      maxSnoozeCount: 3,
      currentSnoozeCount: 0,
      snoozeIntervalMinutes: 10,
      status: ReminderStatus.pending,
      reminderTime: now,
      completed: false,
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<void> _testRingtone() async {
    final userId = FirebaseService().currentUser?.uid ?? '';
    setState(() => _testingRingtone = true);
    try {
      await _reminderController
          .playRingtoneNotification(_sampleRingtoneReminder(userId));
      _showSnack('Playing ringtone from assets/sounds/alarm.mp3');
    } catch (e) {
      _showSnack('Ringtone test failed: $e', success: false);
    } finally {
      if (mounted) setState(() => _testingRingtone = false);
    }
  }

  Future<void> _testVoice(List<Reminder> reminders) async {
    final userId = FirebaseService().currentUser?.uid ?? '';
    if (userId.isEmpty) {
      _showSnack('Sign in required for voice test', success: false);
      return;
    }

    final reminder = reminders.cast<Reminder?>().firstWhere(
          (r) => r!.userId.isNotEmpty && r.id != 'test-ringtone',
          orElse: () => null,
        );
    if (reminder == null) {
      _showSnack('Create a reminder first, then test voice', success: false);
      return;
    }

    setState(() => _testingVoice = true);
    try {
      await _reminderController.playVoiceNotification(reminder);
      _showSnack(
        'Voice test started for "${reminder.title}" (${reminder.id})',
      );
    } catch (e) {
      _showSnack('Voice test failed: $e', success: false);
    } finally {
      if (mounted) setState(() => _testingVoice = false);
    }
  }

  Future<void> _stopTestAudio() async {
    await _reminderController.stopAudio();
    _showSnack('Audio stopped');
  }

  // Returns list of {label, value} from oldest to newest day
  List<Map<String, dynamic>> _trend(List<Reminder> reminders, int days) {
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final now = DateTime.now();
    return List.generate(days, (index) {
      // index 0 = oldest day (6 days ago), index 6 = today
      final day = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: days - 1 - index));
      final dayName = dayNames[day.weekday - 1]; // weekday 1=Mon..7=Sun
      final isToday = index == days - 1;
      final label = isToday ? 'Today' : dayName;

      final dayReminders = reminders.where((r) {
        final due = DateTime(
            r.reminderTime.year, r.reminderTime.month, r.reminderTime.day);
        return due == day;
      }).toList();
      final completed = dayReminders
          .where((r) => r.status == ReminderStatus.completed)
          .length;
      final value = dayReminders.isEmpty
          ? 0
          : (completed * 100 / dayReminders.length).round();

      return {'label': label, 'value': value};
    });
  }

  @override
  Widget build(BuildContext context) {
    final prov = Provider.of<ReminderProvider>(context);
    final total = prov.reminders.length;
    final completed =
        prov.reminders.where((r) => r.status == ReminderStatus.completed).length;
    final snoozed =
        prov.reminders.where((r) => r.status == ReminderStatus.snoozed).length;
    final missed =
        prov.reminders.where((r) => r.status == ReminderStatus.missed).length;
    final pending =
        prov.reminders.where((r) => r.status == ReminderStatus.pending).length;
    final today = prov.reminders.where((r) {
      final date = r.reminderTime.toLocal();
      final now = DateTime.now();
      return date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
    }).toList();
    final upcoming = prov.reminders
        .where((r) => r.reminderTime.toLocal().isAfter(DateTime.now()))
        .toList();
    final completionPct = _completionRate(completed, total).round();
    final streak = _calculateStreak(prov.reminders);
    final trend = _trend(prov.reminders, 7); // List<Map<String,dynamic>>

    final email = Provider.of<AuthProvider>(context, listen: false)
            .currentUserEmail ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Dashboard',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            if (email.isNotEmpty)
              Text(
                email,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Completed reminders',
            onPressed: () => Navigator.pushNamed(context, '/history'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () async {
              final auth = Provider.of<AuthProvider>(context, listen: false);
              final reminders =
                  Provider.of<ReminderProvider>(context, listen: false);
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                Text('Good day!',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(
                    'Your reminders at a glance with productivity tracking and trend analytics.',
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 24),

                // ── Stat cards ─────────────────────────────────────────────
                SizedBox(
                  height: 90,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      _buildStatCard('Total', total.toString(), Colors.indigo.shade50),
                      const SizedBox(width: 12),
                      _buildStatCard('Completed', completed.toString(), Colors.green.shade50),
                      const SizedBox(width: 12),
                      _buildStatCard('Pending', pending.toString(), Colors.orange.shade50),
                      const SizedBox(width: 12),
                      _buildStatCard('Snoozed', snoozed.toString(), Colors.blue.shade50),
                      const SizedBox(width: 12),
                      _buildStatCard('Missed', missed.toString(), Colors.red.shade50),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── Overview card ──────────────────────────────────────────
                Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18)),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Overview',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(
                              child: _buildProgressTile(
                                  'Completion', '$completionPct%', Colors.green)),
                          const SizedBox(width: 12),
                          Expanded(
                              child: _buildProgressTile(
                                  'Streak', '$streak days', Colors.blue)),
                        ]),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ── Today's tasks ──────────────────────────────────────────
                Text("Today's Tasks",
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                if (today.isEmpty)
                  Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                          child: Text(
                              'You have no tasks scheduled for today.',
                              style: Theme.of(context).textTheme.bodyMedium)),
                    ),
                  )
                else
                  ...today.map((r) => ListTile(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        tileColor: Colors.grey.shade100,
                        title: Text(r.title,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                            '${_formatTime(r.reminderTime.toLocal())} • ${_typeLabel(r.type)}'),
                        trailing: Icon(
                          r.status == ReminderStatus.completed
                              ? Icons.check_circle
                              : Icons.notifications,
                          color: r.status == ReminderStatus.completed
                              ? Colors.green
                              : Colors.orange,
                        ),
                        onTap: () => Navigator.pushNamed(context, '/details',
                            arguments: r),
                      )),
                const SizedBox(height: 24),

                // ── Upcoming reminders ─────────────────────────────────────
                Text('Upcoming Reminders',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                if (upcoming.isEmpty)
                  Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                          child: Text(
                              'No upcoming reminders scheduled yet.',
                              style: Theme.of(context).textTheme.bodyMedium)),
                    ),
                  )
                else
                  ...upcoming.take(3).map((r) => ListTile(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        tileColor: Colors.grey.shade100,
                        title: Text(r.title,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        // ── Priority chip removed ──────────────────────────
                        subtitle: Text(
                            '${_formatTime(r.reminderTime.toLocal())} • ${ReminderCategory.label(r.category)}'),
                        trailing: Icon(
                          Icons.alarm,
                          color: Colors.indigo.shade400,
                        ),
                        onTap: () => Navigator.pushNamed(context, '/details',
                            arguments: r),
                      )),
                const SizedBox(height: 24),

                // ── Weekly trend ───────────────────────────────────────────
                Text('Weekly Completion Trend',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18)),
                  color: Colors.grey.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: trend.map((entry) {
                            final label = entry['label'] as String;
                            final value = entry['value'] as int;
                            final isToday = label == 'Today';
                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 6.0),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 44,
                                    child: Text(
                                      label,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: isToday
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: isToday
                                            ? Colors.indigo
                                            : Colors.black54,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: LinearProgressIndicator(
                                      value: value / 100,
                                      color: isToday
                                          ? Colors.indigo
                                          : Colors.indigo.shade300,
                                      backgroundColor:
                                          Colors.indigo.shade100,
                                      minHeight: 8,
                                      borderRadius:
                                          BorderRadius.circular(4),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 36,
                                    child: Text(
                                      '$value%',
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: isToday
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: isToday
                                            ? Colors.indigo
                                            : Colors.black54,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ── Notification tests ─────────────────────────────────────
                Text('Notification Tests',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  'Quick checks for backend connectivity and audio playback.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'API: ${ApiService.baseUrl}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _testingBackend ? null : _testBackend,
                          icon: _testingBackend
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.cloud_done_outlined),
                          label: const Text('Test Backend'),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _testingRingtone ? null : _testRingtone,
                          icon: _testingRingtone
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.notifications_active),
                          label: const Text('Test Ringtone'),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _testingVoice
                              ? null
                              : () => _testVoice(prov.reminders),
                          icon: _testingVoice
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.record_voice_over),
                          label: const Text('Test Voice'),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _stopTestAudio,
                          icon: const Icon(Icons.stop_circle_outlined),
                          label: const Text('Stop Audio'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // ── View all button ────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.list_alt),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.0),
                      child: Text('View all reminders',
                          style: TextStyle(fontSize: 16)),
                    ),
                    onPressed: () =>
                        Navigator.pushNamed(context, '/reminders'),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatCard(String title, String value, Color background) {
    return Container(
      width: 110,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: background.withValues(alpha: 0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Colors.black87)),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black)),
        ],
      ),
    );
  }

  Widget _buildProgressTile(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Text(value,
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color)),
      ]),
    );
  }
}