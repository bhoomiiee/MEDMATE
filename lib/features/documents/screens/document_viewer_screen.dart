import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';

class DocumentViewerScreen extends StatefulWidget {
  final Map<String, dynamic> doc;

  const DocumentViewerScreen({super.key, required this.doc});

  @override
  State<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends State<DocumentViewerScreen> {
  final TransformationController _transformationController =
      TransformationController();

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

  void _copyLink(String url) {
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Document link copied to clipboard!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final doc = widget.doc;
    final title = doc['title'] as String? ?? 'Document';
    final fileName = doc['file_name'] as String? ?? 'Medical Document';
    final fileUrl = doc['file_url'] as String? ?? '';
    final docType = doc['doc_type'] as String? ?? 'other';

    final fileNameLower = fileName.toLowerCase();
    final urlLower = fileUrl.toLowerCase();
    final mimeType = (doc['mime_type'] ?? '').toString().toLowerCase();

    final isImage = ['jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp'].any(
      (ext) =>
          fileNameLower.endsWith('.$ext') ||
          mimeType.contains(ext) ||
          urlLower.contains('.$ext'),
    );
    final isPdf = fileNameLower.endsWith('.pdf') ||
        mimeType.contains('pdf') ||
        urlLower.contains('.pdf');

    final isNetwork =
        fileUrl.startsWith('http://') || fileUrl.startsWith('https://');

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              fileName,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.link_rounded, color: Colors.white),
            tooltip: 'Copy Link',
            onPressed: () => _copyLink(fileUrl),
          ),
          IconButton(
            icon: const Icon(Icons.open_in_new_rounded, color: Colors.white),
            tooltip: 'Open in Browser',
            onPressed: () => _openExternal(fileUrl),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Preview viewport
            Expanded(
              child: isImage
                  ? Stack(
                      children: [
                        Center(
                          child: InteractiveViewer(
                            transformationController: _transformationController,
                            minScale: 0.5,
                            maxScale: 5.0,
                            child: isNetwork
                                ? Image.network(
                                    fileUrl,
                                    fit: BoxFit.contain,
                                    loadingBuilder: (ctx, child, progress) {
                                      if (progress == null) return child;
                                      return Center(
                                        child: CircularProgressIndicator(
                                          value: progress.expectedTotalBytes != null
                                              ? progress.cumulativeBytesLoaded /
                                                  progress.expectedTotalBytes!
                                              : null,
                                          color: AppColors.primary,
                                        ),
                                      );
                                    },
                                    errorBuilder: (ctx, err, stack) =>
                                        _errorCard(fileUrl),
                                  )
                                : Image.file(
                                    File(fileUrl),
                                    fit: BoxFit.contain,
                                    errorBuilder: (ctx, err, stack) =>
                                        _errorCard(fileUrl),
                                  ),
                          ),
                        ),
                        // Pinch to zoom hint
                        Positioned(
                          bottom: 16,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.pinch_rounded,
                                      color: Colors.white70, size: 16),
                                  SizedBox(width: 6),
                                  Text(
                                    'Pinch or drag to zoom',
                                    style: TextStyle(
                                        color: Colors.white70, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 90,
                              height: 90,
                              decoration: BoxDecoration(
                                color: isPdf
                                    ? Colors.red.withOpacity(0.15)
                                    : AppColors.primary.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isPdf
                                    ? Icons.picture_as_pdf_rounded
                                    : Icons.insert_drive_file_rounded,
                                size: 48,
                                color: isPdf
                                    ? Colors.redAccent
                                    : AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              isPdf ? 'PDF Medical Document' : 'Medical Record File',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              fileName,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: () => _openExternal(fileUrl),
                              icon: const Icon(Icons.open_in_new_rounded, size: 18),
                              label: Text(isPdf
                                  ? 'Open PDF in Viewer'
                                  : 'Open / Download File'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),

            // Bottom action bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF1E293B),
                border: Border(top: BorderSide(color: Color(0xFF334155))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _transformationController.value = Matrix4.identity();
                      },
                      icon: const Icon(Icons.refresh_rounded, size: 18, color: Colors.white70),
                      label: const Text('Reset Zoom', style: TextStyle(color: Colors.white70)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: Color(0xFF475569)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _openExternal(fileUrl),
                      icon: const Icon(Icons.open_in_new_rounded, size: 18),
                      label: const Text('Full Viewer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorCard(String fileUrl) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.broken_image_rounded, size: 60, color: Colors.amber),
            const SizedBox(height: 16),
            const Text(
              'Cannot preview image directly',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap below to open in your device browser or photo viewer.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _openExternal(fileUrl),
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Open External Viewer'),
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
}

