import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
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

    final paymentsInRange = await _queryPaymentsInDateRange(
      ownerId: ownerId,
      start: filter.startDate,
      end: filter.endDate,
    );

    final allPayments = paymentsInRange.where((doc) {
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
    final roomNameByPropertyAndRoomId = <String, String>{};
    for (final property in filteredProperties) {
      final propertyId = property.id;
      final byRoomId = _extractRoomNameById(property.data());
      for (final entry in byRoomId.entries) {
        roomNameByPropertyAndRoomId['$propertyId::${entry.key}'] = entry.value;
      }
    }

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
        roomNumber: _resolveTenantRoomLabel(
          tenantData: data,
          propertyId: propertyId,
          roomNameByPropertyAndRoomId: roomNameByPropertyAndRoomId,
        ),
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
      final propertyId = (data['propertyId'] as String? ?? '').trim();
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
          roomNumber: _resolveTenantRoomLabel(
            tenantData: data,
            propertyId: propertyId,
            roomNameByPropertyAndRoomId: roomNameByPropertyAndRoomId,
          ),
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
    final yearlyPayments = await _queryPaymentsInDateRange(
      ownerId: ownerId,
      start: yearlyStart,
      end: yearlyEnd,
    );

    final yearlyEarnings = yearlyPayments
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
    final bytes = await _buildExportBytes(
      normalized: normalized,
      data: data,
      filter: filter,
      propertyId: propertyId,
    );
    final contentType = normalized == 'pdf'
        ? 'application/pdf'
        : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    final fileName =
        'report_${DateTime.now().millisecondsSinceEpoch}.$normalized';

    final storageRef = _storage
        .ref()
        .child('reports')
        .child(ownerId)
        .child(fileName);

    try {
      await storageRef.putData(
        bytes,
        SettableMetadata(contentType: contentType),
      );
      return storageRef.getDownloadURL();
    } on FirebaseException {
      return _persistExportLocally(
        bytes: bytes,
        ownerId: ownerId,
        fileName: fileName,
      );
    }
  }

  Future<Uint8List> _buildExportBytes({
    required String normalized,
    required ReportData data,
    required ReportFilter filter,
    String? propertyId,
  }) async {
    if (normalized == 'pdf') {
      return _buildProfessionalPdf(
        data: data,
        filter: filter,
        propertyId: propertyId,
      );
    }

    if (normalized != 'xlsx') {
      throw StateError('Unsupported export format: $normalized');
    }

    return _buildProfessionalExcel(
      data: data,
      filter: filter,
      propertyId: propertyId,
    );
  }

  Future<Uint8List> _buildProfessionalPdf({
    required ReportData data,
    required ReportFilter filter,
    String? propertyId,
  }) async {
    final pdf = pw.Document();
    final generatedAt = DateTime.now();

    pw.Widget heading(String text) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(top: 12, bottom: 6),
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: 13,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue900,
          ),
        ),
      );
    }

    pw.Widget simpleTable(List<String> headers, List<List<String>> rows) {
      final safeRows = rows.isEmpty
          ? <List<String>>[List<String>.filled(headers.length, '-')]
          : rows;

      return pw.Table.fromTextArray(
        headers: headers,
        data: safeRows,
        headerStyle: pw.TextStyle(
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
          fontSize: 9,
        ),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.blue700),
        cellStyle: const pw.TextStyle(fontSize: 9),
        cellAlignment: pw.Alignment.centerLeft,
        headerAlignment: pw.Alignment.centerLeft,
        border: pw.TableBorder.all(color: PdfColors.blueGrey100, width: 0.5),
        rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (_) => [
          pw.Text(
            'RentDone Owner Report',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Period: ${_formatDate(filter.startDate)} to ${_formatDate(filter.endDate)}',
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.Text(
            'Property: ${(propertyId ?? '').trim().isEmpty ? 'All Properties' : propertyId!.trim()}',
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.Text(
            'Generated: ${_formatDateTime(generatedAt)}',
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.SizedBox(height: 10),
          heading('Executive Summary'),
          simpleTable(
            const ['Metric', 'Value'],
            [
              ['Expected', _currency(data.monthlySummary.expected)],
              ['Collected', _currency(data.monthlySummary.collected)],
              ['Pending', _currency(data.monthlySummary.pending)],
              [
                'Collection Rate',
                '${data.monthlySummary.collectionRate.toStringAsFixed(1)}%',
              ],
              ['Yearly Earnings', _currency(data.yearlyEarnings)],
              [
                'Vacancy',
                '${data.vacancyReport.vacantRooms}/${data.vacancyReport.totalRooms}',
              ],
            ],
          ),
          heading('Property Income Breakdown'),
          simpleTable(
            const ['Property', 'Expected', 'Collected', 'Pending'],
            data.propertyIncome
                .map(
                  (entry) => [
                    entry.propertyName,
                    _currency(entry.expected),
                    _currency(entry.collected),
                    _currency(entry.pending),
                  ],
                )
                .toList(),
          ),
          heading('Tenant Payment Status'),
          simpleTable(
            const ['Tenant', 'Property', 'Room', 'Monthly Rent', 'Status'],
            data.tenantStatuses
                .map(
                  (entry) => [
                    entry.tenantName,
                    entry.propertyName,
                    entry.roomNumber,
                    _currency(entry.monthlyRent),
                    _titleCase(entry.status),
                  ],
                )
                .toList(),
          ),
          heading('Overdue Tenants'),
          simpleTable(
            const ['Tenant', 'Room', 'Pending', 'Days Late'],
            data.overdueTenants
                .map(
                  (entry) => [
                    entry.tenantName,
                    entry.roomNumber,
                    _currency(entry.pendingAmount),
                    entry.daysLate.toString(),
                  ],
                )
                .toList(),
          ),
          heading('Payment Method Breakdown'),
          simpleTable(
            const ['Method', 'Amount'],
            data.paymentMethodBreakdown
                .map((entry) => [entry.method, _currency(entry.amount)])
                .toList(),
          ),
          heading('Monthly Collection Trend'),
          simpleTable(
            const ['Month', 'Collected'],
            data.monthlyTrend
                .map((entry) => [entry.label, _currency(entry.amount)])
                .toList(),
          ),
          heading('Top Paying Tenants'),
          simpleTable(
            const ['Tenant', 'Property', 'Total Paid'],
            data.topPayingTenants
                .map(
                  (entry) => [
                    entry.tenantName,
                    entry.propertyName,
                    _currency(entry.totalPaid),
                  ],
                )
                .toList(),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  Uint8List _buildProfessionalExcel({
    required ReportData data,
    required ReportFilter filter,
    String? propertyId,
  }) {
    final excel = Excel.createExcel();
    final defaultSheetName = excel.getDefaultSheet() ?? 'Sheet1';

    if (defaultSheetName != 'Summary') {
      try {
        excel.rename(defaultSheetName, 'Summary');
      } catch (_) {
        // Keep default sheet name when rename is not supported by the platform package build.
      }
    }

    final summarySheetName = excel.getDefaultSheet() ?? 'Summary';
    final summarySheet = excel[summarySheetName];

    summarySheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
        .value = TextCellValue(
      'RentDone Owner Report',
    );
    summarySheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1))
        .value = TextCellValue(
      'Period: ${_formatDate(filter.startDate)} to ${_formatDate(filter.endDate)}',
    );
    summarySheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2))
        .value = TextCellValue(
      'Property: ${(propertyId ?? '').trim().isEmpty ? 'All Properties' : propertyId!.trim()}',
    );

    final summaryRows = <List<String>>[
      ['Metric', 'Value'],
      ['Expected', _currency(data.monthlySummary.expected)],
      ['Collected', _currency(data.monthlySummary.collected)],
      ['Pending', _currency(data.monthlySummary.pending)],
      [
        'Collection Rate',
        '${data.monthlySummary.collectionRate.toStringAsFixed(1)}%',
      ],
      ['Yearly Earnings', _currency(data.yearlyEarnings)],
      [
        'Vacancy',
        '${data.vacancyReport.vacantRooms}/${data.vacancyReport.totalRooms}',
      ],
    ];
    _writeSheetRows(summarySheet, startRow: 4, rows: summaryRows);

    _writeSheetRows(
      excel['PropertyIncome'],
      rows: [
        ['Property', 'Expected', 'Collected', 'Pending'],
        ...data.propertyIncome.map(
          (entry) => [
            entry.propertyName,
            _currency(entry.expected),
            _currency(entry.collected),
            _currency(entry.pending),
          ],
        ),
      ],
    );

    _writeSheetRows(
      excel['TenantStatus'],
      rows: [
        ['Tenant', 'Property', 'Room', 'Monthly Rent', 'Status'],
        ...data.tenantStatuses.map(
          (entry) => [
            entry.tenantName,
            entry.propertyName,
            entry.roomNumber,
            _currency(entry.monthlyRent),
            _titleCase(entry.status),
          ],
        ),
      ],
    );

    _writeSheetRows(
      excel['Overdue'],
      rows: [
        ['Tenant', 'Room', 'Pending', 'Days Late'],
        ...data.overdueTenants.map(
          (entry) => [
            entry.tenantName,
            entry.roomNumber,
            _currency(entry.pendingAmount),
            entry.daysLate.toString(),
          ],
        ),
      ],
    );

    _writeSheetRows(
      excel['PaymentMethods'],
      rows: [
        ['Method', 'Amount'],
        ...data.paymentMethodBreakdown.map(
          (entry) => [entry.method, _currency(entry.amount)],
        ),
      ],
    );

    _writeSheetRows(
      excel['MonthlyTrend'],
      rows: [
        ['Month', 'Collected'],
        ...data.monthlyTrend.map(
          (entry) => [entry.label, _currency(entry.amount)],
        ),
      ],
    );

    _writeSheetRows(
      excel['TopTenants'],
      rows: [
        ['Tenant', 'Property', 'Total Paid'],
        ...data.topPayingTenants.map(
          (entry) => [
            entry.tenantName,
            entry.propertyName,
            _currency(entry.totalPaid),
          ],
        ),
      ],
    );

    final encoded = excel.encode();
    if (encoded == null) {
      throw StateError('Unable to export report data.');
    }
    return Uint8List.fromList(encoded);
  }

  void _writeSheetRows(
    Sheet sheet, {
    int startRow = 0,
    required List<List<String>> rows,
  }) {
    if (rows.isEmpty) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: startRow))
          .value = TextCellValue(
        'No data',
      );
      return;
    }

    for (var r = 0; r < rows.length; r++) {
      final row = rows[r];
      for (var c = 0; c < row.length; c++) {
        sheet
            .cell(
              CellIndex.indexByColumnRow(
                columnIndex: c,
                rowIndex: startRow + r,
              ),
            )
            .value = TextCellValue(
          row[c],
        );
      }
    }
  }

  Future<String> _persistExportLocally({
    required Uint8List bytes,
    required String ownerId,
    required String fileName,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final ownerDir = Directory(
      '${tempDir.path}${Platform.pathSeparator}rentdone${Platform.pathSeparator}reports${Platform.pathSeparator}$ownerId',
    );
    if (!ownerDir.existsSync()) {
      ownerDir.createSync(recursive: true);
    }

    final filePath = '${ownerDir.path}${Platform.pathSeparator}$fileName';
    final file = File(filePath);
    await file.writeAsBytes(bytes, flush: true);
    return Uri.file(file.path).toString();
  }

  Future<List<MonthlyCollectionPoint>> _buildSixMonthTrend({
    required String ownerId,
    required Set<String> selectedPropertyIds,
  }) async {
    final now = DateTime.now();
    final trendStart = DateTime(now.year, now.month - 5, 1);
    final trendEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    final rangePayments = await _queryPaymentsInDateRange(
      ownerId: ownerId,
      start: trendStart,
      end: trendEnd,
    );

    final points = <MonthlyCollectionPoint>[];

    for (int i = 5; i >= 0; i--) {
      final monthDate = DateTime(now.year, now.month - i, 1);
      final start = DateTime(monthDate.year, monthDate.month, 1);
      final end = DateTime(monthDate.year, monthDate.month + 1, 0, 23, 59, 59);

      final amount = rangePayments
          .where((doc) {
            final date =
                _asDate(doc.data()['date']) ?? _asDate(doc.data()['createdAt']);
            if (date == null) return false;
            final pid = (doc.data()['propertyId'] as String? ?? '').trim();
            return selectedPropertyIds.contains(pid) &&
                !date.isBefore(start) &&
                !date.isAfter(end) &&
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

  String _formatDate(DateTime value) {
    return DateFormat('dd MMM yyyy').format(value);
  }

  String _formatDateTime(DateTime value) {
    return DateFormat('dd MMM yyyy, hh:mm a').format(value);
  }

  String _currency(int amount) {
    return NumberFormat.currency(locale: 'en_IN', symbol: 'Rs ').format(amount);
  }

  String _titleCase(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1).toLowerCase();
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

  Map<String, String> _extractRoomNameById(Map<String, dynamic>? propertyData) {
    final byId = <String, String>{};
    final roomsRaw = propertyData?['rooms'];
    if (roomsRaw is! List) return byId;

    for (final roomRaw in roomsRaw) {
      if (roomRaw is! Map) continue;
      final room = roomRaw.map((k, v) => MapEntry(k.toString(), v));
      final id = (room['id'] ?? '').toString().trim();
      if (id.isEmpty) continue;

      final roomName = (room['name'] ?? '').toString().trim();
      final roomNumber = (room['roomNumber'] ?? '').toString().trim();
      final label = roomName.isNotEmpty ? roomName : roomNumber;
      if (label.isNotEmpty) {
        byId[id] = label;
      }
    }

    return byId;
  }

  String _resolveTenantRoomLabel({
    required Map<String, dynamic> tenantData,
    required String propertyId,
    required Map<String, String> roomNameByPropertyAndRoomId,
  }) {
    final roomId = (tenantData['roomId'] as String? ?? '').trim();
    if (propertyId.isNotEmpty && roomId.isNotEmpty) {
      final mapped = roomNameByPropertyAndRoomId['$propertyId::$roomId']
          ?.trim();
      if (mapped != null && mapped.isNotEmpty) {
        return mapped;
      }
    }

    final roomName = (tenantData['roomName'] as String? ?? '').trim();
    if (roomName.isNotEmpty && roomName.toLowerCase() != 'na') {
      return roomName;
    }

    final roomNumber = (tenantData['roomNumber'] as String? ?? '').trim();
    if (roomNumber.isNotEmpty && roomNumber.toLowerCase() != 'na') {
      return roomNumber;
    }

    return 'NA';
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

  String _friendlyFirestoreReadError(FirebaseException error) {
    return error.message ?? 'Unable to load reports right now.';
  }

  bool _isMissingIndexError(FirebaseException error) {
    final message = (error.message ?? '').toLowerCase();
    return error.code == 'failed-precondition' &&
        message.contains('requires an index');
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  _queryPaymentsInDateRange({
    required String ownerId,
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('payments')
          .where('ownerId', isEqualTo: ownerId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .get();
      return snapshot.docs;
    } on FirebaseException catch (error) {
      if (!_isMissingIndexError(error)) {
        throw StateError(_friendlyFirestoreReadError(error));
      }

      // Compatibility fallback when composite index is not yet deployed.
      final ownerPayments = await _firestore
          .collection('payments')
          .where('ownerId', isEqualTo: ownerId)
          .limit(2500)
          .get();

      return ownerPayments.docs
          .where((doc) {
            final date =
                _asDate(doc.data()['date']) ?? _asDate(doc.data()['createdAt']);
            if (date == null) return false;
            return !date.isBefore(start) && !date.isAfter(end);
          })
          .toList(growable: false);
    }
  }
}
