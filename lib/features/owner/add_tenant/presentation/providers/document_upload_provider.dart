import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rentdone/features/owner/add_tenant/data/repositories/tenant_repository.dart';
import 'package:rentdone/features/owner/add_tenant/data/services/firebase_storage_service.dart';
import 'package:rentdone/features/owner/add_tenant/data/exceptions/document_upload_exceptions.dart';

enum DocumentUploadStatus { idle, loading, success, error }

class DocumentUploadState {
  final DocumentUploadStatus status;
  final double progress;
  final String? errorMessage;
  final List<String> uploadedUrls;

  const DocumentUploadState({
    this.status = DocumentUploadStatus.idle,
    this.progress = 0,
    this.errorMessage,
    this.uploadedUrls = const [],
  });

  DocumentUploadState copyWith({
    DocumentUploadStatus? status,
    double? progress,
    String? errorMessage,
    List<String>? uploadedUrls,
  }) {
    return DocumentUploadState(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      errorMessage: errorMessage,
      uploadedUrls: uploadedUrls ?? this.uploadedUrls,
    );
  }
}

final firebaseDocumentStorageServiceProvider =
    Provider<FirebaseDocumentStorageService>((ref) {
      return FirebaseDocumentStorageService();
    });

final tenantDocumentRepositoryProvider = Provider<TenantDocumentRepository>((
  ref,
) {
  final storageService = ref.watch(firebaseDocumentStorageServiceProvider);
  return TenantDocumentRepository(storageService: storageService);
});

class DocumentUploadNotifier extends Notifier<DocumentUploadState> {
  late final TenantDocumentRepository _repository;
  final Set<String> _inFlightPaths = <String>{};

  @override
  DocumentUploadState build() {
    _repository = ref.read(tenantDocumentRepositoryProvider);
    return const DocumentUploadState();
  }

  Future<void> uploadTenantDocument(File file, String tenantId) async {
    if (_inFlightPaths.contains(file.path)) {
      // Already uploading this file
      return;
    }

    _inFlightPaths.add(file.path);
    state = state.copyWith(
      status: DocumentUploadStatus.loading,
      progress: 0,
      errorMessage: null,
    );

    try {
      final url = await _repository.uploadTenantDocument(
        file: file,
        tenantId: tenantId,
        onProgress: (progress) {
          state = state.copyWith(
            status: DocumentUploadStatus.loading,
            progress: progress,
            errorMessage: null,
          );
        },
      );

      // Only add URL if not already in list
      final urls = state.uploadedUrls;
      if (!urls.contains(url)) {
        state = state.copyWith(uploadedUrls: [...urls, url]);
      }

      state = state.copyWith(
        status: DocumentUploadStatus.success,
        progress: 1.0,
        errorMessage: null,
      );
    } on StorageUploadException catch (error) {
      state = state.copyWith(
        status: DocumentUploadStatus.error,
        errorMessage: error.message,
      );
    } catch (error) {
      // Generic error handling
      state = state.copyWith(
        status: DocumentUploadStatus.error,
        errorMessage: _cleanErrorMessage(error),
      );
    } finally {
      _inFlightPaths.remove(file.path);
    }
  }

  void clearTransientState() {
    state = state.copyWith(
      status: DocumentUploadStatus.idle,
      progress: 0,
      errorMessage: null,
    );
  }

  void reset() {
    _inFlightPaths.clear();
    state = const DocumentUploadState();
  }

  void removeUploadedUrl(String url) {
    final next = List<String>.from(state.uploadedUrls)..remove(url);
    state = state.copyWith(uploadedUrls: next);
  }

  String _cleanErrorMessage(dynamic error) {
    final msg = error.toString();

    // Remove common prefixes
    if (msg.startsWith('StorageUploadException: ')) {
      return msg.replaceFirst('StorageUploadException: ', '');
    }
    if (msg.startsWith('FirestoreSaveException: ')) {
      return msg.replaceFirst('FirestoreSaveException: ', '');
    }
    if (msg.startsWith('Exception: ')) {
      return msg.replaceFirst('Exception: ', '');
    }

    return msg;
  }
}

final documentUploadProvider =
    NotifierProvider<DocumentUploadNotifier, DocumentUploadState>(
      DocumentUploadNotifier.new,
    );
