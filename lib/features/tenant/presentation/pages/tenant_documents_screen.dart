import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:rentdone/app/app_theme.dart';
import 'package:rentdone/core/storage/document_cache_service.dart';
import 'package:rentdone/features/tenant/data/models/tenant_document.dart';
import 'package:rentdone/features/tenant/presentation/providers/tenant_dashboard_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class TenantDocumentsScreen extends ConsumerStatefulWidget {
  const TenantDocumentsScreen({super.key});

  @override
  ConsumerState<TenantDocumentsScreen> createState() =>
      _TenantDocumentsScreenState();
}

class _TenantDocumentsScreenState extends ConsumerState<TenantDocumentsScreen>
    with TickerProviderStateMixin {
  static const _maxSyncAttempts = 10;
  static const _syncRetryInterval = Duration(seconds: 2);
  static const _documentCacheTtl = Duration(days: 7);

  final _imagePicker = ImagePicker();
  final _noteController = TextEditingController();

  String? _loadedTenantId;
  Timer? _syncRetryTimer;
  int _syncAttempts = 0;

  late final AnimationController _bgCtrl;

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat(reverse: true);
    Future<void>.microtask(
      () => DocumentCacheService.clearExpired(_documentCacheTtl),
    );
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _noteController.dispose();
    _syncRetryTimer?.cancel();
    super.dispose();
  }

  void _startAutoSyncIfNeeded() {
    if (_syncRetryTimer != null || !mounted) {
      return;
    }

    _syncAttempts = 0;
    _syncRetryTimer = Timer.periodic(_syncRetryInterval, (timer) {
      if (!mounted) {
        timer.cancel();
        _syncRetryTimer = null;
        return;
      }

      final hasTenant = ref
          .read(tenantDashboardProvider)
          .maybeWhen(
            data: (summary) => summary.tenantId.isNotEmpty,
            orElse: () => false,
          );

      if (hasTenant) {
        timer.cancel();
        _syncRetryTimer = null;
        return;
      }

      _syncAttempts += 1;
      if (_syncAttempts >= _maxSyncAttempts) {
        timer.cancel();
        _syncRetryTimer = null;
      } else {
        ref.invalidate(tenantDashboardProvider);
      }
    });
  }

  void _stopAutoSync() {
    _syncRetryTimer?.cancel();
    _syncRetryTimer = null;
  }

  List<TenantDocument> _docsByCategory(
    List<TenantDocument> docs,
    String category,
  ) {
    return docs.where((doc) => _resolveCategory(doc) == category).toList();
  }

  String _resolveCategory(TenantDocument doc) {
    final c = doc.category.trim().toLowerCase();
    if (c == _DocCategory.agreement || c == _DocCategory.other) {
      return c;
    }

    final d = doc.description.toLowerCase();
    if (d.contains('agreement') || d.contains('lease')) {
      return _DocCategory.agreement;
    }
    // Legacy Aadhaar-tagged docs are surfaced under Other.
    if (d.contains('aadhaar') ||
        d.contains('aadhar') ||
        d.contains('id proof')) {
      return _DocCategory.other;
    }
    return _DocCategory.other;
  }

  String _friendlyName(TenantDocument doc) {
    final desc = doc.description.trim();
    if (desc.isEmpty) {
      return '${_labelForCategory(_resolveCategory(doc))} document';
    }

    if (desc.contains('|')) {
      final parts = desc.split('|');
      if (parts.length >= 2) {
        return parts[1].trim();
      }
    }

    return desc;
  }

  String _labelForCategory(String category) {
    switch (category) {
      case _DocCategory.agreement:
        return 'Agreement';
      default:
        return 'Other Documents';
    }
  }

  String _formatDate(DateTime? value) {
    if (value == null) {
      return 'Pending sync';
    }
    return DateFormat('dd MMM yyyy, hh:mm a').format(value);
  }

  String _formatBytes(int value) {
    if (value <= 0) {
      return '0 KB';
    }

    final kb = value / 1024;
    final mb = kb / 1024;
    if (mb >= 1) {
      return '${mb.toStringAsFixed(1)} MB';
    }
    return '${kb.toStringAsFixed(0)} KB';
  }

  String _friendlyError(Object error) {
    final message = error.toString().toLowerCase();
    if (message.contains('500kb')) {
      return 'PDF must be 500KB or less.';
    }
    if (message.contains('200kb')) {
      return 'Image must compress to 200KB.';
    }
    if (message.contains('permission')) {
      return 'Permission denied. Sign in again and retry.';
    }
    if (message.contains('network') || message.contains('socket')) {
      return 'Network issue. Check internet and retry.';
    }
    return 'Please try again in a moment.';
  }

  Future<void> _uploadPdf(String tenantId, String category) async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      withData: false,
    );

    if (picked == null || picked.files.isEmpty) {
      return;
    }

    await _uploadPlatformFile(
      tenantId: tenantId,
      category: category,
      platformFile: picked.files.first,
    );
  }

  Future<void> _uploadFromGallery(String tenantId, String category) async {
    final picked = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (picked == null) {
      return;
    }

    final file = File(picked.path);
    if (!await file.exists()) {
      _snack('Unable to read selected image.');
      return;
    }

    await _uploadPlatformFile(
      tenantId: tenantId,
      category: category,
      platformFile: PlatformFile(
        name: picked.name,
        path: picked.path,
        size: await file.length(),
      ),
    );
  }

  Future<void> _captureCamera(String tenantId, String category) async {
    final picked = await _imagePicker.pickImage(source: ImageSource.camera);
    if (picked == null) {
      return;
    }

    final file = File(picked.path);
    if (!await file.exists()) {
      _snack('Unable to read captured image.');
      return;
    }

    await _uploadPlatformFile(
      tenantId: tenantId,
      category: category,
      platformFile: PlatformFile(
        name: picked.name,
        path: picked.path,
        size: await file.length(),
      ),
    );
  }

  Future<void> _uploadPlatformFile({
    required String tenantId,
    required String category,
    required PlatformFile platformFile,
  }) async {
    final path = platformFile.path;
    if (path == null || path.isEmpty) {
      _snack('Unable to read this file. Please pick again.');
      return;
    }

    final shouldUseCustomNote = category == _DocCategory.other;
    final customNote = shouldUseCustomNote ? _noteController.text.trim() : '';
    final fallbackName = platformFile.name.trim().isEmpty
        ? '${_labelForCategory(category)} file'
        : platformFile.name.trim();
    final note = customNote.isEmpty ? fallbackName : customNote;

    try {
      await ref
          .read(tenantDocumentsProvider.notifier)
          .upload(
            tenantId: tenantId,
            picked: platformFile,
            description: '$category|$note',
            category: category,
          );
      if (!mounted) {
        return;
      }
      _noteController.clear();
      _snack('Document uploaded successfully.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _snack('Upload failed. ${_friendlyError(error)}');
    }
  }

  Future<void> _openDocument(TenantDocument doc) async {
    try {
      final localFile = await DocumentCacheService.getOrFetch(
        doc.fileUrl,
        _documentCacheTtl,
      );

      if (doc.fileType == 'image') {
        if (!mounted) {
          return;
        }
        final scheme = Theme.of(context).colorScheme;
        await showDialog<void>(
          context: context,
          builder: (_) => Dialog(
            backgroundColor: scheme.surface,
            child: InteractiveViewer(
              child: Image.file(localFile, fit: BoxFit.contain),
            ),
          ),
        );
        return;
      }

      final result = await OpenFilex.open(localFile.path);
      if (result.type == ResultType.done) {
        return;
      }

      final uri = Uri.parse(doc.fileUrl);
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    } catch (error) {
      if (mounted) {
        _snack('Unable to open file. ${_friendlyError(error)}');
      }
    }
  }

  Future<void> _downloadDocument(TenantDocument doc) async {
    try {
      await DocumentCacheService.getOrFetch(doc.fileUrl, _documentCacheTtl);
      if (mounted) {
        _snack('Document cached locally.');
      }
    } catch (error) {
      if (mounted) {
        _snack('Download failed. ${_friendlyError(error)}');
      }
    }
  }

  Future<void> _deleteDocument(String tenantId, TenantDocument doc) async {
    try {
      await ref.read(tenantDocumentsProvider.notifier).delete(tenantId, doc);
      if (mounted) {
        _snack('Document deleted.');
      }
    } catch (error) {
      if (mounted) {
        _snack('Delete failed. ${_friendlyError(error)}');
      }
    }
  }

  Future<void> _showUploadActions(String tenantId, String category) async {
    final scheme = Theme.of(context).colorScheme;
    final showNoteField = category == _DocCategory.other;
    if (!showNoteField) {
      _noteController.clear();
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: OwnerDashboardColors.cardBackground(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              20 + MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Upload to ${_labelForCategory(category)}',
                  style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                    color: OwnerDashboardColors.textPrimary(context),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (showNoteField) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _noteController,
                    decoration: InputDecoration(
                      labelText: 'Document name (optional)',
                      prefixIcon: Icon(
                        Icons.edit_note_rounded,
                        color: scheme.primary,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                _UploadActionTile(
                  icon: Icons.picture_as_pdf_rounded,
                  title: 'Upload PDF',
                  subtitle: 'Will be accepted up to 500KB',
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await _uploadPdf(tenantId, category);
                  },
                ),
                _UploadActionTile(
                  icon: Icons.photo_library_rounded,
                  title: 'Choose Image',
                  subtitle: 'Will compress to 200KB',
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await _uploadFromGallery(tenantId, category);
                  },
                ),
                _UploadActionTile(
                  icon: Icons.photo_camera_rounded,
                  title: 'Capture Photo',
                  subtitle: 'Will compress to 200KB',
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await _captureCamera(tenantId, category);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _snack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(tenantDashboardProvider);
    final docsState = ref.watch(tenantDocumentsProvider);
    final docsAsync = docsState.documents;

    return summaryAsync.when(
      loading: () =>
          _buildScaffold(const Center(child: CircularProgressIndicator())),
      error: (error, _) => _buildScaffold(
        Center(
          child: Text(
            'Failed to load document vault',
            style: TextStyle(color: OwnerDashboardColors.textPrimary(context)),
          ),
        ),
      ),
      data: (summary) {
        final tenantId = summary.tenantId;
        if (tenantId.isEmpty) {
          _startAutoSyncIfNeeded();
          return _buildScaffold(
            const Center(child: CircularProgressIndicator()),
          );
        }

        _stopAutoSync();
        final notifier = ref.read(tenantDocumentsProvider.notifier);
        if (_loadedTenantId != tenantId) {
          _loadedTenantId = tenantId;
          Future<void>.microtask(() => notifier.loadInitial(tenantId));
        }

        final docs = docsAsync.asData?.value ?? const <TenantDocument>[];
        final usedBytes = docs.fold<int>(
          0,
          (sum, doc) => sum + doc.fileSizeBytes,
        );

        return _buildScaffold(
          RefreshIndicator(
            color: OwnerDashboardColors.brandPrimary(context),
            onRefresh: () => notifier.loadInitial(tenantId),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                _VaultHeroCard(
                      totalCount: docs.length,
                      usedLabel: _formatBytes(usedBytes),
                    )
                    .animate()
                    .fadeIn(duration: 360.ms)
                    .slideY(begin: 0.06, end: 0),
                const SizedBox(height: 16),
                ..._DocCategory.values.asMap().entries.map((entry) {
                  final index = entry.key;
                  final category = entry.value;
                  final sectionDocs = _docsByCategory(docs, category);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child:
                        _DocumentSectionCard(
                              title: _labelForCategory(category),
                              subtitle: _categorySubtitle(category),
                              icon: _categoryIcon(category),
                              docs: sectionDocs,
                              onUploadTap: () =>
                                  _showUploadActions(tenantId, category),
                              onOpen: _openDocument,
                              onDownload: _downloadDocument,
                              onDelete: (doc) => _deleteDocument(tenantId, doc),
                              formatBytes: _formatBytes,
                              formatDate: _formatDate,
                              displayNameFor: _friendlyName,
                            )
                            .animate(delay: (80 * (index + 1)).ms)
                            .fadeIn(duration: 300.ms)
                            .slideY(begin: 0.08, end: 0),
                  );
                }),
                if (docsAsync.isLoading || docsState.isLoadingMore)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (docsAsync.hasError)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Could not load some documents. Pull to refresh.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _categorySubtitle(String category) {
    switch (category) {
      case _DocCategory.agreement:
        return 'Lease agreements and signed contract files';
      default:
        return 'Bills, receipts, and any additional documents';
    }
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case _DocCategory.agreement:
        return Icons.description_rounded;
      default:
        return Icons.folder_copy_rounded;
    }
  }

  Widget _buildScaffold(Widget child) {
    return AnimatedBuilder(
      animation: _bgCtrl,
      builder: (context, _) {
        final t = _bgCtrl.value;
        return Scaffold(
          backgroundColor: AppColors.transparent,
          body: Container(
            decoration: BoxDecoration(
              gradient: OwnerDashboardColors.ownerPageBackgroundGradient(
                context,
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: -120 + (26 * math.sin(t * math.pi)),
                  right: -80,
                  child: _BackgroundBlob(
                    size: 240,
                    color: OwnerDashboardColors.ownerTopBlobColor(context),
                  ),
                ),
                Positioned(
                  bottom: -90 + (24 * math.cos(t * math.pi)),
                  left: -70,
                  child: _BackgroundBlob(
                    size: 220,
                    color: OwnerDashboardColors.ownerBottomBlobColor(context),
                  ),
                ),
                SafeArea(child: child),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DocCategory {
  static const agreement = 'agreement';
  static const other = 'other';

  static const values = [agreement, other];
}

class _VaultHeroCard extends StatelessWidget {
  const _VaultHeroCard({required this.totalCount, required this.usedLabel});

  final int totalCount;
  final String usedLabel;

  @override
  Widget build(BuildContext context) {
    final primary = OwnerDashboardColors.brandPrimary(context);
    final card = OwnerDashboardColors.cardBackground(context);
    final textPrimary = OwnerDashboardColors.textPrimary(context);
    final textSecondary = OwnerDashboardColors.textSecondary(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: OwnerDashboardColors.border(context)),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.16),
            blurRadius: 24,
            spreadRadius: -12,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Document Vault',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Structured upload for Agreement and Other Documents',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: textSecondary),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _HeroStat(label: 'Files', value: '$totalCount'),
              const SizedBox(width: 10),
              _HeroStat(label: 'Used', value: usedLabel),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final elevated = OwnerDashboardColors.elevatedBackground(context);
    final border = OwnerDashboardColors.border(context);
    final textPrimary = OwnerDashboardColors.textPrimary(context);
    final textSecondary = OwnerDashboardColors.textSecondary(context);

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: elevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: textSecondary),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DocumentSectionCard extends StatelessWidget {
  const _DocumentSectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.docs,
    required this.onUploadTap,
    required this.onOpen,
    required this.onDownload,
    required this.onDelete,
    required this.formatBytes,
    required this.formatDate,
    required this.displayNameFor,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<TenantDocument> docs;
  final VoidCallback onUploadTap;
  final Future<void> Function(TenantDocument doc) onOpen;
  final Future<void> Function(TenantDocument doc) onDownload;
  final Future<void> Function(TenantDocument doc) onDelete;
  final String Function(int bytes) formatBytes;
  final String Function(DateTime? value) formatDate;
  final String Function(TenantDocument doc) displayNameFor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final card = OwnerDashboardColors.cardBackground(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: OwnerDashboardColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: scheme.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: OwnerDashboardColors.textPrimary(context),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: OwnerDashboardColors.textSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: onUploadTap,
                icon: const Icon(Icons.upload_file_rounded),
                label: const Text('Upload'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (docs.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: OwnerDashboardColors.elevatedBackground(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: OwnerDashboardColors.border(context)),
              ),
              child: Text(
                'No files uploaded in this section yet.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: OwnerDashboardColors.textSecondary(context),
                ),
              ),
            )
          else
            ...docs.map(
              (doc) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _DocumentRow(
                  doc: doc,
                  title: displayNameFor(doc),
                  subtitle:
                      '${formatBytes(doc.fileSizeBytes)} • ${formatDate(doc.uploadedAt)}',
                  onOpen: () => onOpen(doc),
                  onDownload: () => onDownload(doc),
                  onDelete: () => onDelete(doc),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DocumentRow extends StatelessWidget {
  const _DocumentRow({
    required this.doc,
    required this.title,
    required this.subtitle,
    required this.onOpen,
    required this.onDownload,
    required this.onDelete,
  });

  final TenantDocument doc;
  final String title;
  final String subtitle;
  final VoidCallback onOpen;
  final VoidCallback onDownload;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textPrimary = OwnerDashboardColors.textPrimary(context);
    final textSecondary = OwnerDashboardColors.textSecondary(context);

    return Material(
      color: OwnerDashboardColors.elevatedBackground(context),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Icon(
                doc.fileType == 'pdf'
                    ? Icons.picture_as_pdf_rounded
                    : Icons.image_rounded,
                color: scheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: textSecondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Download',
                onPressed: onDownload,
                icon: Icon(Icons.download_rounded, color: scheme.primary),
              ),
              IconButton(
                tooltip: 'Delete',
                onPressed: onDelete,
                icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UploadActionTile extends StatelessWidget {
  const _UploadActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = OwnerDashboardColors.brandPrimary(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: primary),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Icon(Icons.chevron_right_rounded, color: primary),
      onTap: onTap,
    );
  }
}

class _BackgroundBlob extends StatelessWidget {
  const _BackgroundBlob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, AppColors.transparent]),
        ),
      ),
    );
  }
}
