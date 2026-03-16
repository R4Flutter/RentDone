import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart';
import 'package:rentdone/features/owner/reports/domain/entities/report_filter.dart';
import 'package:rentdone/features/owner/reports/domain/entities/report_data.dart';

class ReportsFirebaseService {
  ReportsFirebaseService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseStorage? storage,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseStorage _storage;

  String _ownerIdOrThrow() {
    final ownerId = _auth.currentUser?.uid;
    if (ownerId == null || ownerId.isEmpty) {
      throw StateError('Owner is not authenticated.');
    }
    return ownerId;
  }

  Future<List<int>> getYearOptions() async {
    final ownerId = _ownerIdOrThrow();
    final snapshot = await _firestore
        .collection('payments')
        .where('ownerId', isEqualTo: ownerId)
        .limit(300)
        .get();

    final years = <int>{DateTime.now().year};
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final date = _asDate(data['date']) ?? _asDate(data['createdAt']);
      if (date != null) {
        years.add(date.year);
      }
    }

    final sorted = years.toList()..sort((a, b) => b.compareTo(a));
    return sorted;
  }

  Future<List<ReportPropertyOption>> getPropertyOptions() async {
    final ownerId = _ownerIdOrThrow();
    final snapshot = await _firestore
        .collection('properties')
        .where('ownerId', isEqualTo: ownerId)
        .get();

    final list =
        snapshot.docs
            .map(
              (doc) => ReportPropertyOption(
                id: doc.id,
                name: ((doc.data()['name'] ?? 'Unnamed Property') as String)
                    .trim(),
              ),
            )
            .toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );

    return list;
  }

  Future<ReportData> getReportData({
    required ReportFilter filter,
    String? propertyId,
  }) async {
    final ownerId = _ownerIdOrThrow();

    final propertiesSnapshot = await _firestore
        .collection('properties')
        .where('ownerId', isEqualTo: ownerId)
        .get();
    final tenantsSnapshot = await _firestore
        .collection('tenants')
        .where('ownerId', isEqualTo: ownerId)
        .get();

    final properties = propertiesSnapshot.docs;
    final tenants = tenantsSnapshot.docs;

    final selectedPropertyId = (propertyId ?? '').trim();
    final selectedPropertyIds = selectedPropertyId.isEmpty
        ? properties.map((doc) => doc.id).toSet()
        : <String>{selectedPropertyId};

    final paymentsQuery = _firestore
        .collection('payments')
        .where('ownerId', isEqualTo: ownerId)
        .where(
          'date',
          isGreaterThanOrEqualTo: Timestamp.fromDate(filter.startDate),
        )
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(filter.endDate));

    final paymentsSnapshot = await paymentsQuery.get();
    final allPayments = paymentsSnapshot.docs.where((doc) {
      final pid = (doc.data()['propertyId'] as String? ?? '').trim();
      return selectedPropertyIds.contains(pid);
    }).toList();

    final filteredTenants = tenants.where((doc) {
      final pid = (doc.data()['propertyId'] as String? ?? '').trim();
      return selectedPropertyIds.contains(pid);
    }).toList();

    final filteredProperties = properties.where((doc) {
      return selectedPropertyIds.contains(doc.id);
    }).toList();

    final propertyNameById = <String, String>{
      for (final doc in properties)
        doc.id: ((doc.data()['name'] ?? 'Property') as String).trim(),
    };

    final monthsInRange = _monthSpan(filter.startDate, filter.endDate);

    final expectedMonthly = filteredTenants.fold<int>(
      0,
      (total, doc) =>
          total + ((doc.data()['rentAmount'] as num?)?.toInt() ?? 0),
    );

    final expected = expectedMonthly * max<int>(1, monthsInRange);

    int collected = 0;
    final paymentMethodTotals = <String, int>{
      'UPI': 0,
      'Cash': 0,
      'Bank Transfer': 0,
    };

    final paidByTenant = <String, int>{};
    final latestStatusByTenant = <String, String>{};

    for (final doc in allPayments) {
      final data = doc.data();
      final amount = (data['amount'] as num?)?.toInt() ?? 0;
      final status = (data['status'] as String? ?? 'unpaid').toLowerCase();
      final tenantId = (data['tenantId'] as String? ?? '').trim();
      final method = ((data['method'] ?? 'Cash') as String).trim();

      if (status == 'paid' || status == 'partial') {
        collected += amount;
        paidByTenant[tenantId] = (paidByTenant[tenantId] ?? 0) + amount;
        paymentMethodTotals[method] =
            (paymentMethodTotals[method] ?? 0) + amount;
      }

      latestStatusByTenant[tenantId] = status;
    }

    final pending = max<int>(0, expected - collected);
    final rate = expected == 0 ? 0.0 : (collected / expected) * 100;

    final propertyIncome = filteredProperties.map((property) {
      final pid = property.id;
      final propertyTenants = filteredTenants.where(
        (tenant) =>
            (tenant.data()['propertyId'] as String? ?? '').trim() == pid,
      );
      final propertyExpectedMonthly = propertyTenants.fold<int>(
        0,
        (total, tenant) =>
            total + ((tenant.data()['rentAmount'] as num?)?.toInt() ?? 0),
      );
      final propertyExpected =
          propertyExpectedMonthly * max<int>(1, monthsInRange);

      final propertyCollected = allPayments
          .where(
            (payment) =>
                ((payment.data()['propertyId'] as String? ?? '').trim() ==
                    pid) &&
                _isCollected(payment.data()['status'] as String?),
          )
          .fold<int>(
            0,
            (total, payment) =>
                total + ((payment.data()['amount'] as num?)?.toInt() ?? 0),
          );

      return PropertyIncomeReport(
        propertyId: pid,
        propertyName: propertyNameById[pid] ?? 'Property',
        expected: propertyExpected,
        collected: propertyCollected,
        pending: max<int>(0, propertyExpected - propertyCollected),
      );
    }).toList();

    final tenantStatuses = filteredTenants.map((tenant) {
      final data = tenant.data();
      final tenantId = tenant.id;
      final propertyId = (data['propertyId'] as String? ?? '').trim();
      final status = latestStatusByTenant[tenantId] ?? 'unpaid';

      return TenantPaymentStatusReport(
        tenantId: tenantId,
        tenantName: ((data['fullName'] ?? data['name'] ?? 'Tenant') as String)
            .trim(),
        roomNumber: ((data['roomNumber'] ?? data['roomId'] ?? 'NA') as String)
            .trim(),
        propertyName: propertyNameById[propertyId] ?? 'Property',
        monthlyRent: (data['rentAmount'] as num?)?.toInt() ?? 0,
        status: _normalizeStatus(status),
      );
    }).toList();

    final now = DateTime.now();
    final overdue = <OverdueTenantReport>[];

    for (final tenant in filteredTenants) {
      final data = tenant.data();
      final tenantId = tenant.id;
      final status = _normalizeStatus(
        latestStatusByTenant[tenantId] ?? 'unpaid',
      );
      if (status == 'paid') continue;

      final dueDay =
          ((data['rentDueDay'] ?? data['rentDueDate']) as num?)?.toInt() ?? 5;
      final safeDueDay = dueDay.clamp(1, 28).toInt();
      final dueDate = DateTime(now.year, now.month, safeDueDay);
      final daysLate = now.isAfter(dueDate)
          ? now.difference(dueDate).inDays
          : 0;
      if (daysLate <= 0) continue;

      final monthlyRent = (data['rentAmount'] as num?)?.toInt() ?? 0;
      overdue.add(
        OverdueTenantReport(
          tenantId: tenantId,
          tenantName: ((data['fullName'] ?? data['name'] ?? 'Tenant') as String)
              .trim(),
          roomNumber: ((data['roomNumber'] ?? data['roomId'] ?? 'NA') as String)
              .trim(),
          pendingAmount: monthlyRent,
          daysLate: daysLate,
        ),
      );
    }

    final trend = await _buildSixMonthTrend(
      ownerId: ownerId,
      selectedPropertyIds: selectedPropertyIds,
    );

    final yearlyStart = DateTime(now.year, 1, 1);
    final yearlyEnd = DateTime(now.year, 12, 31, 23, 59, 59);
    final yearlyPayments = await _firestore
        .collection('payments')
        .where('ownerId', isEqualTo: ownerId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(yearlyStart))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(yearlyEnd))
        .get();

    final yearlyEarnings = yearlyPayments.docs
        .where((doc) {
          final pid = (doc.data()['propertyId'] as String? ?? '').trim();
          return selectedPropertyIds.contains(pid) &&
              _isCollected(doc.data()['status'] as String?);
        })
        .fold<int>(
          0,
          (total, doc) =>
              total + ((doc.data()['amount'] as num?)?.toInt() ?? 0),
        );

    int totalRooms = 0;
    for (final property in filteredProperties) {
      final data = property.data();
      if (data['totalRooms'] is num) {
        totalRooms += (data['totalRooms'] as num).toInt();
      } else if (data['rooms'] is List) {
        totalRooms += (data['rooms'] as List).length;
      }
    }

    final occupiedRooms = filteredTenants.where((tenant) {
      final data = tenant.data();
      return data['isActive'] != false;
    }).length;

    final vacancy = VacancyReport(
      totalRooms: totalRooms,
      occupiedRooms: min<int>(occupiedRooms, totalRooms),
      vacantRooms: max<int>(0, totalRooms - occupiedRooms),
    );

    final topTenants =
        filteredTenants
            .map((tenant) {
              final data = tenant.data();
              final propertyId = (data['propertyId'] as String? ?? '').trim();
              return TopPayingTenantReport(
                tenantId: tenant.id,
                tenantName:
                    ((data['fullName'] ?? data['name'] ?? 'Tenant') as String)
                        .trim(),
                propertyName: propertyNameById[propertyId] ?? 'Property',
                totalPaid: paidByTenant[tenant.id] ?? 0,
              );
            })
            .where((entry) => entry.totalPaid > 0)
            .toList()
          ..sort((a, b) => b.totalPaid.compareTo(a.totalPaid));

    return ReportData(
      monthlySummary: MonthlySummary(
        expected: expected,
        collected: collected,
        pending: pending,
        collectionRate: rate,
      ),
      propertyIncome: propertyIncome,
      tenantStatuses: tenantStatuses,
      overdueTenants: overdue,
      monthlyTrend: trend,
      paymentMethodBreakdown: paymentMethodTotals.entries
          .map(
            (entry) =>
                PaymentMethodBreakdown(method: entry.key, amount: entry.value),
          )
          .toList(),
      yearlyEarnings: yearlyEarnings,
      vacancyReport: vacancy,
      topPayingTenants: topTenants.take(5).toList(),
    );
  }

  Future<String> exportReport({
    required String format,
    required ReportData data,
    required ReportFilter filter,
    String? propertyId,
  }) async {
    final ownerId = _ownerIdOrThrow();
    final normalized = format.toLowerCase();

    final storageRef = _storage
        .ref()
        .child('reports')
        .child(ownerId)
        .child('report_${DateTime.now().millisecondsSinceEpoch}.$normalized');

    if (normalized == 'pdf') {
      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (_) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('RentDone Reports Dashboard'),
                pw.SizedBox(height: 12),
                pw.Text('Expected: ${data.monthlySummary.expected}'),
                pw.Text('Collected: ${data.monthlySummary.collected}'),
                pw.Text('Pending: ${data.monthlySummary.pending}'),
                pw.Text(
                  'Collection Rate: ${data.monthlySummary.collectionRate.toStringAsFixed(1)}%',
                ),
              ],
            );
          },
        ),
      );
      final bytes = await pdf.save();
      await storageRef.putData(
        bytes,
        SettableMetadata(contentType: 'application/pdf'),
      );
    } else {
      final excel = Excel.createExcel();
      final sheet = excel['Report'];
      sheet.cell(CellIndex.indexByString('A1')).value = TextCellValue('Metric');
      sheet.cell(CellIndex.indexByString('B1')).value = TextCellValue('Value');
      sheet.cell(CellIndex.indexByString('A2')).value = TextCellValue(
        'Expected',
      );
      sheet.cell(CellIndex.indexByString('B2')).value = IntCellValue(
        data.monthlySummary.expected,
      );
      sheet.cell(CellIndex.indexByString('A3')).value = TextCellValue(
        'Collected',
      );
      sheet.cell(CellIndex.indexByString('B3')).value = IntCellValue(
        data.monthlySummary.collected,
      );
      sheet.cell(CellIndex.indexByString('A4')).value = TextCellValue(
        'Pending',
      );
      sheet.cell(CellIndex.indexByString('B4')).value = IntCellValue(
        data.monthlySummary.pending,
      );

      final bytes = excel.encode();
      if (bytes == null) {
        throw StateError('Unable to export report data.');
      }
      await storageRef.putData(
        Uint8List.fromList(bytes),
        SettableMetadata(
          contentType:
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        ),
      );
    }

    return storageRef.getDownloadURL();
  }

  Future<List<MonthlyCollectionPoint>> _buildSixMonthTrend({
    required String ownerId,
    required Set<String> selectedPropertyIds,
  }) async {
    final now = DateTime.now();
    final points = <MonthlyCollectionPoint>[];

    for (int i = 5; i >= 0; i--) {
      final monthDate = DateTime(now.year, now.month - i, 1);
      final start = DateTime(monthDate.year, monthDate.month, 1);
      final end = DateTime(monthDate.year, monthDate.month + 1, 0, 23, 59, 59);

      final snapshot = await _firestore
          .collection('payments')
          .where('ownerId', isEqualTo: ownerId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .get();

      final amount = snapshot.docs
          .where((doc) {
            final pid = (doc.data()['propertyId'] as String? ?? '').trim();
            return selectedPropertyIds.contains(pid) &&
                _isCollected(doc.data()['status'] as String?);
          })
          .fold<int>(
            0,
            (total, doc) =>
                total + ((doc.data()['amount'] as num?)?.toInt() ?? 0),
          );

      points.add(
        MonthlyCollectionPoint(
          label: _shortMonth(monthDate.month),
          amount: amount,
        ),
      );
    }

    return points;
  }

  int _monthSpan(DateTime start, DateTime end) {
    return ((end.year - start.year) * 12) + end.month - start.month + 1;
  }

  bool _isCollected(String? status) {
    final value = (status ?? '').trim().toLowerCase();
    return value == 'paid' || value == 'partial';
  }

  String _normalizeStatus(String status) {
    final value = status.trim().toLowerCase();
    if (value == 'paid') return 'paid';
    if (value == 'partial') return 'partial';
    return 'unpaid';
  }

  DateTime? _asDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  String _shortMonth(int month) {
    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }
}
