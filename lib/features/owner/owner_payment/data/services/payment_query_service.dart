import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rentdone/features/owner/owner_payment/data/models/payment_dto.dart';
import 'package:rentdone/features/owner/owner_payment/data/models/tenant_payment_record_dto.dart';
import 'package:rentdone/features/owner/owner_payment/domain/entities/tenant_payment_history_page.dart';

class PaymentQueryService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  PaymentQueryService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  static const int _paymentsStreamLimit = 50;

  String _currentUserIdOrThrow() {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.trim().isEmpty) {
      throw StateError('User is not authenticated.');
    }
    return uid.trim();
  }

  Stream<List<PaymentDto>> watchPayments() {
    final ownerId = _auth.currentUser?.uid;
    if (ownerId == null || ownerId.isEmpty) {
      return const Stream<List<PaymentDto>>.empty();
    }

    return _firestore
        .collection('payments')
        .where('ownerId', isEqualTo: ownerId)
        .orderBy('dueDate', descending: true)
        .limit(_paymentsStreamLimit)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return PaymentDto.fromFirestore(doc.id, doc.data());
          }).toList();
        });
  }

  Future<TenantPaymentHistoryPage> fetchTenantPayments({
    required String tenantId,
    int limit = 20,
    DocumentSnapshot<Map<String, dynamic>>? cursor,
  }) async {
    final uid = _currentUserIdOrThrow();
    final isTenantSelf = uid == tenantId.trim();

    Query<Map<String, dynamic>> query = _firestore
        .collection('payments')
        .where('tenantId', isEqualTo: tenantId)
        .orderBy('date', descending: true)
        .orderBy(FieldPath.documentId, descending: true);
        
    if (!isTenantSelf) {
      query = query.where('ownerId', isEqualTo: uid);
    }
    
    if (cursor != null) {
      query = query.startAfterDocument(cursor);
    }
    
    query = query.limit(limit + 1);

    final snapshot = await query.get();
    final pageDocs = snapshot.docs.take(limit).toList();
    final hasMore = snapshot.docs.length > limit;
    final items = pageDocs
        .map((doc) => TenantPaymentRecordDto.fromFirestore(doc.id, doc.data()))
        .toList();
    final nextCursor = hasMore && pageDocs.isNotEmpty ? pageDocs.last : null;

    return TenantPaymentHistoryPage(
      items: items,
      hasMore: hasMore,
      nextCursor: nextCursor,
    );
  }
}
