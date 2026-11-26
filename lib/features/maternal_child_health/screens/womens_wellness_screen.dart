import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

import '../services/maternal_health_service.dart';

class WomensWellnessScreen extends StatefulWidget {
  const WomensWellnessScreen({super.key});

  @override
  State<WomensWellnessScreen> createState() => _WomensWellnessScreenState();
}

class _WomensWellnessScreenState extends State<WomensWellnessScreen> {
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
      final reminders = await MaternalHealthService.getWellnessReminders();

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

      _showMessage('Unable to load wellness reminders.');
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

    final isEditing = reminder != null;

    final titleController = TextEditingController(
      text: reminder?['title']?.toString() ?? '',
    );

    final notesController = TextEditingController(
      text: reminder?['notes']?.toString() ?? '',
    );

    DateTime? selectedDateTime = reminder == null
        ? null
        : DateTime.tryParse(
            reminder['remind_at'].toString(),
          )?.toLocal();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                isEditing ? 'Edit Wellness Reminder' : 'Add Wellness Reminder',
              ),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: titleController,
                        maxLength: 120,
                        decoration: const InputDecoration(
                          labelText: 'Reminder title',
                          hintText: 'Example: Health check-up',
                          prefixIcon: Icon(Icons.edit_note),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: notesController,
                        maxLines: 3,
                        maxLength: 1000,
                        decoration: const InputDecoration(
                          labelText: 'Notes (optional)',
                        ),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        icon: const Icon(
                          Icons.calendar_month_rounded,
                        ),
                        label: Text(
                          selectedDateTime == null
                              ? 'Select date and time'
                              : _formatDateTime(
                                  selectedDateTime!,
                                ),
                        ),
                        onPressed: () async {
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

                          var initialDate = selectedDateTime ?? now;

                          if (initialDate.isBefore(today) ||
                              initialDate.isAfter(lastDate)) {
                            initialDate = today;
                          }

                          final date = await showDatePicker(
                            context: dialogContext,
                            initialDate: initialDate,
                            firstDate: today,
                            lastDate: lastDate,
                          );

                          if (date == null || !dialogContext.mounted) {
                            return;
                          }

                          final time = await showTimePicker(
                            context: dialogContext,
                            initialTime: selectedDateTime == null
                                ? TimeOfDay.now()
                                : TimeOfDay.fromDateTime(
                                    selectedDateTime!,
                                  ),
                          );

                          if (time == null || !dialogContext.mounted) {
                            return;
                          }

                          setDialogState(() {
                            selectedDateTime = DateTime(
                              date.year,
                              date.month,
                              date.day,
                              time.hour,
                              time.minute,
                            );
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: primaryColor,
                  ),
                  onPressed: () {
                    final title = titleController.text.trim();
                    final dateTime = selectedDateTime;

                    if (title.isEmpty) {
                      _showMessage(
                        'Please enter a reminder title.',
                      );
                      return;
                    }

                    if (dateTime == null) {
                      _showMessage(
                        'Please select a date and time.',
                      );
                      return;
                    }

                    if (!dateTime.isAfter(DateTime.now())) {
                      _showMessage(
                        'Please select a future date and time.',
                      );
                      return;
                    }

                    Navigator.pop(dialogContext, {
                      'title': title,
                      'notes': notesController.text.trim(),
                      'remind_at': dateTime,
                    });
                  },
                  child: Text(isEditing ? 'Update' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );

    // Allow the dialog closing animation to finish
    // before disposing its text controllers.
    await Future<void>.delayed(
      const Duration(milliseconds: 350),
    );

    titleController.dispose();
    notesController.dispose();

    if (result == null || !mounted) return;

    setState(() => _isSaving = true);

    try {
      if (isEditing) {
        await MaternalHealthService.updateWellnessReminder(
          id: reminder['id'].toString(),
          title: result['title'] as String,
          remindAt: result['remind_at'] as DateTime,
          notes: result['notes'] as String,
        );
      } else {
        await MaternalHealthService.addWellnessReminder(
          title: result['title'] as String,
          remindAt: result['remind_at'] as DateTime,
          notes: result['notes'] as String,
        );
      }

      if (!mounted) return;

      _showMessage(
        isEditing
            ? 'Reminder updated successfully.'
            : 'Reminder saved successfully.',
      );

      await _loadReminders();
    } catch (_) {
      _showMessage('Unable to save reminder. Please try again.');
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
          title: const Text('Delete reminder?'),
          content: const Text(
            'This wellness reminder will be permanently deleted.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
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
      await MaternalHealthService.deleteWellnessReminder(
        reminder['id'].toString(),
      );

      if (!mounted) return;

      _showMessage('Reminder deleted successfully.');

      await _loadReminders();
    } catch (_) {
      _showMessage('Unable to delete reminder.');
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
        title: const Text("Women's Wellness"),
        actions: [
          IconButton(
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
              onRefresh: _loadReminders,
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
                        const SizedBox(height: 24),
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
                                  : 'Add Wellness Reminder',
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Your Wellness Reminders',
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
                                  onPressed: _loadReminders,
                                  child: const Text('Try again'),
                                ),
                              ],
                            ),
                          )
                        else if (_reminders.isEmpty)
                          _buildEmptyState()
                        else
                          ..._reminders.map(_buildReminderCard),
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
            Icons.spa_rounded,
            color: Colors.white,
            size: 42,
          ),
          SizedBox(height: 16),
          Text(
            'Prioritize Your Well-being',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Organize your health check-ups, appointments '
            'and personal wellness routines.',
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
            Icons.notifications_rounded,
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
        color: Theme.of(context).cardTheme.color,
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
        color: Theme.of(context).cardTheme.color,
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
              Icons.notifications_active_rounded,
              color: primaryColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reminder['title']?.toString() ?? 'Wellness Reminder',
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
                  Text(notes),
                ],
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.10),
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
                _showReminderDialog(reminder: reminder);
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
        color: Theme.of(context).cardTheme.color,
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
            Icons.notifications_none_rounded,
            size: 56,
            color: primaryColor,
          ),
          SizedBox(height: 16),
          Text(
            'No wellness reminders yet',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Add your first reminder to organize '
            'your wellness routine.',
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
              'MedMate helps organize wellness reminders '
              'and does not replace professional medical advice. '
              'Notification delivery depends on device permissions '
              'and platform support. Browser reminders require '
              'MedMate to remain open.',
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
