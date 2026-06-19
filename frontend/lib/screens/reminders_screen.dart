// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/reminder_provider.dart';
import '../widgets/reminder_card.dart';
import '../models/reminder.dart';
import '../utils/reminder_utils.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

String _fmtDateTime(DateTime v) {
  final h = v.hour == 0 ? 12 : v.hour > 12 ? v.hour - 12 : v.hour;
  final m = v.minute.toString().padLeft(2, '0');
  final p = v.hour >= 12 ? 'PM' : 'AM';
  return '${v.month}/${v.day}/${v.year}  $h:$m $p';
}

String _ordinal(int n) {
  if (n >= 11 && n <= 13) return '${n}th';
  switch (n % 10) {
    case 1:
      return '${n}st';
    case 2:
      return '${n}nd';
    case 3:
      return '${n}rd';
    default:
      return '${n}th';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Bottom sheet
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> _showAddSheet(ReminderProvider prov) async {
    _titleCtrl.clear();
    _descCtrl.clear();

    // Shared state
    String type = ReminderType.daily;
    String category = ReminderCategory.personal;
    String notificationMode = 'ringtone';

    int maxSnooze = 3;
    int snoozeInterval = 10;

    // Hourly
    String startTime = '09:00';
    String endTime = '18:00';
    int repeatEveryMinutes = 60;

    // Daily
    DateTime selectedDateTime = DateTime.now().add(const Duration(hours: 1));
    String activeZone = ReminderActiveDateZone.daily;
    final selectedDays = <String>[];

    // Monthly
    int dayOfMonth = 1;
    bool lastDayOfMonth = false;
    TimeOfDay monthlyTime = const TimeOfDay(hour: 9, minute: 0);

    await showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(builder: (ctx, setState) {
          // ── Section builders ──────────────────────────────────────────────

          // Chip row helper
          Widget chipRow<T>(
            List<T> items,
            T selected,
            String Function(T) label,
            void Function(T) onSelect, {
            Color accentColor = const Color(0xFF5C6BC0),
          }) {
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: items.map((item) {
                final sel = item == selected;
                return ChoiceChip(
                  label: Text(label(item)),
                  selected: sel,
                  onSelected: (_) => onSelect(item),
                  selectedColor: accentColor.withValues(alpha: 0.18),
                  checkmarkColor: accentColor,
                  labelStyle: TextStyle(
                    color: sel ? accentColor : Colors.black87,
                    fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  side: BorderSide(
                      color: sel ? accentColor : Colors.grey.shade300),
                );
              }).toList(),
            );
          }

          // Time tile helper
          Widget timeTile({
            required String label,
            required String value,
            required IconData icon,
            required VoidCallback onTap,
          }) {
            return InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Icon(icon, size: 20, color: const Color(0xFF5C6BC0)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(label,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.black45,
                                  fontWeight: FontWeight.w500)),
                          const SizedBox(height: 2),
                          Text(value,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87)),
                        ],
                      ),
                    ),
                    const Icon(Icons.expand_more,
                        size: 18, color: Colors.black38),
                  ],
                ),
              ),
            );
          }

          // ── Frequency-specific sections ───────────────────────────────────

          Widget buildHourlySection() {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionLabel(icon: Icons.schedule, label: 'Active Window'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: timeTile(
                        label: 'Start Time',
                        value: formatTimeHHmm(startTime),
                        icon: Icons.play_circle_outline,
                        onTap: () async {
                          final t = await showTimePicker(
                            context: sheetCtx,
                            initialTime: TimeOfDay(
                              hour: int.parse(startTime.split(':')[0]),
                              minute: int.parse(startTime.split(':')[1]),
                            ),
                          );
                          if (t == null) return;
                          setState(() => startTime =
                              '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}');
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: timeTile(
                        label: 'End Time',
                        value: formatTimeHHmm(endTime),
                        icon: Icons.stop_circle_outlined,
                        onTap: () async {
                          final t = await showTimePicker(
                            context: sheetCtx,
                            initialTime: TimeOfDay(
                              hour: int.parse(endTime.split(':')[0]),
                              minute: int.parse(endTime.split(':')[1]),
                            ),
                          );
                          if (t == null) return;
                          setState(() => endTime =
                              '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}');
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SectionLabel(icon: Icons.repeat, label: 'Repeat Every'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _repeatOptions.entries.map((e) {
                    final sel = repeatEveryMinutes == e.key;
                    return ChoiceChip(
                      label: Text(e.value),
                      selected: sel,
                      onSelected: (_) =>
                          setState(() => repeatEveryMinutes = e.key),
                      selectedColor:
                          const Color(0xFF5C6BC0).withValues(alpha: 0.18),
                      checkmarkColor: const Color(0xFF5C6BC0),
                      labelStyle: TextStyle(
                        color: sel
                            ? const Color(0xFF5C6BC0)
                            : Colors.black87,
                        fontWeight:
                            sel ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13,
                      ),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      side: BorderSide(
                          color: sel
                              ? const Color(0xFF5C6BC0)
                              : Colors.grey.shade300),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                _InfoChip(
                  text:
                      'Triggers every ${_repeatOptions[repeatEveryMinutes]} between ${formatTimeHHmm(startTime)} and ${formatTimeHHmm(endTime)}',
                ),
              ],
            );
          }

          Widget buildDailySection() {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionLabel(
                    icon: Icons.calendar_today,
                    label: 'Reminder Date & Time'),
                const SizedBox(height: 10),
                timeTile(
                  label: 'Date & Time',
                  value: _fmtDateTime(selectedDateTime),
                  icon: Icons.calendar_month,
                  onTap: () async {
                    final date = await showDatePicker(
                      context: sheetCtx,
                      initialDate: selectedDateTime,
                      firstDate: DateTime.now(),
                      lastDate:
                          DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date == null) return;
                    final time = await showTimePicker(
                      context: sheetCtx,
                      initialTime: TimeOfDay.fromDateTime(selectedDateTime),
                    );
                    if (time == null) return;
                    setState(() => selectedDateTime = DateTime(date.year,
                        date.month, date.day, time.hour, time.minute));
                  },
                ),
                const SizedBox(height: 16),
                _SectionLabel(
                    icon: Icons.schedule, label: 'Active Time Window'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: timeTile(
                        label: 'Start Time',
                        value: formatTimeHHmm(startTime),
                        icon: Icons.play_circle_outline,
                        onTap: () async {
                          final t = await showTimePicker(
                            context: sheetCtx,
                            initialTime: TimeOfDay(
                              hour: int.parse(startTime.split(':')[0]),
                              minute: int.parse(startTime.split(':')[1]),
                            ),
                          );
                          if (t == null) return;
                          setState(() => startTime =
                              '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}');
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: timeTile(
                        label: 'End Time',
                        value: formatTimeHHmm(endTime),
                        icon: Icons.stop_circle_outlined,
                        onTap: () async {
                          final t = await showTimePicker(
                            context: sheetCtx,
                            initialTime: TimeOfDay(
                              hour: int.parse(endTime.split(':')[0]),
                              minute: int.parse(endTime.split(':')[1]),
                            ),
                          );
                          if (t == null) return;
                          setState(() => endTime =
                              '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}');
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SectionLabel(icon: Icons.date_range, label: 'Active Days'),
                const SizedBox(height: 10),
                chipRow<String>(
                  ReminderActiveDateZone.values,
                  activeZone,
                  ReminderActiveDateZone.label,
                  (z) {
                    setState(() {
                      activeZone = z;
                      if (z != ReminderActiveDateZone.custom) {
                        selectedDays.clear();
                      }
                    });
                  },
                ),
                if (activeZone == ReminderActiveDateZone.custom) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children:
                        ReminderActiveDateZone.availableDays.map((day) {
                      final sel = selectedDays.contains(day);
                      return FilterChip(
                        label: Text(day.substring(0, 3),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: sel
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: sel
                                  ? const Color(0xFF5C6BC0)
                                  : Colors.black87,
                            )),
                        selected: sel,
                        selectedColor: const Color(0xFF5C6BC0)
                            .withValues(alpha: 0.18),
                        checkmarkColor: const Color(0xFF5C6BC0),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                        side: BorderSide(
                            color: sel
                                ? const Color(0xFF5C6BC0)
                                : Colors.grey.shade300),
                        onSelected: (val) => setState(() => val
                            ? selectedDays.add(day)
                            : selectedDays.remove(day)),
                      );
                    }).toList(),
                  ),
                ],
              ],
            );
          }

          Widget buildMonthlySection() {
            final timeStr =
                '${monthlyTime.hour.toString().padLeft(2, '0')}:${monthlyTime.minute.toString().padLeft(2, '0')}';

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionLabel(
                    icon: Icons.calendar_view_month,
                    label: 'Day of Month'),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: SwitchListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14),
                    title: const Text('Last day of month',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: const Text('e.g. Jan 31, Feb 28/29…',
                        style: TextStyle(
                            fontSize: 12, color: Colors.black45)),
                    value: lastDayOfMonth,
                    activeThumbColor: const Color(0xFF5C6BC0),
                    onChanged: (v) =>
                        setState(() => lastDayOfMonth = v),
                  ),
                ),
                if (!lastDayOfMonth) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 52,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: 31,
                      itemBuilder: (_, i) {
                        final day = i + 1;
                        final sel = dayOfMonth == day;
                        return GestureDetector(
                          onTap: () =>
                              setState(() => dayOfMonth = day),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            margin: const EdgeInsets.only(right: 8),
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: sel
                                  ? const Color(0xFF5C6BC0)
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: sel
                                    ? const Color(0xFF5C6BC0)
                                    : Colors.grey.shade300,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '$day',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: sel
                                    ? Colors.white
                                    : Colors.black87,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                _SectionLabel(
                    icon: Icons.access_alarm, label: 'Reminder Time'),
                const SizedBox(height: 10),
                timeTile(
                  label: 'Time',
                  value: formatTimeHHmm(timeStr),
                  icon: Icons.access_time,
                  onTap: () async {
                    final t = await showTimePicker(
                      context: sheetCtx,
                      initialTime: monthlyTime,
                    );
                    if (t == null) return;
                    setState(() => monthlyTime = t);
                  },
                ),
                const SizedBox(height: 8),
                _InfoChip(
                  text: lastDayOfMonth
                      ? 'Every month on the last day at ${formatTimeHHmm(timeStr)}'
                      : 'Every month on the ${_ordinal(dayOfMonth)} at ${formatTimeHHmm(timeStr)}',
                ),
              ],
            );
          }

          // ── Full sheet content ────────────────────────────────────────────
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(28)),
            ),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetCtx).size.height * 0.92,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF5C6BC0)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.add_alarm,
                            color: Color(0xFF5C6BC0), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'New Reminder',
                        style:
                            Theme.of(ctx).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF3949AB),
                                ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close,
                            color: Colors.black38),
                        onPressed: () =>
                            Navigator.of(sheetCtx).pop(),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Scrollable body
                Flexible(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(
                      left: 20,
                      right: 20,
                      top: 16,
                      bottom:
                          MediaQuery.of(sheetCtx).viewInsets.bottom + 24,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Title ─────────────────────────────────────
                          TextFormField(
                            controller: _titleCtrl,
                            decoration: InputDecoration(
                              labelText: 'Title *',
                              hintText: 'What do you want to remember?',
                              prefixIcon: const Icon(Icons.edit_note,
                                  color: Color(0xFF5C6BC0)),
                              border: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(14)),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            validator: (v) =>
                                (v == null || v.trim().isEmpty)
                                    ? 'Title is required'
                                    : null,
                          ),
                          const SizedBox(height: 10),
                          // ── Description ───────────────────────────────
                          TextFormField(
                            controller: _descCtrl,
                            decoration: InputDecoration(
                              labelText: 'Description',
                              hintText: 'Optional details…',
                              prefixIcon: const Icon(Icons.notes,
                                  color: Color(0xFF5C6BC0)),
                              border: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(14)),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 20),
                          // ── Frequency ─────────────────────────────────
                          _SectionLabel(
                              icon: Icons.loop, label: 'Frequency'),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(16),
                              border:
                                  Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(
                              children: ReminderType.values.map((t) {
                                final sel = t == type;
                                return Expanded(
                                  child: GestureDetector(
                                    onTap: () =>
                                        setState(() => type = t),
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                          milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 10),
                                      decoration: BoxDecoration(
                                        color: sel
                                            ? const Color(0xFF5C6BC0)
                                            : Colors.transparent,
                                        borderRadius:
                                            BorderRadius.circular(13),
                                        boxShadow: sel
                                            ? [
                                                BoxShadow(
                                                  color: const Color(
                                                          0xFF5C6BC0)
                                                      .withValues(
                                                          alpha: 0.25),
                                                  blurRadius: 8,
                                                  offset:
                                                      const Offset(0, 2),
                                                )
                                              ]
                                            : null,
                                      ),
                                      alignment: Alignment.center,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            _typeIcon(t),
                                            size: 15,
                                            color: sel
                                                ? Colors.white
                                                : Colors.black54,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            ReminderType.label(t),
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: sel
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                              color: sel
                                                  ? Colors.white
                                                  : Colors.black54,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // ── Frequency-specific section ─────────────────
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            transitionBuilder: (child, anim) =>
                                FadeTransition(
                                    opacity: anim,
                                    child: SlideTransition(
                                        position: Tween<Offset>(
                                          begin: const Offset(0, 0.04),
                                          end: Offset.zero,
                                        ).animate(anim),
                                        child: child)),
                            child: KeyedSubtree(
                              key: ValueKey(type),
                              child: type == ReminderType.interval
                                  ? buildHourlySection()
                                  : type == ReminderType.daily
                                      ? buildDailySection()
                                      : buildMonthlySection(),
                            ),
                          ),

                          const SizedBox(height: 20),
                          const Divider(),
                          const SizedBox(height: 8),

                          // ── Category ───────────────────────────────────
                          _SectionLabel(
                              icon: Icons.label_outline,
                              label: 'Category'),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 52,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              children:
                                  ReminderCategory.values.map((cat) {
                                final sel = cat == category;
                                final col = ReminderCategory.color(cat);
                                final ic = ReminderCategory.icon(cat);
                                return GestureDetector(
                                  onTap: () =>
                                      setState(() => category = cat),
                                  child: AnimatedContainer(
                                    duration:
                                        const Duration(milliseconds: 180),
                                    margin:
                                        const EdgeInsets.only(right: 8),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: sel
                                          ? col.withValues(alpha: 0.15)
                                          : Colors.grey.shade50,
                                      borderRadius:
                                          BorderRadius.circular(12),
                                      border: Border.all(
                                        color: sel
                                            ? col
                                            : Colors.grey.shade200,
                                        width: sel ? 1.5 : 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(ic,
                                            size: 16,
                                            color: sel
                                                ? col
                                                : Colors.black38),
                                        const SizedBox(width: 6),
                                        Text(
                                          cat,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: sel
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                            color: sel
                                                ? col
                                                : Colors.black54,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // ── Notification Mode ──────────────────────────
                          _SectionLabel(
                              icon: Icons.notifications_active,
                              label: 'Notification Mode'),
                          const SizedBox(height: 10),
                          Row(children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(
                                    () => notificationMode = 'ringtone'),
                                child: AnimatedContainer(
                                  duration:
                                      const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 14),
                                  decoration: BoxDecoration(
                                    color: notificationMode == 'ringtone'
                                        ? const Color(0xFF5C6BC0)
                                            .withValues(alpha: 0.12)
                                        : Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: notificationMode == 'ringtone'
                                          ? const Color(0xFF5C6BC0)
                                          : Colors.grey.shade200,
                                      width:
                                          notificationMode == 'ringtone'
                                              ? 1.5
                                              : 1,
                                    ),
                                  ),
                                  child: Column(children: [
                                    Icon(
                                      Icons.notifications_active,
                                      color: notificationMode == 'ringtone'
                                          ? const Color(0xFF5C6BC0)
                                          : Colors.black38,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Ringtone',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight:
                                            notificationMode == 'ringtone'
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                        color: notificationMode == 'ringtone'
                                            ? const Color(0xFF5C6BC0)
                                            : Colors.black54,
                                      ),
                                    ),
                                  ]),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(
                                    () => notificationMode = 'voice'),
                                child: AnimatedContainer(
                                  duration:
                                      const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 14),
                                  decoration: BoxDecoration(
                                    color: notificationMode == 'voice'
                                        ? const Color(0xFF5C6BC0)
                                            .withValues(alpha: 0.12)
                                        : Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: notificationMode == 'voice'
                                          ? const Color(0xFF5C6BC0)
                                          : Colors.grey.shade200,
                                      width: notificationMode == 'voice'
                                          ? 1.5
                                          : 1,
                                    ),
                                  ),
                                  child: Column(children: [
                                    Icon(
                                      Icons.record_voice_over,
                                      color: notificationMode == 'voice'
                                          ? const Color(0xFF5C6BC0)
                                          : Colors.black38,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Voice',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight:
                                            notificationMode == 'voice'
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                        color: notificationMode == 'voice'
                                            ? const Color(0xFF5C6BC0)
                                            : Colors.black54,
                                      ),
                                    ),
                                  ]),
                                ),
                              ),
                            ),
                          ]),
                          const SizedBox(height: 28),

                          // ── Save button ────────────────────────────────
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF3949AB),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(16)),
                                elevation: 2,
                              ),
                              onPressed: () async {
                                if (!_formKey.currentState!.validate()) {
                                  return;
                                }

                                // ── Validate reminder time against active window ──
                                DateTime reminderTime = selectedDateTime;
                                if (type == ReminderType.monthly) {
                                  final now = DateTime.now();
                                  final targetDay = lastDayOfMonth
                                      ? DateTime(
                                              now.year, now.month + 1, 0)
                                          .day
                                      : dayOfMonth;
                                  reminderTime = DateTime(
                                    now.year,
                                    now.month,
                                    targetDay,
                                    monthlyTime.hour,
                                    monthlyTime.minute,
                                  );
                                } else if (type == ReminderType.interval) {
                                  final now = DateTime.now();
                                  final parts = startTime.split(':');
                                  reminderTime = DateTime(
                                    now.year,
                                    now.month,
                                    now.day,
                                    int.parse(parts[0]),
                                    int.parse(parts[1]),
                                  );
                                }

                                final validationError =
                                    ReminderTimeValidation.validateReminderTime(
                                  type: type,
                                  reminderTime: reminderTime,
                                  startTime: startTime,
                                  endTime: endTime,
                                );
                                if (validationError != null) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(
                                      content: Text(validationError),
                                      backgroundColor: Colors.red.shade600,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                    ),
                                  );
                                  return;
                                }

                                final stateCtx = context;
                                final draft = prov.createDraft(
                                  title: _titleCtrl.text.trim(),
                                  description: _descCtrl.text.trim(),
                                  type: type,
                                  reminderTime: reminderTime,
                                );

                                final newReminder = draft.copyWith(
                                  startTime: startTime,
                                  endTime: endTime,
                                  activeDateZone: activeZone,
                                  selectedDays: selectedDays,
                                  priority: ReminderPriority.medium, // fixed default
                                  category: category,
                                  notificationMode: notificationMode,
                                  notificationSound: ReminderSound.alarm, // always alarm
                                  maxSnoozeCount: maxSnooze,
                                  snoozeIntervalMinutes: snoozeInterval,
                                  status: ReminderStatus.pending,
                                  currentSnoozeCount: 0,
                                  repeatEveryMinutes: repeatEveryMinutes,
                                  dayOfMonth:
                                      lastDayOfMonth ? 0 : dayOfMonth,
                                  lastDayOfMonth: lastDayOfMonth,
                                );

                                await prov.add(newReminder);
                                if (!mounted) return;
                                Navigator.of(stateCtx).pop();
                                ScaffoldMessenger.of(stateCtx)
                                    .showSnackBar(
                                  SnackBar(
                                    content: const Row(
                                      children: [
                                        Icon(Icons.check_circle,
                                            color: Colors.white, size: 18),
                                        SizedBox(width: 8),
                                        Text(
                                            'Reminder added successfully!'),
                                      ],
                                    ),
                                    backgroundColor:
                                        const Color(0xFF3949AB),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                  ),
                                );
                              },
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check, size: 20),
                                  SizedBox(width: 8),
                                  Text('Save Reminder',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Repeat options
  // ───────────────────────────────────────────────────────────────────────────

  static const Map<int, String> _repeatOptions = {
    15: '15 min',
    30: '30 min',
    60: '1 hour',
    120: '2 hours',
    180: '3 hours',
    240: '4 hours',
  };

  static IconData _typeIcon(String type) {
    switch (type) {
      case ReminderType.interval:
        return Icons.timelapse;
      case ReminderType.monthly:
        return Icons.calendar_month;
      case ReminderType.daily:
      default:
        return Icons.today;
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Reminders list page
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildSection(String title, List<Reminder> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(title,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              color: Colors.grey.shade100,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No reminders in this section yet.'),
              ),
            ),
          )
        else
          ...items.map((r) => ReminderCard(
              reminder: r,
              onTap: () =>
                  Navigator.pushNamed(context, '/details', arguments: r),
              onDelete: () async {
                final prov = Provider.of<ReminderProvider>(context, listen: false);
                await prov.deleteReminder(r.id);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.delete, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text('Reminder "${r.title}" deleted')),
                      ],
                    ),
                    backgroundColor: Colors.red.shade600,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                );
              },
          )),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final prov = Provider.of<ReminderProvider>(context);
    final hourly =
        prov.reminders.where((r) => r.type == ReminderType.interval).toList();
    final daily =
        prov.reminders.where((r) => r.type == ReminderType.daily).toList();
    final monthly =
        prov.reminders.where((r) => r.type == ReminderType.monthly).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reminders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Completed tasks',
            onPressed: () => Navigator.pushNamed(context, '/history'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () async {
              final auth =
                  Provider.of<AuthProvider>(context, listen: false);
              final reminders =
                  Provider.of<ReminderProvider>(context, listen: false);
              final navigator = Navigator.of(context);
              reminders.clear();
              await auth.signOut();
              if (!mounted) return;
              navigator.pushReplacementNamed('/');
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('Your reminders',
                style: Theme.of(context).textTheme.headlineSmall),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
                'Tap + to add a reminder or tap any card to view details.',
                style: Theme.of(context).textTheme.bodyMedium),
          ),
          const SizedBox(height: 20),
          _buildSection('Interval', hourly),
          _buildSection('Daily', daily),
          _buildSection('Monthly', monthly),
          const SizedBox(height: 96),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSheet(prov),
        backgroundColor: const Color(0xFF3949AB),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_alarm),
        label: const Text('Add Reminder',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small reusable widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SectionLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF5C6BC0)),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Color(0xFF3949AB),
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String text;
  const _InfoChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF5C6BC0).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 15, color: Color(0xFF5C6BC0)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFF3949AB), height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}