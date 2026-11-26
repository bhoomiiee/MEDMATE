import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

import '../services/maternal_health_service.dart';

class SupplementRemindersScreen extends StatefulWidget {
  const SupplementRemindersScreen({super.key});

  @override
  State<SupplementRemindersScreen> createState() =>
      _SupplementRemindersScreenState();
}

class _SupplementRemindersScreenState extends State<SupplementRemindersScreen> {
  static const Color primaryColor = AppColors.primary;

  List<Map<String, dynamic>> _reminders = [];

  bool _isLoading = true;
  bool _isSaving = false;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  Future<void> _loadReminders() async {
    setState(() {
      _isLoading = true;
      _loadFailed = false;
    });

    try {
      final reminders = await MaternalHealthService.getSupplementReminders();

      if (!mounted) return;

      setState(() {
        _reminders = reminders;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _reminders = [];
        _loadFailed = true;
      });

      _showMessage('Unable to load supplement reminders.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _formatDateTime(DateTime date) {
    final local = date.toLocal();

    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');

    final time = TimeOfDay.fromDateTime(local).format(context);

    return '$day/$month/${local.year} - $time';
  }

  Future<void> _showReminderDialog({
    Map<String, dynamic>? reminder,
  }) async {
    if (_isSaving) return;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _SupplementReminderDialog(
        reminder: reminder,
      ),
    );

    if (result == null || !mounted) return;

    setState(() => _isSaving = true);

    try {
      if (reminder != null) {
        await MaternalHealthService.updateSupplementReminder(
          id: reminder['id'].toString(),
          title: result['title'] as String,
          remindAt: result['remind_at'] as DateTime,
          notes: result['notes'] as String,
        );
      } else {
        await MaternalHealthService.addSupplementReminder(
          title: result['title'] as String,
          remindAt: result['remind_at'] as DateTime,
          notes: result['notes'] as String,
        );
      }

      if (!mounted) return;

      _showMessage(
        reminder != null
            ? 'Supplement reminder updated successfully.'
            : 'Supplement reminder saved successfully.',
      );

      await _loadReminders();
    } catch (_) {
      _showMessage(
        'Unable to save supplement reminder. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _deleteReminder(
    Map<String, dynamic> reminder,
  ) async {
    if (_isSaving) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete supplement reminder?'),
          content: const Text(
            'This supplement reminder will be permanently deleted.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.error,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isSaving = true);

    try {
      await MaternalHealthService.deleteSupplementReminder(
        reminder['id'].toString(),
      );

      if (!mounted) return;

      _showMessage(
        'Supplement reminder deleted successfully.',
      );

      await _loadReminders();
    } catch (_) {
      _showMessage(
        'Unable to delete supplement reminder.',
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Supplement Reminders'),
        actions: [
          IconButton(
            tooltip: 'Refresh reminders',
            onPressed: _isLoading || _isSaving ? null : _loadReminders,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: primaryColor,
              ),
            )
          : RefreshIndicator(
              onRefresh: () async {
                if (!_isSaving) {
                  await _loadReminders();
                }
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 800,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 20),
                        _buildSafetyNote(),
                        const SizedBox(height: 20),
                        _buildSummary(),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: primaryColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed:
                                _isSaving ? null : () => _showReminderDialog(),
                            icon: const Icon(Icons.add_rounded),
                            label: Text(
                              _isSaving
                                  ? 'Please wait...'
                                  : 'Add Supplement Reminder',
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Your Supplement Reminders',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        if (_loadFailed)
                          Center(
                            child: Column(
                              children: [
                                const Text(
                                  'Unable to load reminders.',
                                ),
                                TextButton(
                                  onPressed: _isSaving ? null : _loadReminders,
                                  child: const Text('Try again'),
                                ),
                              ],
                            ),
                          )
                        else if (_reminders.isEmpty)
                          _buildEmptyState()
                        else
                          ..._reminders.map(
                            _buildReminderCard,
                          ),
                        const SizedBox(height: 24),
                        _buildDisclaimer(),
                        const SizedBox(height: 104),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppColors.elevatedShadow,
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.medication_rounded,
            color: Colors.white,
            size: 44,
          ),
          SizedBox(height: 16),
          Text(
            'Stay on Track with Your Supplements',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Organize reminders for supplements '
            'prescribed by your healthcare professional.',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSafetyNote() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.health_and_safety_outlined,
            color: AppColors.warning,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Take supplements only as advised by your '
              'healthcare professional. Do not change your '
              'prescribed dosage or schedule without consultation.',
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: Color(0xFF805500),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    if (_loadFailed) {
      return const Text('Reminder summary unavailable.');
    }

    final now = DateTime.now();

    final upcoming = _reminders.where((reminder) {
      final date = DateTime.tryParse(
        reminder['remind_at'].toString(),
      );

      return date != null && date.isAfter(now);
    }).length;

    final past = _reminders.where((reminder) {
      final date = DateTime.tryParse(
        reminder['remind_at'].toString(),
      );

      return date != null && !date.isAfter(now);
    }).length;

    return Row(
      children: [
        Expanded(
          child: _summaryCard(
            'Total',
            _reminders.length.toString(),
            Icons.medication_rounded,
            primaryColor,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _summaryCard(
            'Upcoming',
            upcoming.toString(),
            Icons.event_available_rounded,
            AppColors.secondary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _summaryCard(
            'Past',
            past.toString(),
            Icons.history_rounded,
            AppColors.warning,
          ),
        ),
      ],
    );
  }

  Widget _summaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 18,
        horizontal: 8,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkSurface
            : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.darkBorder
              : AppColors.borderSubtle,
        ),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderCard(
    Map<String, dynamic> reminder,
  ) {
    final date = DateTime.tryParse(
      reminder['remind_at'].toString(),
    );

    final isUpcoming = date != null && date.isAfter(DateTime.now());

    final notes = reminder['notes']?.toString() ?? '';

    final statusColor = date == null
        ? Colors.grey
        : isUpcoming
            ? AppColors.secondary
            : AppColors.warning;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkSurface
            : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.darkBorder
              : AppColors.borderSubtle,
        ),
        boxShadow: AppColors.softShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.medication_rounded,
              color: primaryColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reminder['title']?.toString() ?? 'Supplement Reminder',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  date == null ? 'Date unavailable' : _formatDateTime(date),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Prescribed instructions / Notes',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(notes),
                ],
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(
                      alpha: 0.10,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    date == null
                        ? 'Unknown'
                        : isUpcoming
                            ? 'Upcoming'
                            : 'Past',
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            enabled: !_isSaving,
            onSelected: (value) {
              if (value == 'edit') {
                _showReminderDialog(
                  reminder: reminder,
                );
              } else if (value == 'delete') {
                _deleteReminder(reminder);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'edit',
                child: Text('Edit'),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Text(
                  'Delete',
                  style: TextStyle(color: AppColors.error),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkSurface
            : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.darkBorder
              : AppColors.borderSubtle,
        ),
        boxShadow: AppColors.softShadow,
      ),
      child: const Column(
        children: [
          Icon(
            Icons.medication_outlined,
            size: 56,
            color: primaryColor,
          ),
          SizedBox(height: 16),
          Text(
            'No supplement reminders yet',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Add your first prescribed supplement reminder '
            'to organize your schedule.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkSurfaceElevated
            : AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            color: primaryColor,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'MedMate helps organize prescribed supplement '
              'reminders. Each reminder represents a single '
              'scheduled date and time. Notification delivery '
              'depends on permissions and platform support. '
              'Browser reminders require MedMate to remain open. '
              'Recurring schedules are not yet enabled.',
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// ADD / EDIT SUPPLEMENT REMINDER DIALOG
// ==========================================

class _SupplementReminderDialog extends StatefulWidget {
  const _SupplementReminderDialog({
    this.reminder,
  });

  final Map<String, dynamic>? reminder;

  @override
  State<_SupplementReminderDialog> createState() =>
      _SupplementReminderDialogState();
}

class _SupplementReminderDialogState extends State<_SupplementReminderDialog> {
  static const Color primaryColor = AppColors.primary;

  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _notesController;

  DateTime? _selectedDateTime;
  String? _dateError;

  @override
  void initState() {
    super.initState();

    _titleController = TextEditingController(
      text: widget.reminder?['title']?.toString() ?? '',
    );

    _notesController = TextEditingController(
      text: widget.reminder?['notes']?.toString() ?? '',
    );

    _selectedDateTime = widget.reminder == null
        ? null
        : DateTime.tryParse(
            widget.reminder!['remind_at'].toString(),
          )?.toLocal();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String _formatDateTime(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    final time = TimeOfDay.fromDateTime(date).format(context);

    return '$day/$month/${date.year} - $time';
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();

    final today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final lastDate = DateTime(
      now.year + 5,
      now.month,
      now.day,
    );

    var initialDate = _selectedDateTime ?? now;

    if (initialDate.isBefore(today) || initialDate.isAfter(lastDate)) {
      initialDate = today;
    }

    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: today,
      lastDate: lastDate,
    );

    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: _selectedDateTime == null
          ? TimeOfDay.now()
          : TimeOfDay.fromDateTime(
              _selectedDateTime!,
            ),
    );

    if (time == null || !mounted) return;

    setState(() {
      _selectedDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );

      _dateError = null;
    });
  }

  void _submit() {
    final valid = _formKey.currentState!.validate();

    final dateTime = _selectedDateTime;

    String? error;

    if (dateTime == null) {
      error = 'Please select a date and time.';
    } else if (!dateTime.isAfter(DateTime.now())) {
      error = 'Please select a future date and time.';
    }

    setState(() {
      _dateError = error;
    });

    if (!valid || error != null || dateTime == null) {
      return;
    }

    Navigator.pop(context, {
      'title': _titleController.text.trim(),
      'notes': _notesController.text.trim(),
      'remind_at': dateTime,
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.reminder != null;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Text(
        isEditing ? 'Edit Supplement Reminder' : 'Add Supplement Reminder',
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _titleController,
                  maxLength: 120,
                  decoration: const InputDecoration(
                    labelText: 'Supplement name',
                    hintText: 'Enter prescribed supplement',
                    prefixIcon: Icon(
                      Icons.medication_rounded,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a supplement name.';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesController,
                  maxLines: 3,
                  maxLength: 1000,
                  decoration: const InputDecoration(
                    labelText: 'Prescribed instructions / Notes',
                    hintText: 'Enter instructions from your doctor',
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(
                      Icons.calendar_month_rounded,
                    ),
                    label: Text(
                      _selectedDateTime == null
                          ? 'Select date and time'
                          : _formatDateTime(
                              _selectedDateTime!,
                            ),
                    ),
                    onPressed: _pickDateTime,
                  ),
                ),
                if (_dateError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _dateError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                const Text(
                  'Enter only the supplement and instructions '
                  'recommended by your healthcare professional.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: primaryColor,
          ),
          onPressed: _submit,
          child: Text(
            isEditing ? 'Update' : 'Save',
          ),
        ),
      ],
    );
  }
}
