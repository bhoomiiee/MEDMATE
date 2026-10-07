import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/empty_state.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  List<Map<String, dynamic>> _schedules = [];
  List<Map<String, dynamic>> _logs = [];
  bool _loading = true;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final start = DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);
      final end = start.add(const Duration(days: 1));
      final results = await Future.wait([
        SupabaseService.getAllActiveSchedules(),
        SupabaseService.getReminderLogs(from: start, to: end),
      ]);
      setState(() {
        _schedules = results[0];
        _logs = results[1];
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _todayReminders {
    final reminders = <Map<String, dynamic>>[];
    for (final s in _schedules) {
      final times = List<String>.from(s['times'] ?? []);
      final start = s['start_date'] as String?;
      final end = s['end_date'] as String?;
      if (start == null) continue;
      if (DateTime.parse(start).isAfter(_selectedDay)) continue;
      if (end != null &&
          DateTime.parse(end)
              .isBefore(_selectedDay.subtract(const Duration(days: 1)))) {
        continue;
      }
      for (final t in times) {
        final parts = t.split(':');
        if (parts.length < 2) continue;
        final dt = DateTime(_selectedDay.year, _selectedDay.month,
            _selectedDay.day, int.parse(parts[0]), int.parse(parts[1]));
        final log = _logs.cast<Map<String, dynamic>?>().firstWhere(
              (l) =>
                  l != null &&
                  l['schedule_id'] == s['id'] &&
                  (l['scheduled_at'] as String).startsWith(
                      DateFormat('yyyy-MM-ddTHH:mm').format(dt).substring(0, 16)),
              orElse: () => null,
            );
        reminders.add({
          ...s,
          'time': t,
          'datetime': dt,
          'log': log,
          'status': log?['status'] ?? 'pending',
        });
      }
    }
    reminders.sort((a, b) =>
        (a['datetime'] as DateTime).compareTo(b['datetime'] as DateTime));
    return reminders;
  }

  Future<void> _markStatus(
      Map<String, dynamic> reminder, String status) async {
    final dt = reminder['datetime'] as DateTime;
    await SupabaseService.upsertReminderLog({
      'schedule_id': reminder['id'],
      'user_id': SupabaseService.currentUserId,
      'scheduled_at': dt.toIso8601String(),
      'status': status,
      if (status == 'taken')
        'taken_at': DateTime.now().toIso8601String(),
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        title: const Text('Medication Schedule'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.backgroundSecondary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: TabBar(
              controller: _tab,
              labelColor: Colors.white,
              unselectedLabelColor:
                  isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              indicator: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              tabs: const [
                Tab(text: 'Daily Timeline'),
                Tab(text: 'Active Plans'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _buildCalendarTab(isDark),
          _buildSchedulesTab(isDark),
        ],
      ),
    );
  }

  Widget _buildCalendarTab(bool isDark) {
    return Column(
      children: [
        // Modern Floating Calendar Card
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.borderSubtle,
            ),
            boxShadow: AppColors.softShadow,
          ),
          child: TableCalendar(
            firstDay: DateTime.now().subtract(const Duration(days: 365)),
            lastDay: DateTime.now().add(const Duration(days: 365)),
            focusedDay: _focusedDay,
            selectedDayPredicate: (d) => isSameDay(d, _selectedDay),
            calendarFormat: CalendarFormat.week,
            startingDayOfWeek: StartingDayOfWeek.monday,
            onDaySelected: (selected, focused) {
              setState(() {
                _selectedDay = selected;
                _focusedDay = focused;
              });
              _load();
            },
            calendarStyle: CalendarStyle(
              selectedDecoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              todayDecoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              todayTextStyle: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
              selectedTextStyle: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
          child: Row(
            children: [
              Text(
                isSameDay(_selectedDay, DateTime.now())
                    ? 'Today\'s Schedule'
                    : DateFormat('EEEE, d MMMM').format(_selectedDay),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_todayReminders.length} reminder${_todayReminders.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _todayReminders.isEmpty
                  ? const EmptyState(
                      icon: Icons.alarm_off_outlined,
                      title: 'No reminders for this day',
                      subtitle: 'Add a medicine and set a schedule to get reminders.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 90),
                      itemCount: _todayReminders.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) =>
                          _buildReminderTile(_todayReminders[i], isDark),
                    ),
        ),
      ],
    );
  }

  Widget _buildReminderTile(Map<String, dynamic> r, bool isDark) {
    final medicine = r['user_medicines'] as Map<String, dynamic>?;
    final name = medicine?['name'] ?? 'Medicine';
    final dosage = medicine?['dosage'] ?? '';
    final form = medicine?['form'] ?? '';
    final time = r['time'] as String;
    final status = r['status'] as String;
    final now = DateTime.now();
    final dt = r['datetime'] as DateTime;
    final isPast = dt.isBefore(now);

    Color borderColor = isDark ? AppColors.darkBorder : AppColors.borderSubtle;
    Color iconBg = AppColors.primarySurface;
    Color iconColor = AppColors.primary;
    IconData statusIcon = Icons.alarm_rounded;

    if (status == 'taken') {
      borderColor = AppColors.secondary.withValues(alpha: 0.4);
      iconBg = AppColors.secondarySurface;
      iconColor = AppColors.secondary;
      statusIcon = Icons.check_circle_rounded;
    } else if (status == 'skipped') {
      borderColor = AppColors.error.withValues(alpha: 0.3);
      iconBg = AppColors.errorSurface;
      iconColor = AppColors.error;
      statusIcon = Icons.cancel_rounded;
    } else if (isPast) {
      borderColor = AppColors.warning.withValues(alpha: 0.4);
      iconBg = AppColors.warningSurface;
      iconColor = AppColors.warning;
      statusIcon = Icons.access_time_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: AppColors.softShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(statusIcon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                    decoration: status == 'taken' ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$dosage • ${_capitalize(form)}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (r['with_food'] == true) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurfaceElevated : AppColors.backgroundSecondary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Take with food',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                time,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: iconColor,
                ),
              ),
              const SizedBox(height: 6),
              if (status == 'pending')
                Row(
                  children: [
                    _actionBtn('Skip', AppColors.error,
                        () => _markStatus(r, 'skipped')),
                    const SizedBox(width: 6),
                    _actionBtn('Taken', AppColors.secondary,
                        () => _markStatus(r, 'taken')),
                  ],
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _capitalize(status),
                    style: TextStyle(
                      color: iconColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionBtn(String label, Color color, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );

  Widget _buildSchedulesTab(bool isDark) {
    return _loading
        ? const Center(child: CircularProgressIndicator())
        : _schedules.isEmpty
            ? const EmptyState(
                icon: Icons.alarm_outlined,
                title: 'No active schedules',
                subtitle:
                    'Open a medicine and tap "Add Schedule" to set reminders',
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                itemCount: _schedules.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) => _buildScheduleCard(_schedules[i], isDark),
              );
  }

  Widget _buildScheduleCard(Map<String, dynamic> s, bool isDark) {
    final medicine = s['user_medicines'] as Map<String, dynamic>?;
    final times = List<String>.from(s['times'] ?? []);
    final freq = s['frequency'] as String? ?? '';
    final startDate = s['start_date'] as String?;
    final endDate = s['end_date'] as String?;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.borderSubtle,
        ),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.medication_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  medicine?['name'] ?? 'Medicine',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded,
                    color: AppColors.error, size: 20),
                onPressed: () async {
                  await SupabaseService.deleteSchedule(s['id']);
                  _load();
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _tag(
                AppConstants.frequencyDisplayNames[freq] ?? _capitalize(freq),
                AppColors.primarySurface,
                AppColors.primary,
              ),
              ...times.map((t) =>
                  _tag(t, AppColors.secondarySurface, AppColors.secondary)),
              if (s['with_food'] == true)
                _tag('With food', AppColors.warningSurface, AppColors.warning),
            ],
          ),
          if (startDate != null) ...[
            const SizedBox(height: 10),
            Text(
              'From ${DateFormat('d MMM yyyy').format(DateTime.parse(startDate))}'
              '${endDate != null ? ' to ${DateFormat('d MMM yyyy').format(DateTime.parse(endDate))}' : ''}',
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _tag(String label, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: fg,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
