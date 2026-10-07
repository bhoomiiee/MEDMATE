import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/auth_guard.dart';
import '../../../core/widgets/app_button.dart';

class AddScheduleScreen extends StatefulWidget {
  final String medicineId;
  const AddScheduleScreen({super.key, required this.medicineId});

  @override
  State<AddScheduleScreen> createState() => _AddScheduleScreenState();
}

class _AddScheduleScreenState extends State<AddScheduleScreen> {
  Map<String, dynamic>? _medicine;
  bool _loading = false;
  bool _saving = false;

  String _frequency = 'daily';
  List<String> _times = ['08:00'];
  List<int> _selectedDays = [];
  int _intervalHours = 8;
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  bool _withFood = false;
  String _instructions = '';

  @override
  void initState() {
    super.initState();
    _loadMedicine();
  }

  Future<void> _loadMedicine() async {
    setState(() => _loading = true);
    final med = await SupabaseService.getMedicine(widget.medicineId);
    setState(() {
      _medicine = med;
      _loading = false;
    });
  }

  void _onFrequencyChanged(String freq) {
    setState(() {
      _frequency = freq;
      switch (freq) {
        case 'daily':
          _times = ['08:00'];
          break;
        case 'twice_daily':
          _times = ['08:00', '20:00'];
          break;
        case 'thrice_daily':
          _times = ['08:00', '14:00', '20:00'];
          break;
        case 'every_x_hours':
          _times = ['08:00'];
          break;
        case 'specific_days':
          _times = ['08:00'];
          _selectedDays = [0, 1, 2, 3, 4]; // Mon-Fri default
          break;
        case 'as_needed':
          _times = [];
          break;
      }
    });
  }

