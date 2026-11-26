import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';

import '../services/maternal_health_service.dart';

class ChildGrowthScreen extends StatefulWidget {
  const ChildGrowthScreen({super.key});

  @override
  State<ChildGrowthScreen> createState() => _ChildGrowthScreenState();
}

class _ChildGrowthScreenState extends State<ChildGrowthScreen> {
  static const Color primaryColor = AppColors.primary;

  List<Map<String, dynamic>> _children = [];
  List<Map<String, dynamic>> _records = [];

  String? _selectedChildId;

  bool _loading = true;
  bool _saving = false;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _loadChildren();
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _loadChildren() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
      _records = [];
    });

    try {
      final children = await MaternalHealthService.getChildProfiles();

      if (!mounted) return;

      final previousId = _selectedChildId;

      setState(() {
        _children = children;

        _selectedChildId = children.any(
          (child) => child['id'].toString() == previousId,
        )
            ? previousId
            : children.isEmpty
                ? null
                : children.first['id'].toString();
      });

      if (_selectedChildId != null) {
        await _loadRecords();
      }
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _children = [];
        _selectedChildId = null;
        _loadFailed = true;
      });

      _showMessage('Unable to load child profiles.');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadRecords() async {
    final childId = _selectedChildId;

    if (childId == null) return;

    setState(() {
      _loading = true;
      _loadFailed = false;
      _records = [];
    });

    try {
      final records = await MaternalHealthService.getChildGrowthRecords(
        childId,
      );

      if (!mounted || _selectedChildId != childId) return;

      setState(() => _records = records);
    } catch (_) {
      if (!mounted) return;

      setState(() => _loadFailed = true);

      _showMessage('Unable to load growth records.');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _formatDate(dynamic value) {
    final date = DateTime.tryParse(value.toString());

    if (date == null) return 'Date unavailable';

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  double? _number(dynamic value) {
    if (value == null) return null;

    final number = double.tryParse(value.toString());

    if (number == null || !number.isFinite || number <= 0) {
      return null;
    }

    return number;
  }

  String _measurement(dynamic value, String unit) {
    final number = _number(value);

    if (number == null) return 'Not recorded';

    final formatted = number == number.roundToDouble()
        ? number.toStringAsFixed(0)
        : number.toString();

    return '$formatted $unit';
  }

  double? _latestMeasurement(String field) {
    for (final record in _records) {
      final value = _number(record[field]);

      if (value != null) return value;
    }

    return null;
  }

  Future<void> _showRecordDialog({
    Map<String, dynamic>? record,
  }) async {
    final childId = _selectedChildId;

    if (childId == null || _saving || _loading) return;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _GrowthRecordDialog(
        record: record,
      ),
    );

    if (!mounted || result == null || _selectedChildId != childId) {
      return;
    }

    setState(() => _saving = true);

    try {
      if (record == null) {
        await MaternalHealthService.addChildGrowthRecord(
          childId: childId,
          recordedOn: result['recorded_on'] as DateTime,
          heightCm: result['height_cm'] as double?,
          weightKg: result['weight_kg'] as double?,
          notes: result['notes'] as String,
        );
      } else {
        await MaternalHealthService.updateChildGrowthRecord(
          id: record['id'].toString(),
          childId: childId,
          recordedOn: result['recorded_on'] as DateTime,
          heightCm: result['height_cm'] as double?,
          weightKg: result['weight_kg'] as double?,
          notes: result['notes'] as String,
        );
      }

      if (!mounted) return;

      _showMessage(
        record == null
            ? 'Growth record saved successfully.'
            : 'Growth record updated successfully.',
      );

      await _loadRecords();
    } catch (_) {
      _showMessage(
        'Unable to save growth record. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _deleteRecord(
    Map<String, dynamic> record,
  ) async {
    final childId = _selectedChildId;

    if (childId == null || _saving || _loading) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete growth record?'),
        content: const Text(
          'This measurement record will be permanently deleted.',
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
      ),
    );

    if (!mounted || confirmed != true || _selectedChildId != childId) {
      return;
    }

    setState(() => _saving = true);

    try {
      await MaternalHealthService.deleteChildGrowthRecord(
        id: record['id'].toString(),
        childId: childId,
      );

      if (!mounted) return;

      _showMessage('Growth record deleted successfully.');

      await _loadRecords();
    } catch (_) {
      _showMessage('Unable to delete growth record.');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Child Growth'),
        actions: [
          IconButton(
            tooltip: 'Refresh child profiles',
            onPressed: _loading || _saving ? null : _loadChildren,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: primaryColor,
              ),
            )
          : RefreshIndicator(
              onRefresh: () async {
                if (!_saving) {
                  await _loadChildren();
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
                        if (_loadFailed)
                          _buildError()
                        else if (_children.isEmpty)
                          _buildNoChildren()
                        else ...[
                          _buildChildSelector(),
                          const SizedBox(height: 20),
                          _buildSummary(),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: primaryColor,
                              ),
                              onPressed:
                                  _saving ? null : () => _showRecordDialog(),
                              icon: const Icon(Icons.add),
                              label: Text(
                                _saving
                                    ? 'Please wait...'
                                    : 'Add Growth Record',
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          _buildChart(
                            title: 'Height Growth History',
                            field: 'height_cm',
                            unit: 'cm',
                            color: AppColors.teal,
                          ),
                          const SizedBox(height: 16),
                          _buildChart(
                            title: 'Weight Growth History',
                            field: 'weight_kg',
                            unit: 'kg',
                            color: primaryColor,
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Growth Records (${_records.length})',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 12),
                          if (_records.isEmpty)
                            _buildEmptyRecords()
                          else
                            ..._records.map(_buildRecordCard),
                        ],
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
            Icons.child_care_rounded,
            size: 44,
            color: Colors.white,
          ),
          SizedBox(height: 16),
          Text(
            "Track Your Child's Growth",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Record height and weight measurements '
            'and view growth history over time.',
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChildSelector() {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Child Profile',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey(_selectedChildId),
            initialValue: _selectedChildId,
            isExpanded: true,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.person_outline),
            ),
            items: _children.map((child) {
              return DropdownMenuItem<String>(
                value: child['id'].toString(),
                child: Text(
                  "${child['full_name']} (${child['relation']})",
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: _saving
                ? null
                : (value) async {
                    if (value == null) return;

                    setState(() {
                      _selectedChildId = value;
                      _records = [];
                    });

                    await _loadRecords();
                  },
          ),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    return Row(
      children: [
        Expanded(
          child: _summaryCard(
            title: 'Latest Height',
            value: _measurement(
              _latestMeasurement('height_cm'),
              'cm',
            ),
            icon: Icons.straighten_rounded,
            color: AppColors.teal,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _summaryCard(
            title: 'Latest Weight',
            value: _measurement(
              _latestMeasurement('weight_kg'),
              'kg',
            ),
            icon: Icons.monitor_weight_outlined,
            color: primaryColor,
          ),
        ),
      ],
    );
  }

  Widget _summaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
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
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChart({
    required String title,
    required String field,
    required String unit,
    required Color color,
  }) {
    final points = _records.reversed.where((record) {
      return _number(record[field]) != null &&
          DateTime.tryParse(
                record['recorded_on'].toString(),
              ) !=
              null;
    }).toList();

    // Keep the latest 20 measurements for readability.
    final visiblePoints =
        points.length > 20 ? points.sublist(points.length - 20) : points;

    final spots = <FlSpot>[];

    for (var i = 0; i < visiblePoints.length; i++) {
      spots.add(
        FlSpot(
          i.toDouble(),
          _number(visiblePoints[i][field])!,
        ),
      );
    }

    return Container(
      width: double.infinity,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Recorded measurements ($unit)',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 20),
          if (spots.length < 2)
            const SizedBox(
              height: 100,
              child: Center(
                child: Text(
                  'Add at least two measurements '
                  'to display the trend.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: (spots.length - 1).toDouble(),
                  minY: 0,
                  gridData: const FlGridData(
                    show: true,
                    drawVerticalLine: false,
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: false,
                      ),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: false,
                      ),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 48,
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 34,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();

                          if (index < 0 ||
                              index >= visiblePoints.length ||
                              value != index.toDouble()) {
                            return const SizedBox.shrink();
                          }

                          final step = (visiblePoints.length / 4).ceil();

                          if (index % step != 0 &&
                              index != visiblePoints.length - 1) {
                            return const SizedBox.shrink();
                          }

                          final date = DateTime.parse(
                            visiblePoints[index]['recorded_on'].toString(),
                          );

                          return Padding(
                            padding: const EdgeInsets.only(
                              top: 8,
                            ),
                            child: Text(
                              '${date.day}/${date.month}',
                              style: const TextStyle(
                                fontSize: 10,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: false,
                      color: color,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: color.withValues(alpha: 0.10),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          const Text(
            'Latest 20 measurements, in recorded order. '
            'Horizontal spacing represents measurement sequence, '
            'not elapsed time.',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordCard(
    Map<String, dynamic> record,
  ) {
    final notes = record['notes']?.toString() ?? '';

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
          const Icon(
            Icons.calendar_month_rounded,
            color: primaryColor,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatDate(record['recorded_on']),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Height: ${_measurement(record['height_cm'], 'cm')}",
                ),
                const SizedBox(height: 4),
                Text(
                  "Weight: ${_measurement(record['weight_kg'], 'kg')}",
                ),
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Notes',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(notes),
                ],
              ],
            ),
          ),
          PopupMenuButton<String>(
            enabled: !_saving,
            onSelected: (value) {
              if (value == 'edit') {
                _showRecordDialog(record: record);
              } else if (value == 'delete') {
                _deleteRecord(record);
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

  Widget _buildNoChildren() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
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
          const Icon(
            Icons.family_restroom_rounded,
            size: 56,
            color: primaryColor,
          ),
          const SizedBox(height: 16),
          const Text(
            'No child profiles found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add a family member with the relationship '
            'Child or Grandchild to begin tracking growth.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: primaryColor,
            ),
            onPressed: () async {
              await context.push('/family');

              if (mounted) {
                await _loadChildren();
              }
            },
            icon: const Icon(Icons.person_add_rounded),
            label: const Text('Manage Family Profiles'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyRecords() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
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
            Icons.insights_rounded,
            size: 48,
            color: primaryColor,
          ),
          SizedBox(height: 12),
          Text(
            'No growth records yet',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Add the first height or weight measurement.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        children: [
          const Text('Unable to load growth information.'),
          TextButton(
            onPressed: _loadChildren,
            child: const Text('Try again'),
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
              'Growth charts display recorded measurements '
              'only. They do not represent clinical growth '
              'percentiles or diagnose health conditions. '
              'Consult a qualified healthcare professional '
              'for assessment of your child’s growth.',
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
// ADD / EDIT GROWTH RECORD DIALOG
// ==========================================

class _GrowthRecordDialog extends StatefulWidget {
  const _GrowthRecordDialog({this.record});

  final Map<String, dynamic>? record;

  @override
  State<_GrowthRecordDialog> createState() => _GrowthRecordDialogState();
}

class _GrowthRecordDialogState extends State<_GrowthRecordDialog> {
  static const Color primaryColor = AppColors.primary;

  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _heightController;
  late final TextEditingController _weightController;
  late final TextEditingController _notesController;

  late DateTime _recordedOn;

  String? _measurementError;

  @override
  void initState() {
    super.initState();

    _heightController = TextEditingController(
      text: widget.record?['height_cm']?.toString() ?? '',
    );

    _weightController = TextEditingController(
      text: widget.record?['weight_kg']?.toString() ?? '',
    );

    _notesController = TextEditingController(
      text: widget.record?['notes']?.toString() ?? '',
    );

    _recordedOn = DateTime.tryParse(
          widget.record?['recorded_on']?.toString() ?? '',
        ) ??
        DateTime.now();
  }

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    _notesController.dispose();

    super.dispose();
  }

  String? _validateNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final number = double.tryParse(value.trim());

    if (number == null || !number.isFinite || number <= 0) {
      return 'Enter a valid positive number.';
    }

    return null;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final firstDate = DateTime(1900);

    var initialDate = _recordedOn;

    if (initialDate.isAfter(today) || initialDate.isBefore(firstDate)) {
      initialDate = today;
    }

    final selected = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: today,
    );

    if (selected == null || !mounted) return;

    setState(() => _recordedOn = selected);
  }

  void _submit() {
    final valid = _formKey.currentState!.validate();

    final heightText = _heightController.text.trim();
    final weightText = _weightController.text.trim();

    final height = double.tryParse(heightText);
    final weight = double.tryParse(weightText);

    if (heightText.isEmpty && weightText.isEmpty) {
      setState(() {
        _measurementError = 'Please enter height or weight.';
      });

      return;
    }

    if (!valid) return;

    try {
      MaternalHealthService.validateChildGrowthRecord(
        recordedOn: _recordedOn,
        heightCm: height,
        weightKg: weight,
      );
    } on ArgumentError catch (error) {
      setState(() {
        _measurementError = error.message.toString();
      });

      return;
    }

    Navigator.pop(context, {
      'recorded_on': _recordedOn,
      'height_cm': height,
      'weight_kg': weight,
      'notes': _notesController.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.record != null;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Text(
        isEditing ? 'Edit Growth Record' : 'Add Growth Record',
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
                const Text(
                  'Enter at least one measurement.',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _heightController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Height (cm)',
                    prefixIcon: Icon(Icons.straighten),
                  ),
                  validator: _validateNumber,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _weightController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Weight (kg)',
                    prefixIcon: Icon(
                      Icons.monitor_weight_outlined,
                    ),
                  ),
                  validator: _validateNumber,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(
                      Icons.calendar_month_rounded,
                    ),
                    label: Text(
                      'Date: ${_recordedOn.day}/'
                      '${_recordedOn.month}/'
                      '${_recordedOn.year}',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesController,
                  maxLines: 3,
                  maxLength: 1000,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                  ),
                ),
                if (_measurementError != null)
                  Text(
                    _measurementError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12,
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
          child: Text(isEditing ? 'Update' : 'Save'),
        ),
      ],
    );
  }
}
