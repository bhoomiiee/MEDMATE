import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/empty_state.dart';
import '../widgets/medicine_card.dart';

class MedicinesListScreen extends StatefulWidget {
  const MedicinesListScreen({super.key});

  @override
  State<MedicinesListScreen> createState() => _MedicinesListScreenState();
}

class _MedicinesListScreenState extends State<MedicinesListScreen> {
  List<Map<String, dynamic>> _medicines = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  String _search = '';
  String _filterForm = 'All';

  final List<String> _formFilters = [
    'All', 'tablet', 'capsule', 'syrup', 'drops', 'cream', 'inhaler', 'other'
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await SupabaseService.getUserMedicines();
      setState(() {
        _medicines = data;
        _applyFilter();
      });
    } catch (e) {
      debugPrint('Load medicines error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilter() {
    _filtered = _medicines.where((m) {
      final nameMatch = _search.isEmpty ||
          (m['name'] as String).toLowerCase().contains(_search.toLowerCase());
      final formMatch = _filterForm == 'All' || m['form'] == _filterForm;
      return nameMatch && formMatch;
    }).toList();
  }

  Future<void> _delete(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Remove Medicine?'),
        content: const Text(
            'This will deactivate the medicine and its reminders.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(true),
              child: const Text('Remove',
                  style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (confirm == true) {
      await SupabaseService.deleteMedicine(id);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            const Text('My Medicines'),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_medicines.length}',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () => showSearch(
              context: context,
              delegate: _MedicineSearchDelegate(_medicines, context),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => context.go('/medicines/add'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() {
                _search = v;
                _applyFilter();
              }),
              decoration: InputDecoration(
                hintText: 'Search by medicine name...',
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => setState(() {
                          _search = '';
                          _applyFilter();
                        }),
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
          // Form filter chips
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              itemCount: _formFilters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final f = _formFilters[i];
                final selected = _filterForm == f;
                return GestureDetector(
                  onTap: () => setState(() {
                    _filterForm = f;
                    _applyFilter();
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary
                          : (isDark ? AppColors.darkSurface : AppColors.surface),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected
                            ? AppColors.primary
                            : (isDark ? AppColors.darkBorder : AppColors.borderSubtle),
                      ),
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Text(
                      f == 'All' ? 'All' : _capitalize(f),
                      style: TextStyle(
                        color: selected
                            ? Colors.white
                            : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                        fontSize: 12,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // Count indicator
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 4),
            child: Row(
              children: [
                Text(
                  '${_filtered.length} medicine${_filtered.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? EmptyState(
                        icon: Icons.medication_outlined,
                        title: _search.isNotEmpty
                            ? 'No medicines found'
                            : 'No medicines added yet',
                        subtitle: _search.isNotEmpty
                            ? 'Try a different search term or category'
                            : 'Add your medicines to track dosage and receive timely alerts.',
                        actionLabel: _search.isEmpty ? 'Add Medicine' : null,
                        onAction: _search.isEmpty
                            ? () => context.go('/medicines/add')
                            : null,
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                          itemCount: _filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 2),
                          itemBuilder: (_, i) {
                            final med = _filtered[i];
                            return Slidable(
                              key: ValueKey(med['id']),
                              endActionPane: ActionPane(
                                motion: const DrawerMotion(),
                                children: [
                                  SlidableAction(
                                    onPressed: (_) => context.go(
                                        '/medicines/edit/${med['id']}'),
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    icon: Icons.edit_rounded,
                                    label: 'Edit',
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(16),
                                      bottomLeft: Radius.circular(16),
                                    ),
                                  ),
                                  SlidableAction(
                                    onPressed: (_) => _delete(med['id']),
                                    backgroundColor: AppColors.error,
                                    foregroundColor: Colors.white,
                                    icon: Icons.delete_rounded,
                                    label: 'Remove',
                                    borderRadius: const BorderRadius.only(
                                      topRight: Radius.circular(16),
                                      bottomRight: Radius.circular(16),
                                    ),
                                  ),
                                ],
                              ),
                              child: MedicineCard(
                                medicine: med,
                                onTap: () =>
                                    context.go('/medicines/${med['id']}'),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/medicines/add'),
        icon: const Icon(Icons.add_rounded, size: 22),
        label: const Text('Add Med', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class _MedicineSearchDelegate extends SearchDelegate {
  final List<Map<String, dynamic>> medicines;
  final BuildContext parentContext;
  _MedicineSearchDelegate(this.medicines, this.parentContext);

  @override
  List<Widget> buildActions(BuildContext context) =>
      [IconButton(icon: const Icon(Icons.clear), onPressed: () => query = '')];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
      icon: const Icon(Icons.arrow_back_ios_new_rounded),
      onPressed: () => close(context, null));

  @override
  Widget buildResults(BuildContext context) => _buildList(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildList(context);

  Widget _buildList(BuildContext context) {
    final results = medicines
        .where((m) =>
            (m['name'] as String).toLowerCase().contains(query.toLowerCase()))
        .toList();
    if (results.isEmpty) {
      return const Center(child: Text('No medicines found'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => MedicineCard(
        medicine: results[i],
        onTap: () {
          close(context, null);
          parentContext.go('/medicines/${results[i]['id']}');
        },
      ),
    );
  }
}
