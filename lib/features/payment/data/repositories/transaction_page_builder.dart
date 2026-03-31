import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rentdone/features/payment/data/models/transaction_record_dto.dart';
import 'package:rentdone/features/payment/data/repositories/datetime_converter.dart';
import 'package:rentdone/features/payment/data/repositories/transaction_doc_filters.dart';
import 'package:rentdone/features/payment/domain/entities/transaction_record.dart';
import 'package:rentdone/features/payment/domain/repositories/payment_repository.dart';

class TransactionPageBuilder {
  final QuerySnapshot<Map<String, dynamic>> snapshot;
  final int year;
  final String? status;
  final int limit;
  final DateTime? startAfterCreatedAt;
  final String? startAfterDocId;

  TransactionPageBuilder({
    required this.snapshot,
    required this.year,
    required this.status,
    required this.limit,
    required this.startAfterCreatedAt,
    required this.startAfterDocId,
  });

  TransactionPage build() {
    var filtered = _filterDocs();
    filtered.sort(_compareDocs);
    final paged = _applyPagination(filtered);
    return TransactionPage(
      items: _mapToEntities(paged),
      nextCreatedAt: snapshot.docs.isNotEmpty
          ? DateTimeConverter.toDate(snapshot.docs.last.data()['createdAt'])
          : null,
      nextDocId: snapshot.docs.isNotEmpty ? snapshot.docs.last.id : null,
      hasMore: paged.length > limit,
    );
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filterDocs() {
    return snapshot.docs
        .where((doc) => TransactionDocFilters.matches(doc, year, status))
        .toList();
  }

  int _compareDocs(
    QueryDocumentSnapshot<Map<String, dynamic>> left,
    QueryDocumentSnapshot<Map<String, dynamic>> right,
  ) {
    final l =
        DateTimeConverter.toDate(left.data()['createdAt']) ?? DateTime(1970);
    final r =
        DateTimeConverter.toDate(right.data()['createdAt']) ?? DateTime(1970);
    final cmp = r.compareTo(l);
    return cmp != 0 ? cmp : right.id.compareTo(left.id);
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _applyPagination(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) => docs
      .where(
        (doc) => TransactionDocFilters.isAfterCursor(
          doc,
          startAfterCreatedAt,
          startAfterDocId,
        ),
      )
      .take(limit)
      .toList();

  List<TransactionRecord> _mapToEntities(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs
        .map(
          (doc) =>
              TransactionRecordDto.fromFirestore(doc.id, doc.data()).toEntity(),
        )
        .toList();
  }
}
