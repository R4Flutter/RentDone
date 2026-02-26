import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/features/tenant/data/models/tenant_complaint.dart';
import 'package:rentdone/features/tenant/data/models/tenant_document.dart';
import 'package:rentdone/features/tenant/data/models/tenant_owner_details.dart';
import 'package:rentdone/features/tenant/data/models/tenant_payment.dart';
import 'package:rentdone/features/tenant/data/models/tenant_reminder.dart';
import 'package:rentdone/features/tenant/data/models/tenant_room_details.dart';
import 'package:rentdone/features/tenant/data/repositories/tenant_dashboard_repository_impl.dart';
import 'package:rentdone/features/tenant/data/services/cloudinary_document_service.dart';
import 'package:rentdone/features/tenant/data/services/tenant_firestore_service.dart';
import 'package:rentdone/features/tenant/domain/entities/tenant_dashboard_summary.dart';
import 'package:rentdone/features/tenant/domain/repositories/tenant_dashboard_repository.dart';

final dioProvider = Provider<Dio>((ref) => Dio());

final tenantFirestoreServiceProvider = Provider<TenantFirestoreService>(
  (ref) => TenantFirestoreService(),
);

final cloudinaryDocumentServiceProvider = Provider<CloudinaryDocumentService>(
  (ref) => CloudinaryDocumentService(dio: ref.read(dioProvider)),
);

final tenantDashboardRepositoryProvider = Provider<TenantDashboardRepository>(
  (ref) => TenantDashboardRepositoryImpl(
    auth: FirebaseAuth.instance,
    firestoreService: ref.read(tenantFirestoreServiceProvider),
    cloudinaryService: ref.read(cloudinaryDocumentServiceProvider),
  ),
);

final tenantDashboardProvider =
    FutureProvider.autoDispose<TenantDashboardSummary>((ref) async {
      final repository = ref.read(tenantDashboardRepositoryProvider);
      const retryDelays = <Duration>[
        Duration.zero,
        Duration(milliseconds: 700),
        Duration(milliseconds: 1200),
        Duration(milliseconds: 2000),
      ];

      TenantDashboardSummary? lastSummary;
      Object? lastError;
      StackTrace? lastStackTrace;

      for (final delay in retryDelays) {
        if (delay > Duration.zero) {
          await Future<void>.delayed(delay);
        }

        try {
          final summary = await repository.getDashboardSummary();
          lastSummary = summary;
          if (summary.tenantId.isNotEmpty) {
            return summary;
          }
        } catch (error, stackTrace) {
          lastError = error;
          lastStackTrace = stackTrace;
        }
      }

      if (lastSummary != null) {
        return lastSummary;
      }

      if (lastError != null && lastStackTrace != null) {
        Error.throwWithStackTrace(lastError, lastStackTrace);
      }

      return TenantDashboardSummary.empty;
    });

final currentMonthPaymentProvider = StreamProvider.autoDispose
    .family<TenantPayment?, String>((ref, tenantId) {
      return ref
          .read(tenantDashboardRepositoryProvider)
          .watchCurrentMonthPayment(tenantId);
    });

final recentTenantDocumentsProvider = FutureProvider.autoDispose
    .family<List<TenantDocument>, String>((ref, tenantId) {
      if (tenantId.isEmpty) {
        return Future.value(const <TenantDocument>[]);
      }

      return ref
          .read(tenantDashboardRepositoryProvider)
          .getDocumentsPage(tenantId, limit: 3);
    });

final tenantRoomDetailsProvider = FutureProvider.autoDispose
    .family<TenantRoomDetails?, String>((ref, tenantId) {
      if (tenantId.isEmpty) {
        return Future.value(null);
      }
      return ref
          .read(tenantDashboardRepositoryProvider)
          .getRoomDetails(tenantId);
    });

final tenantOwnerDetailsProvider = FutureProvider.autoDispose
    .family<TenantOwnerDetails?, String>((ref, tenantId) {
      if (tenantId.isEmpty) {
        return Future.value(null);
      }
      return ref
          .read(tenantDashboardRepositoryProvider)
          .getOwnerDetails(tenantId);
    });

final recentTenantRemindersProvider = FutureProvider.autoDispose
    .family<List<TenantReminder>, String>((ref, tenantId) {
      if (tenantId.isEmpty) {
        return Future.value(const <TenantReminder>[]);
      }

      return ref
          .read(tenantDashboardRepositoryProvider)
          .getRecentReminders(tenantId);
    });

class TenantDocumentsState {
  final AsyncValue<List<TenantDocument>> documents;
  final String? lastDocumentId;
  final bool hasMore;
  final bool isLoadingMore;

  const TenantDocumentsState({
    required this.documents,
    required this.lastDocumentId,
    required this.hasMore,
    required this.isLoadingMore,
  });

  factory TenantDocumentsState.initial() {
    return const TenantDocumentsState(
      documents: AsyncValue.data(<TenantDocument>[]),
      lastDocumentId: null,
      hasMore: true,
      isLoadingMore: false,
    );
  }

