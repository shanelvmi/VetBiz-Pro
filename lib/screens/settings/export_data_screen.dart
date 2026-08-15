import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

import '../../providers/facility_provider.dart';

class ExportDataScreen extends StatefulWidget {
  const ExportDataScreen({super.key});

  @override
  State<ExportDataScreen> createState() => _ExportDataScreenState();
}

class _ExportDataScreenState extends State<ExportDataScreen> {
  final Color primaryColor = const Color(0xFF2F5D62);
  final Color backgroundColor = const Color(0xFFFDFDF9);

  static const List<Map<String, String>> _dataTypes = [
    {'title': 'Sales & Transactions', 'subtitle': 'Sales (incl. archived) and transaction history'},
    {'title': 'Services', 'subtitle': 'Services performed (incl. archived), by client and category'},
    {'title': 'Product Inventory Catalog', 'subtitle': 'Current stock levels, costs, and SKU list'},
    {'title': 'Client Ledger & Directory', 'subtitle': 'Client contacts and outstanding balances'},
    {'title': 'Debtors / Outstanding Balances', 'subtitle': 'Itemized list of everything currently owed'},
    {'title': 'Payments Ledger', 'subtitle': 'Every payment collected - sales, services, debts, other income'},
    {'title': 'Activity Log', 'subtitle': 'Who did what, and when'},
  ];

  // These two are point-in-time snapshots, not something with a
  // meaningful "date it happened" - the date range filter doesn't apply.
  static const Set<String> _snapshotTypes = {
    'Product Inventory Catalog',
    'Debtors / Outstanding Balances',
  };

  String _selectedDataType = 'Sales & Transactions';
  DateTimeRange? _selectedDateRange;

  bool _isExporting = false;

  String _csvField(dynamic value) {
    final text = (value ?? '').toString();
    if (text.contains(',') || text.contains('"') || text.contains('\n')) {
      return '"${text.replaceAll('"', '""')}"';
    }
    return text;
  }

  String _csvRow(List<dynamic> values) => values.map(_csvField).join(',');

  DateTime? _asDate(dynamic value) =>
      value is Timestamp ? value.toDate() : null;

  Future<void> _triggerExportPipeline() async {
    setState(() => _isExporting = true);

    try {
      final facilityId =
          Provider.of<FacilityProvider>(context, listen: false).selectedFacilityId;

      if (facilityId == null || facilityId.isEmpty) {
        throw Exception('No facility selected.');
      }

      final String csv;
      switch (_selectedDataType) {
        case 'Services':
          csv = await _buildServicesCsv(facilityId);
          break;
        case 'Product Inventory Catalog':
          csv = await _buildProductsCsv(facilityId);
          break;
        case 'Client Ledger & Directory':
          csv = await _buildClientsCsv(facilityId);
          break;
        case 'Debtors / Outstanding Balances':
          csv = await _buildDebtorsCsv(facilityId);
          break;
        case 'Payments Ledger':
          csv = await _buildPaymentsCsv(facilityId);
          break;
        case 'Activity Log':
          csv = await _buildActivityLogCsv(facilityId);
          break;
        default:
          csv = await _buildSalesAndTransactionsCsv(facilityId);
      }

      final fileName =
          '${_selectedDataType.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')}_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv';

      // Share directly from in-memory bytes - never touches a
      // filesystem, so this works identically on web and mobile.
      final bytes = Uint8List.fromList(utf8.encode(csv));
      final xfile = XFile.fromData(bytes, name: fileName, mimeType: 'text/csv');

      if (!mounted) return;