  Future<void> _pickTime(int index) async {
    final current = _times[index].split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
          hour: int.parse(current[0]), minute: int.parse(current[1])),
    );
    if (picked != null) {
      setState(() {
        _times[index] =
            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _pickDate({bool isEnd = false}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isEnd ? (_endDate ?? DateTime.now()) : _startDate,
      firstDate: isEnd ? _startDate : DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null) {
      setState(() {
        if (isEnd) {
          _endDate = picked;
        } else {
          _startDate = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    if (_frequency != 'as_needed' && _times.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one time')),
      );
      return;
    }
    final userId = await AuthGuard.requireUserId(context);
    if (userId == null) return;

    setState(() => _saving = true);
    try {
      final data = {
        'user_medicine_id': widget.medicineId,
        'user_id': userId,
        'frequency': _frequency,
        'times': _times,
        'days_of_week':
            _frequency == 'specific_days' ? _selectedDays : null,
        'interval_hours':
            _frequency == 'every_x_hours' ? _intervalHours : null,
        'start_date':
            DateFormat('yyyy-MM-dd').format(_startDate),
        'end_date': _endDate != null
            ? DateFormat('yyyy-MM-dd').format(_endDate!)
            : null,
        'with_food': _withFood,
        'instructions':
            _instructions.isEmpty ? null : _instructions,
        'is_active': true,
      };

      await SupabaseService.addSchedule(data);

      // Schedule notifications
      final medName = _medicine?['name'] ?? 'Medicine';
      final dosage = _medicine?['dosage'] ?? '';
      for (int i = 0; i < _times.length; i++) {
        final parts = _times[i].split(':');
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        final notifId = widget.medicineId.hashCode ^ (i * 1000);
        if (_frequency == 'daily' ||
            _frequency == 'twice_daily' ||
            _frequency == 'thrice_daily') {
          await NotificationService.scheduleDailyReminder(
            id: notifId,
            medicineName: medName,
            dosage: dosage,
            hour: hour,
            minute: minute,
            withFood: _withFood,
          );
        } else {
          final now = DateTime.now();
          var dt = DateTime(
              now.year, now.month, now.day, hour, minute);
          if (dt.isBefore(now)) dt = dt.add(const Duration(days: 1));
          await NotificationService.scheduleMedicineReminder(
            id: notifId,
            medicineName: medName,
            dosage: dosage,
            scheduledTime: dt,
            withFood: _withFood,
            instructions: _instructions.isEmpty ? null : _instructions,
          );
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Schedule saved and reminders set'),
          backgroundColor: AppColors.secondary,
        ),
      );
      context.go('/medicines/${widget.medicineId}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Add Schedule'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.go('/medicines/${widget.medicineId}'),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_medicine != null)
                    _MedicineHeader(medicine: _medicine!),
                  const SizedBox(height: 20),

                  _sectionTitle('Frequency'),
                  const SizedBox(height: 12),
                  ...AppConstants.frequencyOptions.map((f) => _freqTile(f)),

                  const SizedBox(height: 20),

                  if (_frequency != 'as_needed') ...[
                    _sectionTitle('Times'),
                    const SizedBox(height: 12),
                    ..._times.asMap().entries.map((e) => _timeTile(e.key)),
                    if (_frequency == 'daily' ||
                        _frequency == 'specific_days' ||
                        _frequency == 'every_x_hours')
                      TextButton.icon(
                        onPressed: () => setState(() => _times.add('12:00')),
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text('Add another time'),
                      ),
                    const SizedBox(height: 20),
                  ],

                  if (_frequency == 'every_x_hours') ...[
                    _sectionTitle('Repeat every'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _counterBtn(Icons.remove_rounded,
                            () => setState(() {
                                  if (_intervalHours > 1) _intervalHours--;
                                })),
                        Expanded(
                          child: Center(
                            child: Text('$_intervalHours hours',
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ),
                        _counterBtn(Icons.add_rounded,
                            () => setState(() {
                                  if (_intervalHours < 24) _intervalHours++;
                                })),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],

                  if (_frequency == 'specific_days') ...[
                    _sectionTitle('Days of Week'),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(7, (i) {
                        final selected = _selectedDays.contains(i);
                        return GestureDetector(
                          onTap: () => setState(() {
                            selected
                                ? _selectedDays.remove(i)
                                : _selectedDays.add(i);
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.primary
                                  : AppColors.surface,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: selected
                                      ? AppColors.primary
                                      : AppColors.border),
                            ),
                            child: Center(
                              child: Text(
                                AppConstants.daysOfWeek[i],
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: selected
                                        ? Colors.white
                                        : AppColors.textSecondary),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 20),
                  ],

                  _sectionTitle('Duration'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _dateTile('Start Date', _startDate,
                            () => _pickDate()),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _dateTile(
                            'End Date',
                            _endDate,
                            () => _pickDate(isEnd: true),
                            isOptional: true),
                      ),
                    ],
                  ),
                  if (_endDate != null)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => setState(() => _endDate = null),
                        child: const Text('Clear end date'),
                      ),
                    ),
                  const SizedBox(height: 20),

                  _sectionTitle('Options'),
                  const SizedBox(height: 12),
                  _switchTile(
                    'Take with food',
                    'Reminder will mention taking with food',
                    Icons.restaurant_outlined,
                    _withFood,
                    (v) => setState(() => _withFood = v),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Special Instructions',
                      hintText:
                          'e.g. Shake well before use, take with warm water',
                      prefixIcon: const Icon(Icons.info_outline_rounded),
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: AppColors.border)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: AppColors.border)),
                    ),
                    maxLines: 2,
                    onChanged: (v) => _instructions = v,
                  ),
                  const SizedBox(height: 32),
                  AppButton(
                    label: 'Save Schedule',
                    onPressed: _save,
                    loading: _saving,
                    icon: Icons.alarm_add_rounded,
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _freqTile(String freq) {
    final selected = _frequency == freq;
    final label = AppConstants.frequencyDisplayNames[freq] ?? freq;
    return GestureDetector(
      onTap: () => _onFrequencyChanged(freq),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySurface : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? AppColors.primary : AppColors.textMuted,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: selected
                        ? AppColors.primary
                        : AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }

  Widget _timeTile(int index) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: const Border.fromBorderSide(
              BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            const Icon(Icons.access_time_rounded, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(_times[index],
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            TextButton(
              onPressed: () => _pickTime(index),
              child: const Text('Change'),
            ),
            if (_times.length > 1)
              IconButton(
                icon: const Icon(Icons.remove_circle_outline_rounded,
                    color: AppColors.error),
                onPressed: () => setState(() => _times.removeAt(index)),
              ),
          ],
        ),
      );

  Widget _dateTile(String label, DateTime? date, VoidCallback onTap,
      {bool isOptional = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: const Border.fromBorderSide(
              BorderSide(color: AppColors.border)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 11)),
            const SizedBox(height: 4),
            Text(
              date != null
                  ? DateFormat('d MMM yyyy').format(date)
                  : isOptional
                      ? 'No end date'
                      : 'Select date',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: date != null
                      ? AppColors.textPrimary
                      : AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _switchTile(String title, String subtitle, IconData icon, bool value,
      void Function(bool) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: const Border.fromBorderSide(
            BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                Text(subtitle,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _counterBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.primarySurface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.primary),
        ),
      );

  Widget _sectionTitle(String title) => Text(title,
      style: Theme.of(context)
          .textTheme
          .titleMedium
          ?.copyWith(color: AppColors.textSecondary));
}

class _MedicineHeader extends StatelessWidget {
  final Map<String, dynamic> medicine;
  const _MedicineHeader({required this.medicine});

  @override
  Widget build(BuildContext context) {
    final hex = medicine['color'] as String?;
    final color = hex != null
        ? Color(int.parse(hex.replaceFirst('#', '0xFF')))
        : AppColors.primary;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.medication_rounded, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(medicine['name'] ?? '',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 15)),
              Text(
                  '${medicine['dosage']} ${medicine['unit'] ?? ''} • ${medicine['form'] ?? ''}',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}
