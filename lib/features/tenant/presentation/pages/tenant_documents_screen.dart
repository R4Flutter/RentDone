import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:rentdone/app/app_theme.dart';

import 'package:rentdone/features/tenant/data/models/tenant_document.dart';
import 'package:rentdone/features/tenant/presentation/providers/tenant_dashboard_provider.dart';
import 'package:rentdone/features/tenant/presentation/widgets/tenant_glass.dart';

class TenantDocumentsScreen extends ConsumerStatefulWidget {
  const TenantDocumentsScreen({super.key});

  @override
  ConsumerState<TenantDocumentsScreen> createState() =>
      _TenantDocumentsScreenState();
}

class _TenantDocumentsScreenState extends ConsumerState<TenantDocumentsScreen> {
  static const _categories = ['All', 'Agreements', 'IDs', 'Receipts', 'Other'];
  static const _vaultLimitBytes = 200 * 1024 * 1024;

  final TextEditingController _descriptionController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  String? _loadedTenantId;
  String _selectedCategory = 'All';
  Timer? _syncRetryTimer;
  int _syncAttempts = 0;

  static const _maxSyncAttempts = 10;
  static const _syncRetryInterval = Duration(seconds: 2);
  static const _maxUploadBytes = 5 * 1024 * 1024;

  @override
  void dispose() {
    _stopAutoSync();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(tenantDashboardProvider);
    final docsState = ref.watch(tenantDocumentsProvider);
    final docsAsync = docsState.documents;

    return summaryAsync.when(
      loading: () =>
          _vaultScaffold(const Center(child: CircularProgressIndicator())),
      error: (e, _) => _vaultScaffold(
        Center(
          child: Text(
            'Error: $e',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
          ),
        ),
      ),
      data: (summary) {
        final tenantId = summary.tenantId;
        if (tenantId.isEmpty) {
          _startAutoSyncIfNeeded();
          return _vaultScaffold(
            Center(
              child: TenantGlassCard(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Profile sync in progress. We are refreshing automatically.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        _stopAutoSync();

        final notifier = ref.read(tenantDocumentsProvider.notifier);

        if (_loadedTenantId != tenantId) {
          _loadedTenantId = tenantId;
          Future.microtask(() => notifier.loadInitial(tenantId));
        }

        return _vaultScaffold(
          docsAsync.when(
            loading: () => _buildVaultBody(
              tenantId: tenantId,
              hasMore: docsState.hasMore,
              isLoadingMore: docsState.isLoadingMore,
              documents: const [],
              loading: true,
            ),
            error: (e, _) => _buildVaultBody(
              tenantId: tenantId,
              hasMore: false,
              isLoadingMore: false,
              documents: const [],
              errorText: 'Failed to load docs: $e',
            ),
            data: (documents) => _buildVaultBody(
              tenantId: tenantId,
              hasMore: docsState.hasMore,
              isLoadingMore: docsState.isLoadingMore,
              documents: documents,
            ),
          ),
        );
      },
    );
  }

  Widget _vaultScaffold(Widget child) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _VaultTokens.bgTop,
            _VaultTokens.bgMiddle,
            _VaultTokens.bgBottom,
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -100,
            right: -60,
            child: _GlowOrb(
              color: _VaultTokens.primaryAccent.withValues(alpha: 0.24),
              size: 220,
            ),
          ),
          Positioned(
            top: 140,
            left: -80,
            child: _GlowOrb(
              color: _VaultTokens.secondaryAccent.withValues(alpha: 0.18),
              size: 200,
            ),
          ),
          child,
        ],
      ),
    );
  }

  Widget _buildVaultBody({
    required String tenantId,
    required bool hasMore,
    required bool isLoadingMore,
    required List<TenantDocument> documents,
    bool loading = false,
    String? errorText,
  }) {
    final filteredDocs = _filterByCategory(documents, _selectedCategory);
    final storageUsedBytes = documents.fold<int>(
      0,
      (sum, item) => sum + item.fileSizeBytes,
    );
    final storageProgress = (storageUsedBytes / _vaultLimitBytes).clamp(
      0.0,
      1.0,
    );

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () =>
              ref.read(tenantDocumentsProvider.notifier).loadInitial(tenantId),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              _VaultTokens.outerMargin,
              18,
              _VaultTokens.outerMargin,
              120,
            ),
            children: [
              _buildHeader(tenantId)
                  .animate()
                  .fadeIn(duration: const Duration(milliseconds: 320))
                  .slideY(
                    begin: 0.08,
                    end: 0,
                    duration: const Duration(milliseconds: 320),
                  ),
              const SizedBox(height: _VaultTokens.sectionSpacing),
              _buildStorageCard(
                    fileCount: documents.length,
                    storageUsedBytes: storageUsedBytes,
                    progress: storageProgress,
                  )
                  .animate(delay: const Duration(milliseconds: 90))
                  .fadeIn(duration: const Duration(milliseconds: 320))
                  .slideY(
                    begin: 0.08,
                    end: 0,
                    duration: const Duration(milliseconds: 320),
                  ),
              const SizedBox(height: 16),
              _buildDescriptionInput()
                  .animate(delay: const Duration(milliseconds: 140))
                  .fadeIn(duration: const Duration(milliseconds: 300)),
              const SizedBox(height: 16),
              _buildCategoryFilter()
                  .animate(delay: const Duration(milliseconds: 180))
                  .fadeIn(duration: const Duration(milliseconds: 300)),
              const SizedBox(height: 16),
              if (loading)
                _buildLoadingSkeleton()
              else if (errorText != null)
                _buildErrorState(errorText)
              else if (filteredDocs.isEmpty)
                _buildEmptyState(tenantId)
              else
                _buildMasonrySection(
                  tenantId: tenantId,
                  documents: filteredDocs,
                  hasMore: hasMore,
                  isLoadingMore: isLoadingMore,
                ),
            ],
          ),
        ),
        Positioned(right: 20, bottom: 86, child: _buildUploadFab(tenantId)),
      ],
    );
  }

  Widget _buildHeader(String tenantId) {
    return TenantGlassCard(
      accent: true,
      borderRadius: BorderRadius.circular(24),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Document Vault',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Secure • Encrypted • Private',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.76),
                    fontSize: 13,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          _NeonCircleButton(
            icon: Icons.upload_file_rounded,
            onTap: () => _showUploadOptionsSheet(tenantId),
          ),
        ],
      ),
    );
  }

  Widget _buildStorageCard({
    required int fileCount,
    required int storageUsedBytes,
    required double progress,
  }) {
    return TenantGlassCard(
      borderRadius: BorderRadius.circular(22),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _MetricTile(
                title: 'Total Files',
                value: fileCount.toString(),
                icon: Icons.description_outlined,
              ),
              const SizedBox(width: 10),
              _MetricTile(
                title: 'Storage Used',
                value: _formatStorage(storageUsedBytes),
                icon: Icons.storage_rounded,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: _VaultTokens.success.withValues(alpha: 0.18),
                  border: Border.all(
                    color: _VaultTokens.success.withValues(alpha: 0.5),
                  ),
                ),
                child: const Text(
                  'AES-256 Encrypted',
                  style: TextStyle(
                    color: _VaultTokens.success,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '${(progress * 100).toStringAsFixed(1)}%',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _NeonProgressBar(progress: progress),
        ],
      ),
    );
  }

  Widget _buildDescriptionInput() {
    return TenantGlassCard(
      borderRadius: BorderRadius.circular(18),
      child: TextField(
        controller: _descriptionController,
        style: const TextStyle(color: Colors.white),
        decoration: tenantGlassInputDecoration(
          context,
          label: 'File description (optional)',
          hint: 'Agreement, rent receipt, ID proof...',
        ),
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = _categories[index];
          final selected = category == _selectedCategory;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = category),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: selected
                    ? const LinearGradient(
                        colors: [
                          _VaultTokens.primaryAccent,
                          _VaultTokens.secondaryAccent,
                        ],
                      )
                    : null,
                color: selected ? null : Colors.white.withValues(alpha: 0.05),
                border: Border.all(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.28)
                      : Colors.white.withValues(alpha: 0.12),
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: _VaultTokens.primaryAccent.withValues(
                            alpha: 0.36,
                          ),
                          blurRadius: 26,
                          spreadRadius: -5,
                        ),
                      ]
                    : null,
              ),
              child: Text(
                category,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 12,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMasonrySection({
    required String tenantId,
    required List<TenantDocument> documents,
    required bool hasMore,
    required bool isLoadingMore,
  }) {
    final leftColumn = <Widget>[];
    final rightColumn = <Widget>[];

    for (var i = 0; i < documents.length; i++) {
      final widget =
          _VaultDocumentTile(
                key: ValueKey(documents[i].id),
                document: documents[i],
                compact: i.isOdd,
                uploadedAtLabel: _formatUploadedAt(documents[i].uploadedAt),
                onOpen: () => _openDocument(documents[i]),
                onDelete: () => _deleteDocument(tenantId, documents[i]),
              )
              .animate(delay: Duration(milliseconds: 60 * (i % 6)))
              .fadeIn(duration: const Duration(milliseconds: 280))
              .slideY(
                begin: 0.08,
                end: 0,
                duration: const Duration(milliseconds: 280),
              );

      if (i.isEven) {
        leftColumn.add(widget);
        leftColumn.add(const SizedBox(height: 10));
      } else {
        rightColumn.add(widget);
        rightColumn.add(const SizedBox(height: 10));
      }
    }

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Column(children: leftColumn)),
            const SizedBox(width: 10),
            Expanded(child: Column(children: rightColumn)),
          ],
        ),
        if (isLoadingMore) ...[
          const SizedBox(height: 12),
          const Center(child: CircularProgressIndicator(strokeWidth: 2.2)),
        ] else if (hasMore) ...[
          const SizedBox(height: 12),
          TenantGlassCard(
            onTap: () =>
                ref.read(tenantDocumentsProvider.notifier).loadMore(tenantId),
            borderRadius: BorderRadius.circular(16),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.expand_more_rounded, color: Colors.white70),
                SizedBox(width: 6),
                Text(
                  'Load more documents',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEmptyState(String tenantId) {
    return Center(
      child: TenantGlassCard(
        width: 340,
        borderRadius: BorderRadius.circular(24),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.folder_open_rounded,
              size: 58,
              color: _VaultTokens.highlightAccent.withValues(alpha: 0.9),
            ),
            const SizedBox(height: 14),
            const Text(
              'No Documents Yet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Your secure files will appear here',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(
                    colors: [
                      _VaultTokens.primaryAccent,
                      _VaultTokens.secondaryAccent,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _VaultTokens.primaryAccent.withValues(alpha: 0.4),
                      blurRadius: 30,
                      spreadRadius: -8,
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: () => _showUploadOptionsSheet(tenantId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.cloud_upload_outlined),
                  label: const Text('Upload Document'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return Column(
      children: List.generate(
        4,
        (index) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            height: 120 + (index.isEven ? 20 : 0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: Colors.white.withValues(alpha: 0.05),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(String errorText) {
    return TenantGlassCard(
      borderRadius: BorderRadius.circular(20),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: _VaultTokens.danger,
            size: 34,
          ),
          const SizedBox(height: 10),
          Text(
            errorText,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildUploadFab(String tenantId) {
    return GestureDetector(
          onTap: () => _showUploadOptionsSheet(tenantId),
          child: Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [
                  _VaultTokens.primaryAccent,
                  _VaultTokens.secondaryAccent,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: _VaultTokens.primaryAccent.withValues(alpha: 0.5),
                  blurRadius: 26,
                  spreadRadius: -4,
                ),
              ],
            ),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
          ),
        )
        .animate(onPlay: (controller) => controller.repeat(reverse: true))
        .scaleXY(
          begin: 0.97,
          end: 1.03,
          duration: const Duration(milliseconds: 1400),
        );
  }

  List<TenantDocument> _filterByCategory(
    List<TenantDocument> documents,
    String category,
  ) {
    if (category == 'All') {
      return documents;
    }

    return documents.where((document) {
      final normalizedType = document.fileType.toLowerCase();
      final normalizedDesc = document.description.toLowerCase();

      switch (category) {
        case 'Agreements':
          return normalizedDesc.contains('agreement') ||
              normalizedDesc.contains('lease') ||
              normalizedType == 'pdf';
        case 'IDs':
          return normalizedDesc.contains('id') ||
              normalizedDesc.contains('aadhaar') ||
              normalizedDesc.contains('pan') ||
              normalizedType == 'image';
        case 'Receipts':
          return normalizedDesc.contains('receipt') ||
              normalizedDesc.contains('rent') ||
              normalizedDesc.contains('invoice');
        case 'Other':
          return !(normalizedDesc.contains('agreement') ||
              normalizedDesc.contains('lease') ||
              normalizedDesc.contains('id') ||
              normalizedDesc.contains('aadhaar') ||
              normalizedDesc.contains('pan') ||
              normalizedDesc.contains('receipt') ||
              normalizedDesc.contains('rent') ||
              normalizedDesc.contains('invoice'));
        default:
          return true;
      }
    }).toList();
  }

  Future<void> _showUploadOptionsSheet(String tenantId) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 18),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF16263C), Color(0xFF111C30)],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _UploadOptionTile(
                  icon: Icons.photo_library_outlined,
                  title: 'Upload from Gallery',
                  onTap: () async {
                    Navigator.pop(context);
                    await _uploadFromGallery(tenantId);
                  },
                ),
                _UploadOptionTile(
                  icon: Icons.document_scanner_outlined,
                  title: 'Scan Document',
                  onTap: () async {
                    Navigator.pop(context);
                    await _scanDocument(tenantId);
                  },
                ),
                _UploadOptionTile(
                  icon: Icons.picture_as_pdf_outlined,
                  title: 'Upload PDF',
                  onTap: () async {
                    Navigator.pop(context);
                    await _uploadPdf(tenantId);
                  },
                ),
                _UploadOptionTile(
                  icon: Icons.camera_alt_outlined,
                  title: 'Camera Capture',
                  onTap: () async {
                    Navigator.pop(context);
                    await _captureFromCamera(tenantId);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _uploadFromGallery(String tenantId) async {
    final file = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    await _uploadFromXFile(tenantId, file);
  }

  Future<void> _captureFromCamera(String tenantId) async {
    final file = await _imagePicker.pickImage(source: ImageSource.camera);
    if (file == null) return;
    await _uploadFromXFile(tenantId, file);
  }

  Future<void> _scanDocument(String tenantId) async {
    final file = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 2200,
    );
    if (file == null) return;
    await _uploadFromXFile(tenantId, file);
  }

  Future<void> _uploadPdf(String tenantId) async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: false,
    );
    if (picked == null || picked.files.isEmpty) return;
    await _uploadPlatformFile(tenantId, picked.files.first);
  }

  Future<void> _uploadFromXFile(String tenantId, XFile file) async {
    final ioFile = File(file.path);
    if (!await ioFile.exists()) return;
    final size = await ioFile.length();

    final platformFile = PlatformFile(
      name: file.name,
      path: file.path,
      size: size,
    );

    await _uploadPlatformFile(tenantId, platformFile);
  }

  Future<void> _uploadPlatformFile(String tenantId, PlatformFile file) async {
    if (file.size > _maxUploadBytes) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('File too large. Max allowed size is 5 MB.'),
          ),
        );
      }
      return;
    }

    if ((file.path ?? '').isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to read this file. Please pick again.'),
          ),
        );
      }
      return;
    }

    try {
      await ref
          .read(tenantDocumentsProvider.notifier)
          .upload(
            tenantId: tenantId,
            picked: file,
            description: _descriptionController.text.trim(),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document uploaded successfully')),
        );
      }
      _descriptionController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed. ${_friendlyError(e)}')),
        );
      }
    }
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

      final hasTenantId = ref
          .read(tenantDashboardProvider)
          .maybeWhen(
            data: (summary) => summary.tenantId.isNotEmpty,
            orElse: () => false,
          );

      if (hasTenantId) {
        timer.cancel();
        _syncRetryTimer = null;
        return;
      }

      _syncAttempts += 1;
      ref.invalidate(tenantDashboardProvider);

      if (_syncAttempts >= _maxSyncAttempts) {
        timer.cancel();
        _syncRetryTimer = null;
      }
    });
  }

  void _stopAutoSync() {
    _syncRetryTimer?.cancel();
    _syncRetryTimer = null;
  }

  Future<void> _openDocument(TenantDocument document) async {
    if (document.fileType == 'image') {
      await showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: AppTheme.nearBlack,
          child: InteractiveViewer(
            child: Image.network(document.fileUrl, fit: BoxFit.contain),
          ),
        ),
      );
      return;
    }

    final uri = Uri.parse(document.fileUrl);
    final opened = await launchUrl(uri, mode: LaunchMode.platformDefault);
    if (!opened && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Unable to open document')));
    }
  }

  Future<void> _deleteDocument(String tenantId, TenantDocument document) async {
    try {
      await ref
          .read(tenantDocumentsProvider.notifier)
          .delete(tenantId, document);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Document deleted')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed. ${_friendlyError(e)}')),
        );
      }
    }
  }

  String _friendlyError(Object error) {
    final raw = error.toString();
    final text = raw.toLowerCase();
    if (text.contains('cloudinary upload preset is missing')) {
      return 'Cloudinary preset is missing in app config. Start app with CLOUDINARY_UPLOAD_PRESET.';
    }
    if (text.contains('cloudinary upload failed for all configurations') ||
        text.contains('cloudinary unsigned upload failed') ||
        text.contains('upload failed with status') ||
        text.contains('http 400')) {
      return _cloudinaryReason(raw);
    }
    if (text.contains('http 401') || text.contains('http 403')) {
      return 'Upload authorization failed. Please sign in again and retry.';
    }
    if (text.contains('http 404')) {
      return 'Upload endpoint not found. Backend upload route is not deployed correctly.';
    }
    if (text.contains('http 500')) {
      return 'Upload server error. Please verify Cloudinary config on backend.';
    }
    if (text.contains('file exceeds 50mb')) {
      return 'File is larger than 50 MB. Please choose a smaller file.';
    }
    if (text.contains('permission-denied') ||
        text.contains('permission denied')) {
      return 'You do not have access yet. Please wait for profile sync to complete.';
    }
    if (text.contains('not-found') || text.contains('not found')) {
      return 'Tenant profile not found. Ask owner to assign this account to your room.';
    }
    if (text.contains('network') || text.contains('socket')) {
      return 'Network issue detected. Check internet and try again.';
    }
    return 'Please try again in a moment.';
  }

  String _cloudinaryReason(String rawError) {
    final text = rawError.toLowerCase();
    if (text.contains('upload preset not found')) {
      return 'Upload preset not found on Cloudinary. Configure valid CLOUDINARY_UPLOAD_PRESET.';
    }
    if (text.contains('unsigned uploads are disabled') ||
        text.contains('must be unsigned')) {
      return 'Cloudinary preset is not unsigned. Enable unsigned mode in Cloudinary preset settings.';
    }
    if (text.contains('invalid cloud name')) {
      return 'Cloudinary cloud name is invalid. Check CLOUDINARY_CLOUD_NAME.';
    }
    if (text.contains('public_id is not allowed')) {
      return 'Cloudinary preset blocks public_id. Update preset options to allow app uploads.';
    }
    if (text.contains('resource not found')) {
      return 'Cloudinary API endpoint not found. Verify cloud name and API host.';
    }
    return 'Cloudinary rejected upload config. Please verify cloud name and upload preset.';
  }

  String _formatUploadedAt(DateTime? uploadedAt) {
    if (uploadedAt == null) {
      return 'Pending sync';
    }
    return DateFormat('dd MMM yyyy, hh:mm a').format(uploadedAt);
  }

  String _formatStorage(int bytes) {
    if (bytes <= 0) return '0 MB';
    final mb = bytes / (1024 * 1024);
    if (mb < 1) {
      final kb = bytes / 1024;
      return '${kb.toStringAsFixed(0)} KB';
    }
    return '${mb.toStringAsFixed(1)} MB';
  }
}

