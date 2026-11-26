import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../services/maternal_health_service.dart';

class PregnancyTrackerScreen extends StatefulWidget {
  const PregnancyTrackerScreen({super.key});

  @override
  State<PregnancyTrackerScreen> createState() => _PregnancyTrackerScreenState();
}

class _PregnancyTrackerScreenState extends State<PregnancyTrackerScreen> {
  final TextEditingController _notesController = TextEditingController();

  DateTime? _lmp;
  DateTime? _dueDate;

  bool _isLoading = true;
  bool _isSaving = false;
  String? _loadError;

  static const Color primaryColor = AppColors.primary;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final profile = await MaternalHealthService.getPregnancyProfile();

      if (!mounted) return;

      setState(() {
        if (profile != null) {
          _lmp = DateTime.tryParse(
            profile['last_menstrual_period'].toString(),
          );

          _dueDate = DateTime.tryParse(
            profile['expected_delivery_date'].toString(),
          );

          _notesController.text = profile['notes']?.toString() ?? '';
        }

        if (_lmp != null && _dueDate == null) {
          _dueDate = DateTime(
            _lmp!.year,
            _lmp!.month,
            _lmp!.day + 280,
          );
        }

        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _loadError = 'Unable to load pregnancy profile.';
      });
    }
  }

  int get pregnancyDays {
    if (_lmp == null) return 0;

    final now = DateTime.now();

    final today = DateTime.utc(
      now.year,
      now.month,
      now.day,
    );

    final start = DateTime.utc(
      _lmp!.year,
      _lmp!.month,
      _lmp!.day,
    );

    return today.difference(start).inDays.clamp(0, 999).toInt();
  }

  int get pregnancyWeek => pregnancyDays ~/ 7;

  int get remainingDays => pregnancyDays % 7;

  String get trimester {
    if (pregnancyWeek < 14) {
      return 'First Trimester';
    } else if (pregnancyWeek < 28) {
      return 'Second Trimester';
    }

    return 'Third Trimester';
  }

  double get progress {
    return (pregnancyDays / 280).clamp(0.0, 1.0).toDouble();
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Select date';

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  Future<void> _selectLmp() async {
    final now = DateTime.now();

    final selected = await showDatePicker(
      context: context,
      initialDate: _lmp ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      helpText: 'Select last menstrual period',
    );

    if (selected == null || !mounted) return;

    setState(() {
      _lmp = selected;
      _dueDate = DateTime(
        selected.year,
        selected.month,
        selected.day + 280,
      );
    });
  }

  Future<void> _selectDueDate() async {
    if (_lmp == null) {
      _showMessage('Please select your LMP first.');
      return;
    }

    final firstDate = DateTime(
      _lmp!.year,
      _lmp!.month,
      _lmp!.day + 1,
    );

    final lastDate = DateTime(
      _lmp!.year,
      _lmp!.month,
      _lmp!.day + 350,
    );

    final estimatedDate = DateTime(
      _lmp!.year,
      _lmp!.month,
      _lmp!.day + 280,
    );

    final currentDueDate = _dueDate ?? estimatedDate;

    final initialDate =
        currentDueDate.isBefore(firstDate) || currentDueDate.isAfter(lastDate)
            ? estimatedDate
            : currentDueDate;

    final selected = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: 'Select clinician-confirmed due date',
    );

    if (selected == null || !mounted) return;

    setState(() {
      _dueDate = selected;
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _saveProfile() async {
    if (_lmp == null) {
      _showMessage('Please select your last menstrual period.');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await MaternalHealthService.savePregnancyProfile(
        lastMenstrualPeriod: _lmp!,
        expectedDeliveryDate: _dueDate,
        notes: _notesController.text,
      );

      if (!mounted) return;

      _showMessage('Pregnancy profile saved successfully.');
    } catch (_) {
      _showMessage(
        'Unable to save pregnancy profile. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  List<String> get guidance {
    if (pregnancyWeek < 14) {
      return [
        'Arrange your initial antenatal checkup.',
        'Discuss prescribed supplements with your doctor.',
        'Maintain a balanced diet and adequate hydration.',
        'Avoid alcohol, tobacco and unapproved medicines.',
      ];
    } else if (pregnancyWeek < 28) {
      return [
        'Attend scheduled antenatal appointments.',
        'Discuss recommended screening with your doctor.',
        'Follow your prescribed supplement schedule.',
        'Stay active according to medical advice.',
      ];
    }

    return [
      'Continue regular antenatal checkups.',
      'Discuss delivery preparation with your doctor.',
      'Prepare your hospital bag and emergency contacts.',
      'Seek prompt medical advice for reduced fetal movement.',
    ];
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge,
      ),
    );
  }

  Widget _panel({required Widget child}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.borderSubtle,
        ),
        boxShadow: AppColors.softShadow,
      ),
      child: child,
    );
  }

  Widget _dateTile({
    required String title,
    required DateTime? date,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: primaryColor),
      title: Text(title),
      subtitle: Text(_formatDate(date)),
      trailing: const Icon(Icons.edit_calendar_rounded),
      onTap: _isSaving ? null : onTap,
    );
  }

  Widget _buildProgressCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppColors.elevatedShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Pregnancy Journey',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 18),
          if (_lmp == null)
            const Text(
              'Start by adding your pregnancy details.',
              style: TextStyle(color: AppColors.textPrimary),
            )
          else ...[
            Text(
              '$pregnancyWeek weeks, $remainingDays days',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 30,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              trimester,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                color: AppColors.textPrimary,
                backgroundColor: AppColors.primaryLight,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '${(progress * 100).round()}% of estimated '
              '40-week journey',
              style: const TextStyle(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Estimated delivery: ${_formatDate(_dueDate)}',
              style: const TextStyle(color: AppColors.textPrimary),
            ),
            if (pregnancyWeek >= 40) ...[
              const SizedBox(height: 12),
              const Text(
                'Please contact your maternity care team '
                'for guidance about your delivery date.',
                style: TextStyle(color: AppColors.textPrimary),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildGuidance() {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$trimester Guidance',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...guidance.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    color: primaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(item)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pregnancy Tracker'),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _loadError != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_loadError!),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: 180,
                        child: ElevatedButton(
                          onPressed: _loadProfile,
                          child: const Text('Retry'),
                        ),
                      ),
                    ],
                  ),
                )
              : SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      16,
                      20,
                      16,
                      110,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: 800,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildProgressCard(),
                            const SizedBox(height: 24),
                            _sectionTitle('Pregnancy Details'),
                            _panel(
                              child: Column(
                                children: [
                                  _dateTile(
                                    title: 'Last Menstrual Period',
                                    date: _lmp,
                                    icon: Icons.calendar_month,
                                    onTap: _selectLmp,
                                  ),
                                  const Divider(),
                                  _dateTile(
                                    title: 'Expected Delivery Date',
                                    date: _dueDate,
                                    icon: Icons.event_available,
                                    onTap: _selectDueDate,
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Dates and pregnancy weeks '
                                    'are estimates. Confirm '
                                    'pregnancy dating with your '
                                    'healthcare provider.',
                                    style: TextStyle(
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            if (_lmp != null) ...[
                              _sectionTitle(
                                'Pregnancy Guidance',
                              ),
                              _buildGuidance(),
                              const SizedBox(height: 24),
                            ],
                            _sectionTitle('Pregnancy Notes'),
                            _panel(
                              child: TextField(
                                controller: _notesController,
                                enabled: !_isSaving,
                                maxLines: 4,
                                decoration: InputDecoration(
                                  hintText: 'Add appointments, '
                                      'questions or personal notes...',
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton.icon(
                                onPressed: _isSaving ? null : _saveProfile,
                                icon: _isSaving
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.save_rounded,
                                      ),
                                label: Text(
                                  _isSaving
                                      ? 'Saving...'
                                      : 'Save Pregnancy Profile',
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            _panel(
                              child: const Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: primaryColor,
                                  ),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'MedMate provides general '
                                      'educational support and '
                                      'does not replace professional '
                                      'medical advice. Seek urgent '
                                      'medical care for severe '
                                      'symptoms or emergencies.',
                                      style: TextStyle(
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
    );
  }
}
