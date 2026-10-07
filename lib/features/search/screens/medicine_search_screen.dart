import 'package:flutter/material.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/empty_state.dart';

class MedicineSearchScreen extends StatefulWidget {
  const MedicineSearchScreen({super.key});

  @override
  State<MedicineSearchScreen> createState() => _MedicineSearchScreenState();
}

class _MedicineSearchScreenState extends State<MedicineSearchScreen> {
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  bool _hasSearched = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() { _results = []; _hasSearched = false; });
      return;
    }
    setState(() { _loading = true; _hasSearched = true; });
    try {
      final data = await SupabaseService.searchMedicineDatabase(query.trim());
      setState(() => _results = data);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Medicine Search'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              onChanged: (v) {
                if (v.length >= 2) _search(v);
                if (v.isEmpty) setState(() { _results = []; _hasSearched = false; });
              },
              decoration: InputDecoration(
                hintText: 'Search by medicine or generic name...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() { _results = []; _hasSearched = false; });
                        },
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (!_hasSearched)
            Expanded(child: _buildSuggestions())
          else if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_results.isEmpty)
            const Expanded(
              child: EmptyState(
                icon: Icons.search_off_rounded,
                title: 'No medicines found',
                subtitle: 'Try a different name or generic name',
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _results.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _resultCard(_results[i]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSuggestions() {
    final suggestions = [
      'Paracetamol', 'Amoxicillin', 'Metformin',
      'Omeprazole', 'Cetirizine', 'Vitamin D3',
      'Amlodipine', 'Iron Supplement',
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Common Searches',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: suggestions.map((s) => GestureDetector(
              onTap: () {
                _searchCtrl.text = s;
                _search(s);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: const Border.fromBorderSide(BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.search_rounded, size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 6),
                    Text(s, style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            )).toList(),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary.withOpacity(0.2)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Search our medicine database for information on usage, side effects, and precautions.',
                    style: TextStyle(fontSize: 13, color: AppColors.primary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultCard(Map<String, dynamic> med) {
    final name = med['name'] as String? ?? '';
    final generic = med['generic_name'] as String?;
    final category = med['category'] as String?;
    final form = med['form'] as String?;
    final requiresRx = med['requires_prescription'] as bool? ?? false;
    final uses = (med['uses'] as List?)?.cast<String>() ?? [];
    final sideEffects = (med['side_effects'] as List?)?.cast<String>() ?? [];
    final precautions = (med['precautions'] as List?)?.cast<String>() ?? [];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: const Border.fromBorderSide(BorderSide(color: AppColors.border)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.medication_rounded, color: AppColors.primary, size: 22),
          ),
          title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (generic != null)
                Text(generic, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 4),
              Row(
                children: [
                  if (category != null) _chip(category, AppColors.primarySurface, AppColors.primary),
                  if (form != null) ...[
                    const SizedBox(width: 6),
                    _chip(_capitalize(form), AppColors.surface, AppColors.textSecondary),
                  ],
                  if (requiresRx) ...[
                    const SizedBox(width: 6),
                    _chip('Rx', AppColors.errorSurface, AppColors.error),
                  ],
                ],
              ),
            ],
          ),
          children: [
            if (med['description'] != null) ...[
              _infoSection('Description', med['description'], Icons.info_outline_rounded, AppColors.primary),
            ],
            if (uses.isNotEmpty)
              _listSection('Uses', uses, Icons.check_circle_outline_rounded, AppColors.secondary),
            if (sideEffects.isNotEmpty)
              _listSection('Side Effects', sideEffects, Icons.warning_amber_outlined, AppColors.warning),
            if (precautions.isNotEmpty)
              _listSection('Precautions', precautions, Icons.shield_outlined, AppColors.error),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.warningSurface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '⚠️ This information is for reference only. Always consult your doctor or pharmacist.',
                style: TextStyle(fontSize: 11, color: AppColors.warning),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoSection(String title, String content, IconData icon, Color color) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: color, fontSize: 13)),
            ]),
            const SizedBox(height: 4),
            Text(content, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ],
        ),
      );

  Widget _listSection(String title, List<String> items, IconData icon, Color color) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: color, fontSize: 13)),
            ]),
            const SizedBox(height: 6),
            ...items.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• ', style: TextStyle(color: color, fontWeight: FontWeight.w700)),
                  Expanded(child: Text(s, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
                ],
              ),
            )),
          ],
        ),
      );

  Widget _chip(String label, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
        child: Text(label, style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.w600)),
      );

  String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
