import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';

import '../services/maternal_health_service.dart';

class DevelopmentMilestonesScreen extends StatefulWidget {
  const DevelopmentMilestonesScreen({super.key});

  @override
  State<DevelopmentMilestonesScreen> createState() =>
      _DevelopmentMilestonesScreenState();
}

class _DevelopmentMilestonesScreenState
    extends State<DevelopmentMilestonesScreen> {
  static const Color primaryColor = AppColors.primary;

  List<Map<String, dynamic>> _children = [];
  List<Map<String, dynamic>> _milestones = [];

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
    if (!mounted) return;

    setState(() {
      _loading = true;
      _loadFailed = false;
      _milestones = [];
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
        await _loadMilestones();
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

  Future<void> _loadMilestones() async {
    final childId = _selectedChildId;

    if (childId == null || !mounted) return;

    setState(() {
      _loading = true;
      _loadFailed = false;
      _milestones = [];
    });

    try {
      final milestones = await MaternalHealthService.getChildMilestones(
        childId,
      );

      if (!mounted || _selectedChildId != childId) return;

      setState(() => _milestones = milestones);
    } catch (_) {
      if (!mounted) return;

      setState(() => _loadFailed = true);

      _showMessage('Unable to load milestones.');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _formatDate(dynamic value) {
    if (value == null) return 'Not recorded';

    final date = DateTime.tryParse(value.toString());

    if (date == null) return 'Date unavailable';

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  int get _achievedCount =>
      _milestones.where((item) => item['achieved_on'] != null).length;

  int get _pendingCount => _milestones.length - _achievedCount;

  Future<void> _showMilestoneDialog({
    Map<String, dynamic>? milestone,
  }) async {
    final childId = _selectedChildId;

    if (childId == null || _saving || _loading) return;

    final currentUserId = MaternalHealthService.userId;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _MilestoneDialog(
        milestone: milestone,
      ),
    );

    if (!mounted || result == null || _selectedChildId != childId) {
      return;
    }

    setState(() => _saving = true);

    try {
      if (MaternalHealthService.userId != currentUserId) {
        throw Exception('Login session changed.');
      }

      if (milestone == null) {
        await MaternalHealthService.addChildMilestone(
          childId: childId,
          title: result['title'] as String,
          achievedOn: result['achieved_on'] as DateTime?,
          notes: result['notes'] as String,
        );
      } else {
        await MaternalHealthService.updateChildMilestone(
          id: milestone['id'].toString(),
          childId: childId,
          title: result['title'] as String,
          achievedOn: result['achieved_on'] as DateTime?,
          notes: result['notes'] as String,
        );
      }

      if (!mounted) return;

      _showMessage(
        milestone == null
            ? 'Milestone saved successfully.'
            : 'Milestone updated successfully.',
      );

      await _loadMilestones();
    } catch (_) {
      _showMessage(
        'Unable to save milestone. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _deleteMilestone(
    Map<String, dynamic> milestone,
  ) async {
    final childId = _selectedChildId;

    if (childId == null || _saving || _loading) return;

    final currentUserId = MaternalHealthService.userId;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete milestone?'),
        content: Text(
          'The milestone "${milestone['title']}" '
          'will be permanently deleted.',
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
      if (MaternalHealthService.userId != currentUserId) {
        throw Exception('Login session changed.');
      }

      await MaternalHealthService.deleteChildMilestone(
        id: milestone['id'].toString(),
        childId: childId,
      );

      if (!mounted) return;

      _showMessage('Milestone deleted successfully.');

      await _loadMilestones();
    } catch (_) {
      _showMessage('Unable to delete milestone.');
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
        title: const Text('Development Milestones'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading || _saving ? null : _loadChildren,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
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
                  padding: const EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    120,
                  ),
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
                                onPressed: _saving
                                    ? null
                                    : () => _showMilestoneDialog(),
                                icon: const Icon(Icons.add),
                                label: Text(
                                  _saving ? 'Please wait...' : 'Add Milestone',
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Milestone History '
                              '(${_milestones.length})',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 12),
                            if (_milestones.isEmpty)
                              _buildEmptyMilestones()
                            else
                              ..._milestones.map(
                                _buildMilestoneCard,
                              ),
                          ],
                          const SizedBox(height: 24),
                          _buildDisclaimer(),
                        ],
                      ),
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
            Icons.insights_rounded,
            color: Colors.white,
            size: 44,
          ),
          SizedBox(height: 16),
          Text(
            'Every Little Step Matters',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            "Record and celebrate your child's "
            'developmental milestones.',
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
              fontSize: 16,
              fontWeight: FontWeight.bold,
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
                      _milestones = [];
                    });

                    await _loadMilestones();
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
            title: 'Total',
            count: _milestones.length,
            icon: Icons.list_alt_rounded,
            color: primaryColor,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _summaryCard(
            title: 'Achieved',
            count: _achievedCount,
            icon: Icons.check_circle_outline,
            color: AppColors.secondary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _summaryCard(
            title: 'Pending',
            count: _pendingCount,
            icon: Icons.schedule_rounded,
            color: AppColors.warning,
          ),
        ),
      ],
    );
  }

  Widget _summaryCard({
    required String title,
    required int count,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 16,
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
            count.toString(),
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

  Widget _buildMilestoneCard(
    Map<String, dynamic> milestone,
  ) {
    final achieved = milestone['achieved_on'] != null;

    final color = achieved ? AppColors.secondary : AppColors.warning;

    final notes = milestone['notes']?.toString() ?? '';

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
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              achieved ? Icons.check_circle_rounded : Icons.schedule_rounded,
              color: color,
              size: 26,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  milestone['title']?.toString() ?? 'Milestone',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    achieved ? 'Achieved' : 'Pending',
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  achieved
                      ? 'Achieved on: '
                          '${_formatDate(milestone['achieved_on'])}'
                      : 'Not yet recorded as achieved',
                  style: const TextStyle(fontSize: 13),
                ),
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'Notes',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(notes),
                ],
              ],
            ),
          ),
          PopupMenuButton<String>(
            enabled: !_saving,
            onSelected: (value) {
              if (value == 'edit') {
                _showMilestoneDialog(
                  milestone: milestone,
                );
              } else if (value == 'delete') {
                _deleteMilestone(milestone);
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
            'Add a Child or Grandchild family profile '
            'to begin recording milestones.',
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

  Widget _buildEmptyMilestones() {
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
            Icons.emoji_events_outlined,
            color: primaryColor,
            size: 48,
          ),
          SizedBox(height: 12),
          Text(
            'No milestones recorded yet',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Add a milestone to start recording '
            'your child’s developmental journey.',
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
          const Text('Unable to load milestones.'),
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
              'Milestones are personal observations, '
              'not clinical developmental assessments. '
              'Pending means an achievement date has not '
              'been recorded, not that a child is delayed. '
              'Consult a qualified healthcare professional '
              'for developmental concerns.',
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
// ADD / EDIT MILESTONE DIALOG
// ==========================================

class _MilestoneDialog extends StatefulWidget {
  const _MilestoneDialog({this.milestone});

  final Map<String, dynamic>? milestone;

  @override
  State<_MilestoneDialog> createState() => _MilestoneDialogState();
}

class _MilestoneDialogState extends State<_MilestoneDialog> {
  static const Color primaryColor = AppColors.primary;

  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _notesController;

  bool _achieved = false;

  DateTime? _achievedOn;

  String? _error;

  @override
  void initState() {
    super.initState();

    _titleController = TextEditingController(
      text: widget.milestone?['title']?.toString() ?? '',
    );

    _notesController = TextEditingController(
      text: widget.milestone?['notes']?.toString() ?? '',
    );

    _achievedOn = DateTime.tryParse(
      widget.milestone?['achieved_on']?.toString() ?? '',
    );

    _achieved = _achievedOn != null;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();

    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final firstDate = DateTime(1900);

    var initialDate = _achievedOn ?? today;

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

    setState(() {
      _achievedOn = selected;
      _error = null;
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    if (_achieved && _achievedOn == null) {
      setState(() {
        _error = 'Please select the achievement date.';
      });

      return;
    }

    final title = _titleController.text.trim();
    final notes = _notesController.text.trim();

    final achievedOn = _achieved ? _achievedOn : null;

    try {
      MaternalHealthService.validateChildMilestone(
        title: title,
        achievedOn: achievedOn,
        notes: notes,
      );
    } on ArgumentError catch (error) {
      setState(() {
        _error = error.message.toString();
      });

      return;
    }

    Navigator.pop(context, {
      'title': title,
      'achieved_on': achievedOn,
      'notes': notes,
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.milestone != null;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Text(
        isEditing ? 'Edit Milestone' : 'Add Milestone',
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
                    labelText: 'Milestone Title *',
                    hintText: 'e.g. First Steps',
                    prefixIcon: Icon(
                      Icons.emoji_events_outlined,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a milestone title.';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Achieved'),
                  subtitle: const Text(
                    'Record an achievement date',
                  ),
                  value: _achieved,
                  onChanged: (value) {
                    setState(() {
                      _achieved = value;
                      _error = null;

                      if (!value) {
                        _achievedOn = null;
                      }
                    });
                  },
                ),
                if (_achieved) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(
                        Icons.calendar_month_rounded,
                      ),
                      label: Text(
                        _achievedOn == null
                            ? 'Select Achievement Date'
                            : '${_achievedOn!.day}/'
                                '${_achievedOn!.month}/'
                                '${_achievedOn!.year}',
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesController,
                  maxLines: 3,
                  maxLength: 1000,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                  ),
                ),
                if (_error != null)
                  Text(
                    _error!,
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