      await Share.shareXFiles([xfile], text: 'VetBiz Pro export: $_selectedDataType');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Exported $_selectedDataType'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  /// Fetch a collection with an optional date-range filter on [dateField],
  /// used for both a live collection and its archive counterpart -
  /// callers merge the two so archived records are never silently missing
  /// from an export.
  Future<List<Map<String, dynamic>>> _fetchWithRange({
    required String facilityId,
    required String collection,
    required String dateField,
  }) async {
    Query query = FirebaseFirestore.instance
        .collection('facilities')
        .doc(facilityId)
        .collection(collection);

    if (_selectedDateRange != null) {
      query = query
          .where(dateField,
              isGreaterThanOrEqualTo: Timestamp.fromDate(_selectedDateRange!.start))
          .where(dateField,
              isLessThanOrEqualTo: Timestamp.fromDate(
                  _selectedDateRange!.end.add(const Duration(days: 1))));
    }

    final snapshot = await query.get();
    return snapshot.docs.map((doc) {
      final data = Map<String, dynamic>.from(doc.data() as Map);
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  /// Sales (live + archived, merged and sorted) followed by a Transactions
  /// section.
  Future<String> _buildSalesAndTransactionsCsv(String facilityId) async {
    final buffer = StringBuffer();

    final liveSales =
        await _fetchWithRange(facilityId: facilityId, collection: 'sales', dateField: 'timestamp');
    final archivedSales = await _fetchWithRange(
        facilityId: facilityId, collection: 'archived_sales', dateField: 'timestamp');

    final allSales = [...liveSales, ...archivedSales];
    allSales.sort((a, b) {
      final da = _asDate(a['timestamp']) ?? DateTime(0);
      final db = _asDate(b['timestamp']) ?? DateTime(0);
      return db.compareTo(da);
    });

    buffer.writeln('SALES (${liveSales.length} active, ${archivedSales.length} archived)');
    buffer.writeln(_csvRow(['Date', 'Client', 'Total Amount', 'Total Paid', 'Status', 'Profit']));

    for (final data in allSales) {
      final totalAmount = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
      final totalPaid = (data['totalPaid'] as num?)?.toDouble() ?? 0.0;
      final timestamp = _asDate(data['timestamp']);
      final status = totalPaid >= totalAmount ? 'Paid' : (totalPaid > 0 ? 'Partial' : 'Unpaid');

      buffer.writeln(_csvRow([
        timestamp != null ? DateFormat('yyyy-MM-dd HH:mm').format(timestamp) : '',
        data['clientName'] ?? 'Walk-in',
        totalAmount,
        totalPaid,
        status,
        data['totalProfit'] ?? 0,
      ]));
    }

    buffer.writeln();
    buffer.writeln('TRANSACTIONS');
    buffer.writeln(_csvRow(['Date', 'Type', 'Category', 'Description', 'Amount', 'Recorded By']));

    final transactions =
        await _fetchWithRange(facilityId: facilityId, collection: 'transactions', dateField: 'date');
    transactions.sort((a, b) {
      final da = _asDate(a['date']) ?? DateTime(0);
      final db = _asDate(b['date']) ?? DateTime(0);
      return db.compareTo(da);
    });

    for (final data in transactions) {
      final date = _asDate(data['date']);
      buffer.writeln(_csvRow([
        date != null ? DateFormat('yyyy-MM-dd HH:mm').format(date) : '',
        data['type'] ?? '',
        data['category'] ?? '',
        data['description'] ?? '',
        data['amount'] ?? 0,
        data['recordedBy'] ?? '',
      ]));
    }

    return buffer.toString();
  }

  /// Services (live + archived, merged and sorted by serviceDate).
  Future<String> _buildServicesCsv(String facilityId) async {
    final buffer = StringBuffer();

    final liveServices = await _fetchWithRange(
        facilityId: facilityId, collection: 'services', dateField: 'serviceDate');
    final archivedServices = await _fetchWithRange(
        facilityId: facilityId, collection: 'archived_services', dateField: 'serviceDate');

    final allServices = [...liveServices, ...archivedServices];
    allServices.sort((a, b) {
      final da = _asDate(a['serviceDate']) ?? DateTime(0);
      final db = _asDate(b['serviceDate']) ?? DateTime(0);
      return db.compareTo(da);
    });

    buffer.writeln(
        'SERVICES (${liveServices.length} active, ${archivedServices.length} archived)');
    buffer.writeln(_csvRow([
      'Date', 'Client', 'Service', 'Category', 'Provided By',
      'Total Amount', 'Total Paid', 'Status',
    ]));

    for (final data in allServices) {
      final totalAmount = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
      final totalPaid = (data['totalPaid'] as num?)?.toDouble() ?? 0.0;
      final date = _asDate(data['serviceDate']);
      final status = totalPaid >= totalAmount ? 'Paid' : (totalPaid > 0 ? 'Partial' : 'Unpaid');

      buffer.writeln(_csvRow([
        date != null ? DateFormat('yyyy-MM-dd').format(date) : '',
        data['clientName'] ?? 'N/A',
        data['name'] ?? '',
        (data['category'] as String?)?.isNotEmpty == true ? data['category'] : 'Other',
        data['providedByName'] ?? 'N/A',
        totalAmount,
        totalPaid,
        status,
      ]));
    }

    return buffer.toString();
  }

  /// Inventory is a current snapshot - no date range applies.
  /// One row per batch (its own batch number, quantities, buy price, and
  /// expiry) - a product with three batches produces three rows, not one
  /// blended row. Products with no batch records yet (created before
  /// batch tracking existed) fall back to a single row using their own
  /// aggregate fields, same as before this existed.
  Future<String> _buildProductsCsv(String facilityId) async {
    final buffer = StringBuffer();
    final snapshot = await FirebaseFirestore.instance
        .collection('facilities')
        .doc(facilityId)
        .collection('products')
        .orderBy('name')
        .get();

    buffer.writeln(_csvRow([
      'Name', 'Category', 'Type', 'Batch No', 'Stock Qty', 'Sellable Qty',
      'Buy Price', 'Sell Price', 'Expiry',
    ]));

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final name = data['name'] ?? '';
      final category = data['category'] ?? '';
      final type = data['type'] ?? '';
      final sellPrice = data['sellPrice'] ?? 0;

      final batchesSnap = await doc.reference.collection('batches').get();

      if (batchesSnap.docs.isEmpty) {
        final expiry = _asDate(data['expiry']);
        buffer.writeln(_csvRow([
          name, category, type,
          data['batchNo'] ?? '',
          data['stockQty'] ?? 0,
          data['sellableQty'] ?? 0,
          data['buyPrice'] ?? 0,
          sellPrice,
          expiry != null ? DateFormat('yyyy-MM-dd').format(expiry) : '',
        ]));
        continue;
      }

      for (final batchDoc in batchesSnap.docs) {
        final batchData = batchDoc.data();
        final expiry = _asDate(batchData['expiry']);
        buffer.writeln(_csvRow([
          name, category, type,
          batchData['batchNo'] ?? '',
          batchData['stockQty'] ?? 0,
          batchData['sellableQty'] ?? 0,
          batchData['buyPrice'] ?? 0,
          sellPrice,
          expiry != null ? DateFormat('yyyy-MM-dd').format(expiry) : '',
        ]));
      }
    }

    return buffer.toString();
  }

  Future<String> _buildClientsCsv(String facilityId) async {
    final buffer = StringBuffer();
    final snapshot = await FirebaseFirestore.instance
        .collection('facilities')
        .doc(facilityId)
        .collection('clients')
        .orderBy('name')
        .get();

    buffer.writeln(_csvRow(['Name', 'Type', 'Phone', 'Address', 'Balance']));

    for (final doc in snapshot.docs) {
      final data = doc.data();
      buffer.writeln(_csvRow([
        data['name'] ?? '',
        data['type'] ?? '',
        data['phone'] ?? '',
        data['address'] ?? '',
        data['balance'] ?? 0,
      ]));
    }

    return buffer.toString();
  }

  /// Every currently outstanding debt, itemized - a snapshot of "who owes
  /// what right now", not filtered by date.
  Future<String> _buildDebtorsCsv(String facilityId) async {
    final buffer = StringBuffer();
    final snapshot = await FirebaseFirestore.instance
        .collection('facilities')
        .doc(facilityId)
        .collection('debts')
        .orderBy('timestamp', descending: true)
        .get();

    buffer.writeln(_csvRow(
        ['Client', 'Phone', 'Source', 'Amount Owed', 'Date Incurred', 'Last Updated']));

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final incurred = _asDate(data['timestamp']);
      final updated = _asDate(data['updatedAt']);

      buffer.writeln(_csvRow([
        data['clientName'] ?? 'Unknown',
        data['clientPhone'] ?? '',
        data['source'] ?? '',
        data['amountOwed'] ?? 0,
        incurred != null ? DateFormat('yyyy-MM-dd').format(incurred) : '',
        updated != null ? DateFormat('yyyy-MM-dd').format(updated) : '',
      ]));
    }

    return buffer.toString();
  }

  /// Every payment collected - sale payments, service payments, debt
  /// repayments, plus Other Income transactions, merged - same sources as
  /// the in-app Payments screen.
  Future<String> _buildPaymentsCsv(String facilityId) async {
    final buffer = StringBuffer();

    final payments = await _fetchWithRange(
        facilityId: facilityId, collection: 'payments', dateField: 'timestamp');

    final labelFor = {
      'sale': 'Sale payment',
      'service': 'Service payment',
      'debt_repayment': 'Debt repayment',
    };

    final rows = payments
        .map((data) => {
              'date': _asDate(data['timestamp']),
              'type': labelFor[data['source']] ?? 'Payment',
              'client': data['clientName'] ?? '',
              'amount': data['amount'] ?? 0,
            })
        .toList();

    final transactions =
        await _fetchWithRange(facilityId: facilityId, collection: 'transactions', dateField: 'date');
    for (final data in transactions) {
      final type = ((data['type'] as String?) ?? '').toLowerCase();
      if (type != 'other income') continue;
      rows.add({
        'date': _asDate(data['date']),
        'type': 'Other income',
        'client': data['description'] ?? '',
        'amount': data['amount'] ?? 0,
      });
    }

    rows.sort((a, b) {
      final da = a['date'] as DateTime? ?? DateTime(0);
      final db = b['date'] as DateTime? ?? DateTime(0);
      return db.compareTo(da);
    });

    buffer.writeln(_csvRow(['Date', 'Type', 'Client / Description', 'Amount']));
    for (final row in rows) {
      final date = row['date'] as DateTime?;
      buffer.writeln(_csvRow([
        date != null ? DateFormat('yyyy-MM-dd HH:mm').format(date) : '',
        row['type'],
        row['client'],
        row['amount'],
      ]));
    }

    return buffer.toString();
  }

  Future<String> _buildActivityLogCsv(String facilityId) async {
    final buffer = StringBuffer();
    final logs = await _fetchWithRange(
        facilityId: facilityId, collection: 'activity_logs', dateField: 'timestamp');
    logs.sort((a, b) {
      final da = _asDate(a['timestamp']) ?? DateTime(0);
      final db = _asDate(b['timestamp']) ?? DateTime(0);
      return db.compareTo(da);
    });

    buffer.writeln(_csvRow(['Date', 'User', 'Action Type', 'Description']));

    for (final data in logs) {
      final date = _asDate(data['timestamp']);
      buffer.writeln(_csvRow([
        date != null ? DateFormat('yyyy-MM-dd HH:mm').format(date) : '',
        data['userName'] ?? '',
        data['actionType'] ?? '',
        data['description'] ?? '',
      ]));
    }

    return buffer.toString();
  }

  Future<void> _pickDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      currentDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDateRange = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    const double cardElevation = 2.0;
    final isSnapshot = _snapshotTypes.contains(_selectedDataType);

    String dateRangeText = isSnapshot
        ? 'Not applicable - this is a current snapshot'
        : _selectedDateRange == null
            ? 'All Records (No Filters Applied)'
            : '${DateFormat('yyyy-MM-dd').format(_selectedDateRange!.start)}  to  ${DateFormat('yyyy-MM-dd').format(_selectedDateRange!.end)}';

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Export Center', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20)),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionTitle('1. Select Dataset Category'),
          const SizedBox(height: 6),
          Card(
            elevation: cardElevation,
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                for (int i = 0; i < _dataTypes.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: Colors.grey.shade200, indent: 56),
                  _buildRadioTile(_dataTypes[i]['title']!, _dataTypes[i]['subtitle']!),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          _buildSectionTitle('2. Scope & Date Range Filtering'),
          const SizedBox(height: 6),
          Card(
            elevation: cardElevation,
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: Icon(Icons.calendar_today_outlined, color: primaryColor),
              title: const Text('Date Selection Scope', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
              subtitle: Text(dateRangeText),
              trailing: isSnapshot
                  ? null
                  : TextButton(
                      onPressed: _pickDateRange,
                      child: Text('Modify', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
                    ),
            ),
          ),
          const SizedBox(height: 20),

          _buildSectionTitle('3. Output Document Layout'),
          const SizedBox(height: 6),
          Card(
            elevation: cardElevation,
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: Icon(Icons.table_chart_outlined, color: primaryColor),
              title: const Text('CSV (Spreadsheet)', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
              subtitle: const Text('Opens in Excel, Google Sheets, or similar'),
              trailing: Icon(Icons.check_circle, color: primaryColor),
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              'PDF export isn\'t built yet - CSV is the only real, working format for now.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ),
          const SizedBox(height: 32),

          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _isExporting ? null : _triggerExportPipeline,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 1,
              ),
              child: _isExporting
                  ? const SizedBox(
                      width: 24, height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Text('Generate & Export Data',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
            ),
          ),
        ],
          ),
        ),
      ),
    );
  }

  Widget _buildRadioTile(String title, String subtitle) {
    return RadioListTile<String>(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 13)),
      value: title,
      groupValue: _selectedDataType,
      activeColor: primaryColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      onChanged: (value) {
        if (value != null) setState(() => _selectedDataType = value);
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 11,
          color: primaryColor.withValues(alpha: 0.75),
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}
