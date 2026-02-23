import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/tenant_dashboard_summary.dart';

final tenantDashboardProvider = FutureProvider<TenantDashboardSummary>((
  ref,
) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null || user.email == null) {
    return TenantDashboardSummary.empty;
  }

  final db = FirebaseFirestore.instance;

  try {
    // Find tenant document by email
    final tenantQuery = await db
        .collection('tenants')
        .where('email', isEqualTo: user.email)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();

    if (tenantQuery.docs.isEmpty) {
      return TenantDashboardSummary.empty;
    }

    final tenantDoc = tenantQuery.docs.first;
    final tenantData = tenantDoc.data();

    // Get property details
    final propertyId = tenantData['propertyId'] as String?;
    String? propertyName;
    String? ownerName;
    String? ownerPhone;
    String? roomNumber;

    if (propertyId != null) {
      try {
        final propertyDoc = await db
            .collection('properties')
            .doc(propertyId)
            .get();
        if (propertyDoc.exists) {
          final propertyData = propertyDoc.data();
          propertyName = propertyData?['name'] as String?;

          // Find room number
          final rooms = propertyData?['rooms'] as List?;
          final roomId = tenantData['roomId'] as String?;
          if (rooms != null && roomId != null) {
            final room = rooms.firstWhere(
              (r) => r['id'] == roomId,
              orElse: () => null,
            );
            roomNumber = room?['roomNumber'] as String?;
          }

          // Try to get owner details from property document if stored there
          ownerName = propertyData?['ownerName'] as String?;
          ownerPhone = propertyData?['ownerPhone'] as String?;
        }
      } catch (e) {
        // Property read might fail, continue with partial data
      }
    }

    // Get payment transactions
    final transactionsQuery = await db
        .collection('payments')
        .where('tenantId', isEqualTo: tenantDoc.id)
        .orderBy('createdAt', descending: true)
        .get();

    int totalTransactions = transactionsQuery.docs.length;
    int successfulPayments = 0;
    int paidAmount = 0;
    int pendingAmount = 0;
    DateTime? nextDueDate;

    final now = DateTime.now();

    for (final doc in transactionsQuery.docs) {
      final data = doc.data();
      final status = data['status'] as String?;
      final amount = data['amount'] as int? ?? 0;

      if (status == 'success' || status == 'completed') {
        successfulPayments++;
        paidAmount += amount;
      } else if (status == 'pending' || status == 'due') {
        pendingAmount += amount;
        final dueDate = (data['dueDate'] as Timestamp?)?.toDate();
        if (dueDate != null &&
            (nextDueDate == null || dueDate.isBefore(nextDueDate))) {
          nextDueDate = dueDate;
        }
      }
    }

    // Calculate pending amount based on rent due day if no pending transactions
    final rentAmount = tenantData['rentAmount'] as int? ?? 0;
    final rentDueDay = tenantData['rentDueDay'] as int? ?? 1;

    if (pendingAmount == 0 && rentAmount > 0) {
      final dueDate = DateTime(now.year, now.month, rentDueDay);
      if (now.isAfter(dueDate)) {
        pendingAmount = rentAmount;
        nextDueDate = dueDate;
      } else {
        nextDueDate = dueDate;
      }
    }

    return TenantDashboardSummary(
      totalDueAmount: pendingAmount,
      paidAmount: paidAmount,
      pendingAmount: pendingAmount,
      nextDueDate: nextDueDate,
      propertyName: propertyName,
      roomNumber: roomNumber,
      ownerName: ownerName,
      ownerPhone: ownerPhone,
      rentAmount: rentAmount,
      leaseStartDate: (tenantData['moveInDate'] as Timestamp?)?.toDate(),
      leaseEndDate: (tenantData['agreementEndDate'] as Timestamp?)?.toDate(),
      totalTransactions: totalTransactions,
      successfulPayments: successfulPayments,
    );
  } catch (e) {
    // Return empty on error - could also log this
    return TenantDashboardSummary.empty;
  }
});
