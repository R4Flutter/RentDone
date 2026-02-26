import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:rentdone/features/tenant/data/models/tenant_document.dart';
import 'package:rentdone/features/tenant/presentation/providers/tenant_dashboard_provider.dart';

class TenantDocumentsScreen extends ConsumerStatefulWidget {
  const TenantDocumentsScreen({super.key});

  @override
  ConsumerState<TenantDocumentsScreen> createState() =>
      _TenantDocumentsScreenState();
}

class _TenantDocumentsScreenState extends ConsumerState<TenantDocumentsScreen> {
  final TextEditingController _descriptionController = TextEditingController();
  String? _loadedTenantId;
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

    return summaryAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (summary) {
        final tenantId = summary.tenantId;
        if (tenantId.isEmpty) {
          _startAutoSyncIfNeeded();
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Profile sync in progress. We are refreshing automatically.',
                    textAlign: TextAlign.center,
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
          );
        }

        _stopAutoSync();

        final notifier = ref.read(tenantDocumentsProvider.notifier);
        final docsState = ref.watch(tenantDocumentsProvider);
        final docsAsync = docsState.documents;

        if (_loadedTenantId != tenantId) {
          _loadedTenantId = tenantId;
          Future.microtask(() => notifier.loadInitial(tenantId));
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Agreement & Property Documents',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => _pickAndUpload(tenantId),
                    icon: const Icon(Icons.upload_file_rounded),
                    label: const Text('Upload'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: docsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Failed to load docs: $e')),
                data: (documents) {
                  if (documents.isEmpty) {
                    return const Center(
                      child: Text('No documents uploaded yet'),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () => notifier.loadInitial(tenantId),
                    child: GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 0.95,
                          ),
                      itemCount: documents.length + 1,
                      itemBuilder: (context, index) {
                        if (index == documents.length) {
                          return _loadMoreTile(tenantId);
                        }
                        final document = documents[index];
                        return _documentTile(tenantId, document);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
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

  Widget _loadMoreTile(String tenantId) {
    final notifier = ref.read(tenantDocumentsProvider.notifier);
    final hasMore = ref.watch(tenantDocumentsProvider).hasMore;

    if (!hasMore) {
      return const Card(child: Center(child: Text('No more documents')));
    }

    return InkWell(
      onTap: () => notifier.loadMore(tenantId),
      child: const Card(
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.expand_more_rounded),
              SizedBox(width: 6),
              Text('Load more'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _documentTile(String tenantId, TenantDocument document) {
    final isImage = document.fileType == 'image';
    final isPdf = document.fileType == 'pdf';

    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () => _openDocument(document),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Center(
                  child: isImage
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            document.fileUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.broken_image_outlined),
                          ),
                        )
                      : Icon(
                          isPdf
                              ? Icons.picture_as_pdf_rounded
                              : Icons.video_file_rounded,
                          size: 56,
                        ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                document.description.isEmpty
                    ? 'Uploaded document'
                    : document.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                'Uploaded: ${_formatUploadedAt(document.uploadedAt)}',
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    document.fileType.toUpperCase(),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  IconButton(
                    onPressed: () => _deleteDocument(tenantId, document),
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndUpload(String tenantId) async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'mp4', 'mov'],
      withData: false,
    );

    if (picked == null || picked.files.isEmpty) {
      return;
    }

    final file = picked.files.first;
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

  Future<void> _openDocument(TenantDocument document) async {
    if (document.fileType == 'image') {
      await showDialog<void>(
        context: context,
        builder: (_) => Dialog(
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
}