  TenantDocumentsState copyWith({
    AsyncValue<List<TenantDocument>>? documents,
    String? lastDocumentId,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return TenantDocumentsState(
      documents: documents ?? this.documents,
      lastDocumentId: lastDocumentId ?? this.lastDocumentId,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

final tenantDocumentsProvider =
    NotifierProvider<TenantDocumentsNotifier, TenantDocumentsState>(
      TenantDocumentsNotifier.new,
    );

class TenantDocumentsNotifier extends Notifier<TenantDocumentsState> {
  TenantDashboardRepository get _repository =>
      ref.read(tenantDashboardRepositoryProvider);

  @override
  TenantDocumentsState build() {
    return TenantDocumentsState.initial();
  }

  Future<void> loadInitial(String tenantId) async {
    state = state.copyWith(
      documents: const AsyncValue.loading(),
      lastDocumentId: null,
      hasMore: true,
      isLoadingMore: false,
    );

    try {
      final page = await _repository.getDocumentsPage(tenantId);
      state = state.copyWith(
        documents: AsyncValue.data(page),
        lastDocumentId: page.isEmpty ? null : page.last.id,
        hasMore: page.length >= 20,
      );
    } catch (e, st) {
      state = state.copyWith(documents: AsyncValue.error(e, st));
    }
  }

  Future<void> loadMore(String tenantId) async {
    if (!state.hasMore || state.isLoadingMore) {
      return;
    }

    final current = state.documents is AsyncData<List<TenantDocument>>
        ? (state.documents as AsyncData<List<TenantDocument>>).value
        : <TenantDocument>[];
    state = state.copyWith(isLoadingMore: true);

    try {
      final page = await _repository.getDocumentsPage(
        tenantId,
        lastDocumentId: state.lastDocumentId,
      );
      final merged = [...current, ...page];
      state = state.copyWith(
        documents: AsyncValue.data(merged),
        lastDocumentId: page.isEmpty ? state.lastDocumentId : page.last.id,
        hasMore: page.length >= 20,
        isLoadingMore: false,
      );
    } catch (e, st) {
      state = state.copyWith(
        documents: AsyncValue.error(e, st),
        isLoadingMore: false,
      );
    }
  }

  Future<void> upload({
    required String tenantId,
    required PlatformFile picked,
    required String description,
  }) async {
    final path = picked.path;
    if (path == null || path.isEmpty) {
      throw Exception('Invalid file path');
    }

    await _repository.uploadDocument(
      tenantId: tenantId,
      file: File(path),
      fileName: picked.name,
      description: description,
      fileSizeBytes: picked.size,
    );

    await loadInitial(tenantId);
  }

  Future<void> delete(String tenantId, TenantDocument document) async {
    await _repository.deleteDocument(tenantId: tenantId, document: document);
    await loadInitial(tenantId);
  }
}

final complaintSubmittingProvider =
    NotifierProvider<ComplaintSubmittingNotifier, bool>(
      ComplaintSubmittingNotifier.new,
    );

class ComplaintSubmittingNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setSubmitting(bool value) {
    state = value;
  }
}

Future<void> submitComplaint(
  WidgetRef ref, {
  required TenantDashboardSummary summary,
  required String description,
  required String category,
}) async {
  ref.read(complaintSubmittingProvider.notifier).setSubmitting(true);
  try {
    await ref
        .read(tenantDashboardRepositoryProvider)
        .submitComplaintAndOpenWhatsApp(
          summary: summary,
          complaint: TenantComplaint(
            description: description,
            category: category,
          ),
        );
  } finally {
    ref.read(complaintSubmittingProvider.notifier).setSubmitting(false);
  }
}

Future<void> saveTenantRoomDetails(
  WidgetRef ref, {
  required String tenantId,
  required TenantRoomDetails details,
}) async {
  await ref
      .read(tenantDashboardRepositoryProvider)
      .saveRoomDetails(tenantId: tenantId, details: details);
  ref.invalidate(tenantRoomDetailsProvider(tenantId));
  ref.invalidate(tenantDashboardProvider);
}

Future<void> saveTenantOwnerDetails(
  WidgetRef ref, {
  required String tenantId,
  required TenantOwnerDetails details,
}) async {
  await ref
      .read(tenantDashboardRepositoryProvider)
      .saveOwnerDetails(tenantId: tenantId, details: details);
  ref.invalidate(tenantOwnerDetailsProvider(tenantId));
  ref.invalidate(tenantDashboardProvider);
}

Future<void> markTenantPaymentAsPaid(
  WidgetRef ref, {
  required String tenantId,
  required int amountPaid,
  required DateTime paymentDate,
  required String paymentMethod,
  required int monthlyRent,
}) async {
  await ref
      .read(tenantDashboardRepositoryProvider)
      .markPaymentAsPaid(
        tenantId: tenantId,
        amountPaid: amountPaid,
        paymentDate: paymentDate,
        paymentMethod: paymentMethod,
        monthlyRent: monthlyRent,
      );

  ref.invalidate(currentMonthPaymentProvider(tenantId));
  ref.invalidate(recentTenantRemindersProvider(tenantId));
  ref.invalidate(tenantDashboardProvider);
}
