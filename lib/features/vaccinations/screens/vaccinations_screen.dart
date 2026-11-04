import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/auth_guard.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/app_exit_button.dart';

class VaccinationsScreen extends StatefulWidget {
  const VaccinationsScreen({super.key});

  @override
  State<VaccinationsScreen> createState() => _VaccinationsScreenState();
}

class _VaccinationsScreenState extends State<VaccinationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _vaccinations = [];
  List<Map<String, dynamic>> _familyMembers = [];
  String? _selectedFamilyMemberId; // null = All
  bool _loading = true;

  // Preset vaccination templates with standard recommended intervals
  static const List<Map<String, dynamic>> _vaccinePresets = [
    {
      'name': 'COVID-19 Booster',
      'dose': 3,
      'months': 6,
      'category': 'Adult / Child',
    },
    {
      'name': 'Influenza (Flu Shot)',
      'dose': 1,
      'months': 12,
      'category': 'Annual',
    },
    {
      'name': 'Tetanus / Tdap',
      'dose': 1,
      'months': 120, // 10 years
      'category': 'Booster',
    },
    {
      'name': 'Hepatitis B',
      'dose': 1,
      'months': 1,
      'category': 'Course (3 Doses)',
    },
    {
      'name': 'MMR (Measles, Mumps, Rubella)',
      'dose': 1,
      'months': 1,
      'category': 'Pediatric / Adult',
    },
    {
      'name': 'HPV (Human Papillomavirus)',
      'dose': 1,
      'months': 6,
      'category': 'Adolescent',
    },
    {
      'name': 'Polio (IPV)',
      'dose': 1,
      'months': 2,
      'category': 'Pediatric',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        SupabaseService.getVaccinations(),
        SupabaseService.getFamilyMembers(),
      ]);
      setState(() {
        _vaccinations = results[0];
        _familyMembers = results[1];
      });
    } catch (e) {
      debugPrint('Error loading vaccinations: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredVaccinations {
    if (_selectedFamilyMemberId == null) return _vaccinations;
    if (_selectedFamilyMemberId == 'self') {
      return _vaccinations.where((v) => v['family_member_id'] == null).toList();
    }
    return _vaccinations
        .where((v) => v['family_member_id'] == _selectedFamilyMemberId)
        .toList();
  }

  List<Map<String, dynamic>> get _upcomingVaccinations {
    final now = DateTime.now();
    return _filteredVaccinations.where((v) {
      final next = v['next_due_date'] as String?;
      if (next == null) return false;
      return true; // Any with next due date to track
    }).toList()
      ..sort((a, b) {
        final da = DateTime.tryParse(a['next_due_date'] ?? '') ?? now;
        final db = DateTime.tryParse(b['next_due_date'] ?? '') ?? now;
        return da.compareTo(db);
      });
  }

  List<Map<String, dynamic>> get _completedVaccinations {
    return _filteredVaccinations.where((v) {
      final admin = v['administered_date'] as String?;
      return admin != null;
    }).toList()
      ..sort((a, b) {
        final da = DateTime.tryParse(a['administered_date'] ?? '') ?? DateTime.now();
        final db = DateTime.tryParse(b['administered_date'] ?? '') ?? DateTime.now();
        return db.compareTo(da); // Most recent first
      });
  }

  Future<void> _showAddDialog({Map<String, dynamic>? editVaccine}) async {
    final nameCtrl = TextEditingController(text: editVaccine?['vaccine_name'] ?? '');
    final hospitalCtrl = TextEditingController(text: editVaccine?['hospital_clinic'] ?? '');
    final notesCtrl = TextEditingController(text: editVaccine?['notes'] ?? '');
    int doseNumber = editVaccine?['dose_number'] ?? 1;
    String? selectedMemberId = editVaccine?['family_member_id'];
    DateTime? adminDate = editVaccine?['administered_date'] != null
        ? DateTime.tryParse(editVaccine!['administered_date'])
        : DateTime.now();
    DateTime? nextDue = editVaccine?['next_due_date'] != null
        ? DateTime.tryParse(editVaccine!['next_due_date'])
        : null;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;

          return AlertDialog(
            backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.teal.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.vaccines_rounded, color: AppColors.teal, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    editVaccine == null ? 'Track New Vaccination' : 'Edit Vaccination',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: MediaQuery.of(ctx).size.width * 0.9,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Helper tracking tip banner
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'How tracking works: Setting a "Next Due Date" schedules automated alarm reminders and active countdowns.',
                              style: TextStyle(fontSize: 11, height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Quick-Pick Vaccine Templates
                    const Text(
                      'Quick Presets:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _vaccinePresets.map((preset) {
                          final isSelected = nameCtrl.text == preset['name'];
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ActionChip(
                              label: Text(preset['name'] as String),
                              labelStyle: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isSelected ? Colors.white : AppColors.teal,
                              ),
                              backgroundColor: isSelected
                                  ? AppColors.teal
                                  : AppColors.teal.withValues(alpha: 0.08),
                              side: BorderSide(
                                color: isSelected ? AppColors.teal : AppColors.teal.withValues(alpha: 0.3),
                              ),
                              onPressed: () {
                                setDlgState(() {
                                  nameCtrl.text = preset['name'] as String;
                                  doseNumber = preset['dose'] as int;
                                  final months = preset['months'] as int;
                                  if (adminDate != null) {
                                    nextDue = DateTime(
                                      adminDate!.year,
                                      adminDate!.month + months,
                                      adminDate!.day,
                                    );
                                  }
                                });
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Vaccine Name
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Vaccine Name *',
                        hintText: 'e.g. Hepatitis B, Tdap, Flu',
                        prefixIcon: Icon(Icons.medication_liquid_outlined),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Family Member Picker (Who is this for?)
                    DropdownButtonFormField<String?>(
                      initialValue: selectedMemberId,
                      decoration: const InputDecoration(
                        labelText: 'Recipient / Person',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Myself (Primary User)'),
                        ),
                        ..._familyMembers.map((m) => DropdownMenuItem<String?>(
                              value: m['id'] as String,
                              child: Text('${m['full_name']} (${m['relationship'] ?? 'Family'})'),
                            )),
                      ],
                      onChanged: (val) => setDlgState(() => selectedMemberId = val),
                    ),
                    const SizedBox(height: 14),

                    // Dose Number Selector
                    Row(
                      children: [
                        const Text('Dose Number:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        const SizedBox(width: 12),
                        DropdownButton<int>(
                          value: doseNumber,
                          items: const [
                            DropdownMenuItem(value: 1, child: Text('Dose 1')),
                            DropdownMenuItem(value: 2, child: Text('Dose 2')),
                            DropdownMenuItem(value: 3, child: Text('Dose 3')),
                            DropdownMenuItem(value: 4, child: Text('Booster 1')),
                            DropdownMenuItem(value: 5, child: Text('Booster 2')),
                            DropdownMenuItem(value: 6, child: Text('Annual Dose')),
                          ],
                          onChanged: (val) {
                            if (val != null) setDlgState(() => doseNumber = val);
                          },
                        ),
                      ],
                    ),
                    const Divider(height: 24),

                    // Date Administered (Given)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.check_circle_outline_rounded, color: AppColors.secondary),
                      title: const Text('Administered Date (Given)', style: TextStyle(fontSize: 13)),
                      subtitle: Text(
                        adminDate == null
                            ? 'Not given yet'
                            : DateFormat('d MMM yyyy').format(adminDate!),
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (adminDate != null)
                            IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () => setDlgState(() => adminDate = null),
                            ),
                          const Icon(Icons.calendar_today_rounded, size: 18),
                        ],
                      ),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: adminDate ?? DateTime.now(),
                          firstDate: DateTime(1980),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) setDlgState(() => adminDate = picked);
                      },
                    ),

                    // Next Due Date (The Tracker Target)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.alarm_rounded, color: AppColors.primary),
                      title: const Text('Next Due Date (For Tracker & Reminders)', style: TextStyle(fontSize: 13)),
                      subtitle: Text(
                        nextDue == null
                            ? 'Tap to set due date'
                            : DateFormat('d MMM yyyy').format(nextDue!),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: nextDue != null ? AppColors.primary : AppColors.textSecondary,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (nextDue != null)
                            IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () => setDlgState(() => nextDue = null),
                            ),
                          const Icon(Icons.calendar_month_rounded, size: 18),
                        ],
                      ),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: nextDue ?? DateTime.now().add(const Duration(days: 30)),
                          firstDate: DateTime.now().subtract(const Duration(days: 30)),
                          lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
                        );
                        if (picked != null) setDlgState(() => nextDue = picked);
                      },
                    ),

                    const SizedBox(height: 10),
                    // Hospital / Clinic
                    TextField(
                      controller: hospitalCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Hospital / Clinic (Optional)',
                        hintText: 'e.g. Apollo Hospital, City Health Center',
                        prefixIcon: Icon(Icons.local_hospital_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Notes
                    TextField(
                      controller: notesCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Notes / Batch Number (Optional)',
                        hintText: 'e.g. Batch #VX-902, no side effects',
                        prefixIcon: Icon(Icons.notes_rounded),
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  if (nameCtrl.text.trim().isEmpty) return;
                  final userId = await AuthGuard.requireUserId(context);
                  if (userId == null) return;

                  final payload = {
                    'user_id': userId,
                    'vaccine_name': nameCtrl.text.trim(),
                    'family_member_id': selectedMemberId,
                    'dose_number': doseNumber,
                    'hospital_clinic': hospitalCtrl.text.trim().isEmpty ? null : hospitalCtrl.text.trim(),
                    'administered_date': adminDate != null ? DateFormat('yyyy-MM-dd').format(adminDate!) : null,
                    'next_due_date': nextDue != null ? DateFormat('yyyy-MM-dd').format(nextDue!) : null,
                    'notes': notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                  };

                  if (editVaccine != null) {
                    await SupabaseService.updateVaccination(editVaccine['id'], payload);
                  } else {
                    final inserted = await SupabaseService.addVaccination(payload);

                    // If a next due date was provided, schedule an automatic reminder notification!
                    if (nextDue != null) {
                      final notifId = (inserted['id'].hashCode ^ 8888) & 0x7FFFFFFF;
                      String? patientName;
                      if (selectedMemberId != null) {
                        final m = _familyMembers.cast<Map<String, dynamic>?>().firstWhere(
                          (element) => element?['id'] == selectedMemberId,
                          orElse: () => null,
                        );
                        patientName = m?['full_name'];
                      }
                      await NotificationService.scheduleVaccinationReminder(
                        id: notifId,
                        vaccineName: nameCtrl.text.trim(),
                        dueDate: nextDue!,
                        patientName: patientName,
                      );
                    }
                  }

                  if (ctx.mounted) Navigator.pop(ctx);
                  _load();

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          nextDue != null
                              ? 'Vaccination saved! Countdown active & reminder scheduled for ${DateFormat('d MMM yyyy').format(nextDue!)}.'
                              : 'Vaccination saved to history.',
                        ),
                        backgroundColor: AppColors.primary,
                      ),
                    );
                  }
                },
                child: const Text('Save & Track'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _markAsGiven(Map<String, dynamic> v) async {
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final curDose = v['dose_number'] as int? ?? 1;

    // Show dialog to optionally schedule the next dose / booster
    DateTime? nextDoseDate;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Dose $curDose Administered ✓'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Marking "${v['vaccine_name']}" as completed today ($todayStr).'),
              const SizedBox(height: 16),
              const Text('Would you like to schedule the next dose / booster?',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.alarm_add_rounded, color: AppColors.primary),
                title: Text(
                  nextDoseDate == null
                      ? 'Select Next Due Date (Optional)'
                      : DateFormat('d MMM yyyy').format(nextDoseDate!),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                trailing: const Icon(Icons.calendar_today_rounded),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: now.add(const Duration(days: 30)),
                    firstDate: now,
                    lastDate: now.add(const Duration(days: 365 * 10)),
                  );
                  if (picked != null) setDlgState(() => nextDoseDate = picked);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await SupabaseService.updateVaccination(v['id'], {
                  'administered_date': todayStr,
                  'next_due_date': nextDoseDate != null ? DateFormat('yyyy-MM-dd').format(nextDoseDate!) : null,
                  'dose_number': nextDoseDate != null ? curDose + 1 : curDose,
                });

                if (nextDoseDate != null) {
                  final notifId = (v['id'].hashCode ^ 8888) & 0x7FFFFFFF;
                  await NotificationService.scheduleVaccinationReminder(
                    id: notifId,
                    vaccineName: v['vaccine_name'] ?? 'Vaccine',
                    dueDate: nextDoseDate!,
                  );
                } else {
                  await NotificationService.cancelVaccinationReminder(v['id']);
                }

                _load();
              },
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteVaccine(Map<String, dynamic> v) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Vaccination?'),
        content: Text('Remove "${v['vaccine_name']}" from your tracker?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await NotificationService.cancelVaccinationReminder(v['id']);
      await SupabaseService.deleteVaccination(v['id']);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        leading: const AppExitButton(fallbackRoute: '/home'),
        title: const Text('Vaccination Tracker'),
        actions: [
          IconButton(
            tooltip: 'Add Vaccine',
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _showAddDialog(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.teal,
          unselectedLabelColor: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
          indicatorColor: AppColors.teal,
          tabs: [
            Tab(text: 'Due (${_upcomingVaccinations.length})'),
            Tab(text: 'History (${_completedVaccinations.length})'),
            Tab(text: 'All (${_filteredVaccinations.length})'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Family Member Filter Chips
                if (_familyMembers.isNotEmpty)
                  Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _memberChip('All', null),
                        const SizedBox(width: 8),
                        _memberChip('Myself', 'self'),
                        const SizedBox(width: 8),
                        ..._familyMembers.map((m) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _memberChip(
                                '${m['full_name']} (${m['relationship'] ?? 'Family'})',
                                m['id'] as String,
                              ),
                            )),
                      ],
                    ),
                  ),

                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Tab 1: Due & Upcoming
                      _buildListTab(_upcomingVaccinations, isUpcomingTab: true),
                      // Tab 2: Completed / History
                      _buildListTab(_completedVaccinations, isUpcomingTab: false),
                      // Tab 3: All
                      _buildListTab(_filteredVaccinations, isUpcomingTab: false),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(),
        backgroundColor: AppColors.teal,
        icon: const Icon(Icons.add_rounded, size: 22, color: Colors.white),
        label: const Text('Add Vaccine', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
      ),
    );
  }

  Widget _memberChip(String label, String? memberId) {
    final isSelected = _selectedFamilyMemberId == memberId;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedFamilyMemberId = memberId),
      selectedColor: AppColors.teal.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? AppColors.teal : AppColors.textSecondary,
      ),
    );
  }

  Widget _buildListTab(List<Map<String, dynamic>> items, {required bool isUpcomingTab}) {
    if (items.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              EmptyState(
                icon: Icons.vaccines_outlined,
                title: isUpcomingTab ? 'No Upcoming Vaccinations Due' : 'No Vaccinations Recorded',
                subtitle: isUpcomingTab
                    ? 'All doses are up to date! Tap "+ Add Vaccine" to track your next dose or booster.'
                    : 'Track vaccine courses, dosages, dates, and get automatic reminders on your phone.',
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add New Vaccination'),
                onPressed: () => _showAddDialog(),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (ctx, i) => _vaccinationCard(items[i]),
      ),
    );
  }

  Widget _vaccinationCard(Map<String, dynamic> v) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final adminDate = v['administered_date'] != null
        ? DateTime.tryParse(v['administered_date'])
        : null;
    final nextDue = v['next_due_date'] != null
        ? DateTime.tryParse(v['next_due_date'])
        : null;
    final doseNum = v['dose_number'] ?? 1;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final daysLeft = nextDue != null
        ? DateTime(nextDue.year, nextDue.month, nextDue.day).difference(today).inDays
        : null;

    final isOverdue = daysLeft != null && daysLeft < 0;
    final isDueSoon = daysLeft != null && daysLeft >= 0 && daysLeft <= 14;

    // Recipient label
    String recipientLabel = 'Self';
    if (v['family_member_id'] != null) {
      final m = _familyMembers.cast<Map<String, dynamic>?>().firstWhere(
            (element) => element?['id'] == v['family_member_id'],
            orElse: () => null,
          );
      if (m != null) {
        recipientLabel = '${m['full_name']} (${m['relationship'] ?? 'Family'})';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOverdue
              ? AppColors.error.withValues(alpha: 0.5)
              : (isDueSoon
                  ? AppColors.warning.withValues(alpha: 0.5)
                  : (isDark ? AppColors.darkBorder : AppColors.borderSubtle)),
          width: (isOverdue || isDueSoon) ? 1.5 : 1,
        ),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.teal.withValues(alpha: 0.25),
                      AppColors.teal.withValues(alpha: 0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.teal.withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.vaccines_rounded, color: AppColors.teal, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            v['vaccine_name'] ?? 'Vaccine',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                            ),
                          ),
                        ),
                        // Dose Tag
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.teal.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Dose $doseNum',
                            style: const TextStyle(
                              color: AppColors.teal,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Recipient chip
                    Row(
                      children: [
                        const Icon(Icons.person_pin_rounded, size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          recipientLabel,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Tracking Status & Dates
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (adminDate != null)
                      _dateRow(
                        Icons.check_circle_rounded,
                        'Given: ${DateFormat('d MMM yyyy').format(adminDate)}',
                        AppColors.secondary,
                      ),
                    if (nextDue != null) ...[
                      const SizedBox(height: 6),
                      _dateRow(
                        Icons.alarm_rounded,
                        'Next Due: ${DateFormat('d MMM yyyy').format(nextDue)}',
                        isOverdue
                            ? AppColors.error
                            : (isDueSoon ? AppColors.warning : AppColors.primary),
                      ),
                    ],
                    if (v['hospital_clinic'] != null && (v['hospital_clinic'] as String).isNotEmpty) ...[
                      const SizedBox(height: 6),
                      _dateRow(
                        Icons.local_hospital_outlined,
                        v['hospital_clinic'],
                        AppColors.textSecondary,
                      ),
                    ],
                  ],
                ),
              ),

              // Countdown Badge
              if (daysLeft != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isOverdue
                        ? AppColors.error.withValues(alpha: 0.12)
                        : (isDueSoon
                            ? AppColors.warning.withValues(alpha: 0.12)
                            : AppColors.primary.withValues(alpha: 0.1)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        isOverdue
                            ? '${daysLeft.abs()}'
                            : (daysLeft == 0 ? 'Today' : '$daysLeft'),
                        style: TextStyle(
                          fontSize: daysLeft == 0 ? 14 : 18,
                          fontWeight: FontWeight.w800,
                          color: isOverdue
                              ? AppColors.error
                              : (isDueSoon ? AppColors.warning : AppColors.primary),
                        ),
                      ),
                      Text(
                        isOverdue
                            ? 'days late'
                            : (daysLeft == 0 ? 'Due' : 'days left'),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isOverdue
                              ? AppColors.error
                              : (isDueSoon ? AppColors.warning : AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          if (v['notes'] != null && (v['notes'] as String).isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBackground : AppColors.backgroundSecondary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      v['notes'],
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),
          // Action Buttons: Mark Given / Edit / Delete
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (nextDue != null && (adminDate == null || nextDue.isAfter(adminDate)))
                TextButton.icon(
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 16, color: AppColors.secondary),
                  label: const Text('Mark Taken', style: TextStyle(color: AppColors.secondary, fontWeight: FontWeight.w700, fontSize: 12)),
                  onPressed: () => _markAsGiven(v),
                ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.textSecondary),
                tooltip: 'Edit',
                onPressed: () => _showAddDialog(editVaccine: v),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
                tooltip: 'Delete',
                onPressed: () => _deleteVaccine(v),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dateRow(IconData icon, String label, Color color) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
}
