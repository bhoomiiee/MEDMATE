import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/auth_guard.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/app_exit_button.dart';
import 'document_viewer_screen.dart';

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  List<Map<String, dynamic>> _docs = [];
  bool _loading = true;
  bool _uploading = false;
  String _filterType = 'All';

  final List<String> _types = [
    'All', 'prescription', 'lab_report', 'scan', 'vaccination', 'insurance', 'other'
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await SupabaseService.getMedicalDocuments();
      setState(() => _docs = data);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered => _filterType == 'All'
      ? _docs
      : _docs.where((d) => d['doc_type'] == _filterType).toList();

  Future<void> _upload() async {
    final userId = await AuthGuard.requireUserId(context);
    if (userId == null) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final picked = result.files.single;
    Uint8List? fileBytes = picked.bytes;
    if (fileBytes == null && picked.path != null) {
      try {
        fileBytes = await File(picked.path!).readAsBytes();
      } catch (_) {}
    }

    if (fileBytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not read the selected file.')),
        );
      }
      return;
    }

    setState(() => _uploading = true);
    try {
      final fileName = picked.name;
      final uuid = const Uuid().v4();
      final path = '$userId/$uuid/$fileName';

      String contentType = 'application/octet-stream';
      final ext = picked.extension?.toLowerCase();
      if (ext == 'pdf') contentType = 'application/pdf';
      if (ext == 'jpg' || ext == 'jpeg') contentType = 'image/jpeg';
      if (ext == 'png') contentType = 'image/png';

      final url = await SupabaseService.uploadFile(
        bucket: AppConstants.medicalDocsBucket,
        path: path,
        bytes: fileBytes,
        contentType: contentType,
      );

      // Ask for document type
      String? selectedType;
      if (mounted) {
        selectedType = await showDialog<String>(
          context: context,
          builder: (_) => _DocTypeDialog(),
        );
      }

      await SupabaseService.addMedicalDocument({
        'user_id': userId,
        'title': fileName.replaceAll(RegExp(r'\.[^.]+$'), ''),
        'doc_type': selectedType ?? 'other',
        'file_url': url,
        'file_name': fileName,
        'file_size': picked.size,
        'mime_type': picked.extension,
        'document_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      });

      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Document uploaded successfully!'),
              ],
            ),
            backgroundColor: AppColors.secondary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _delete(Map<String, dynamic> doc) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete Document?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(true),
              child: const Text('Delete',
                  style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (ok == true) {
      await SupabaseService.deleteMedicalDocument(doc['id']);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const AppExitButton(fallbackRoute: '/home'),
        title: const Text('Medical Documents'),
        actions: [
          if (_uploading)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            IconButton(
              icon: const Icon(Icons.upload_file_rounded),
              onPressed: _upload,
            ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 54,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _types.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final t = _types[i];
                final sel = _filterType == t;
                final label = t == 'All'
                    ? 'All'
                    : AppConstants.docTypeLabels[t] ?? t;
                return GestureDetector(
                  onTap: () => setState(() => _filterType = t),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.primary : AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: sel ? AppColors.primary : AppColors.border,
                      ),
                      boxShadow: sel ? AppColors.glow(AppColors.primary) : null,
                    ),
                    child: Center(
                      child: Text(
                        label,
                        style: TextStyle(
                          color: sel ? Colors.white : AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? EmptyState(
                        icon: Icons.folder_outlined,
                        title: 'No documents yet',
                        subtitle: 'Upload prescriptions, lab reports, scans and more',
                        actionLabel: 'Upload Document',
                        onAction: _upload,
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                          itemCount: _filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (_, i) =>
                              _docCard(_filtered[i]),
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _upload,
        backgroundColor: AppColors.primary,
        elevation: 4,
        icon: const Icon(Icons.upload_file_rounded, color: Colors.white),
        label: const Text(
          'Upload Document',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _docCard(Map<String, dynamic> doc) {
    final docType = doc['doc_type'] as String? ?? 'other';
    final label = AppConstants.docTypeLabels[docType] ?? 'Document';
    final date = doc['document_date'] != null
        ? DateFormat('d MMM yyyy')
            .format(DateTime.parse(doc['document_date']))
        : null;
    final size = doc['file_size'] as int?;
    final color = _docColor(docType);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
        boxShadow: AppColors.softShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _viewDocument(doc),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(_docIcon(docType), color: color, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doc['title'] ?? 'Document',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _chip(label, color),
                          if (date != null)
                            Text(
                              date,
                              style: TextStyle(
                                color: isDark ? AppColors.darkTextSecondary : AppColors.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                      if (size != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            '${(size / 1024).toStringAsFixed(1)} KB',
                            style: TextStyle(
                              color: isDark ? AppColors.darkTextSecondary : AppColors.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () => _viewDocument(doc),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.visibility_rounded, size: 16, color: AppColors.primary),
                            SizedBox(width: 4),
                            Text(
                              'View',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.errorSurface,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.delete_outline_rounded,
                            color: AppColors.error, size: 18),
                      ),
                      tooltip: 'Delete',
                      onPressed: () => _delete(doc),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _viewDocument(Map<String, dynamic> doc) async {
    final fileUrl = doc['file_url'] as String?;
    if (fileUrl == null || fileUrl.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No file link found for this record.'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
      return;
    }

    // Require account login password before unlocking and viewing
    final bool? verified = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) => const _PasswordAuthDialog(),
    );

    if (verified != true || !mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => DocumentViewerScreen(doc: doc),
      ),
    );
  }

  Future<void> _openExternal(String url) async {
    try {
      final uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        await launchUrl(uri);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open file: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Widget _imageFallback(String fileUrl, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.broken_image_rounded, size: 52, color: AppColors.warning),
            const SizedBox(height: 12),
            Text(
              'Image preview unavailable in-app.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You can open or download the image directly.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _openExternal(fileUrl),
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: const Text('Open in Browser / Viewer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 10, fontWeight: FontWeight.w700)),
      );

  Color _docColor(String type) {
    switch (type) {
      case 'prescription': return AppColors.primary;
      case 'lab_report': return AppColors.secondary;
      case 'scan': return const Color(0xFF8B5CF6);
      case 'vaccination': return AppColors.warning;
      case 'insurance': return const Color(0xFFEC4899);
      default: return AppColors.textSecondary;
    }
  }

  IconData _docIcon(String type) {
    switch (type) {
      case 'prescription': return Icons.description_rounded;
      case 'lab_report': return Icons.biotech_rounded;
      case 'scan': return Icons.image_rounded;
      case 'vaccination': return Icons.vaccines_outlined;
      case 'insurance': return Icons.shield_rounded;
      default: return Icons.insert_drive_file_rounded;
    }
  }
}

class _DocTypeDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Document Type'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: AppConstants.docTypeLabels.entries
            .map((e) => ListTile(
                  title: Text(e.value),
                  onTap: () => Navigator.pop(context, e.key),
                  dense: true,
                ))
            .toList(),
      ),
    );
  }
}

class _PasswordAuthDialog extends StatefulWidget {
  const _PasswordAuthDialog();

  @override
  State<_PasswordAuthDialog> createState() => _PasswordAuthDialogState();
}

class _PasswordAuthDialogState extends State<_PasswordAuthDialog> {
  final _passwordController = TextEditingController();
  bool _obscure = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _verifyPassword() async {
    final password = _passwordController.text.trim();
    if (password.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your password';
      });
      return;
    }

    final user = AuthService.currentUser;
    final email = user?.email;
    if (email == null) {
      setState(() {
        _errorMessage = 'User session not found. Please log in again.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await AuthService.signIn(email: email, password: password);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        final errText = e.toString().toLowerCase();
        setState(() {
          _isLoading = false;
          if (errText.contains('invalid login credentials') ||
              errText.contains('invalid_credentials')) {
            _errorMessage = 'Incorrect password. Please try again.';
          } else if (errText.contains('socketexception') ||
              errText.contains('network') ||
              errText.contains('failed host lookup')) {
            _errorMessage = 'Network error. Please check your connection.';
          } else {
            _errorMessage = 'Authentication failed. Please check your password.';
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textCol = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final subTextCol =
        isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: bg,
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withValues(alpha: 0.35),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_rounded,
                  color: AppColors.primary,
                  size: 28,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Security Verification',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: textCol,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter your account login password to view this confidential medical document.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: subTextCol,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _passwordController,
              obscureText: _obscure,
              autofocus: true,
              enabled: !_isLoading,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _verifyPassword(),
              style: TextStyle(color: textCol, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Enter your password',
                hintStyle: TextStyle(
                    color: subTextCol.withValues(alpha: 0.7), fontSize: 14),
                prefixIcon: const Icon(Icons.password_rounded,
                    size: 20, color: AppColors.primary),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    size: 20,
                    color: subTextCol,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
                filled: true,
                fillColor:
                    isDark ? const Color(0xFF0F172A) : AppColors.lavenderMist,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: _errorMessage != null
                        ? AppColors.error
                        : isDark
                            ? Colors.white12
                            : AppColors.border,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: _errorMessage != null
                        ? AppColors.error
                        : AppColors.primary,
                    width: 1.5,
                  ),
                ),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded,
                      size: 16, color: AppColors.error),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _isLoading ? null : () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      side: BorderSide(
                          color: isDark ? Colors.white24 : AppColors.border),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: subTextCol,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _verifyPassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Verify & View',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