class _VaultTokens {
  static const Color bgTop = Color(0xFF0B1220);
  static const Color bgMiddle = Color(0xFF0E1A2B);
  static const Color bgBottom = Color(0xFF111C30);

  static const Color primaryAccent = Color(0xFF4F7CFF);
  static const Color secondaryAccent = Color(0xFF7A5CFF);
  static const Color highlightAccent = Color(0xFF3FE0FF);
  static const Color danger = Color(0xFFFF5A5F);
  static const Color success = Color(0xFF22C55E);

  static const double outerMargin = 20;
  static const double sectionSpacing = 24;
}

class _GlowOrb extends StatelessWidget {
  final Color color;
  final double size;

  const _GlowOrb({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: [
            BoxShadow(color: color, blurRadius: 90, spreadRadius: 10),
          ],
        ),
      ),
    );
  }
}

class _NeonCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _NeonCircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [_VaultTokens.primaryAccent, _VaultTokens.highlightAccent],
          ),
          boxShadow: [
            BoxShadow(
              color: _VaultTokens.highlightAccent.withValues(alpha: 0.45),
              blurRadius: 18,
              spreadRadius: -4,
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _MetricTile({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colors.white.withValues(alpha: 0.04),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white.withValues(alpha: 0.85), size: 16),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.66),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NeonProgressBar extends StatelessWidget {
  final double progress;

  const _NeonProgressBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 10,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withValues(alpha: 0.08),
      ),
      child: Stack(
        children: [
          AnimatedFractionallySizedBox(
            alignment: Alignment.centerLeft,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            widthFactor: progress,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: const LinearGradient(
                  colors: [
                    _VaultTokens.primaryAccent,
                    _VaultTokens.highlightAccent,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: _VaultTokens.highlightAccent.withValues(alpha: 0.52),
                    blurRadius: 18,
                    spreadRadius: -3,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VaultDocumentTile extends StatefulWidget {
  final TenantDocument document;
  final bool compact;
  final String uploadedAtLabel;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  const _VaultDocumentTile({
    super.key,
    required this.document,
    required this.compact,
    required this.uploadedAtLabel,
    required this.onOpen,
    required this.onDelete,
  });

  @override
  State<_VaultDocumentTile> createState() => _VaultDocumentTileState();
}

class _VaultDocumentTileState extends State<_VaultDocumentTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isImage = widget.document.fileType == 'image';
    final isPdf = widget.document.fileType == 'pdf';
    final previewHeight = widget.compact ? 100.0 : 132.0;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 1.02 : 1,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        child: TenantGlassCard(
          onTap: widget.onOpen,
          borderRadius: BorderRadius.circular(20),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: previewHeight,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: Colors.white.withValues(alpha: 0.06),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Center(
                    child: isImage
                        ? Image.network(
                            widget.document.fileUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(
                                  Icons.broken_image_outlined,
                                  color: Colors.white70,
                                  size: 34,
                                ),
                          )
                        : Icon(
                            isPdf
                                ? Icons.picture_as_pdf_rounded
                                : Icons.insert_drive_file_rounded,
                            size: 40,
                            color: Colors.white.withValues(alpha: 0.82),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.document.description.isEmpty
                          ? 'Uploaded document'
                          : widget.document.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_horiz_rounded,
                      color: Colors.white.withValues(alpha: 0.78),
                    ),
                    color: const Color(0xFF152238),
                    onSelected: (value) {
                      if (value == 'open') {
                        widget.onOpen();
                      }
                      if (value == 'delete') {
                        widget.onDelete();
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'open', child: Text('Open')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ],
              ),
              Text(
                widget.uploadedAtLabel,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UploadOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _UploadOptionTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TenantGlassCard(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _VaultTokens.primaryAccent.withValues(alpha: 0.22),
              ),
              child: Icon(icon, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ],
        ),
      ),
    );
  }
}
