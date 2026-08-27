import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' as xl;

import '../../providers/facility_provider.dart';
import '../../utils/web_download.dart';

/// One logical table of data - a title (shown as its own line in CSV,
/// its own sheet/tab name in xlsx), a header row, and the data rows
/// themselves. Both output formats are rendered from this same shared
/// shape, so the actual data-fetching logic below (already carefully
/// verified against each collection's real field names) exists in
/// exactly one place, not duplicated once per format.
class _ExportSection {
  // Short and fixed - Excel sheet names are capped at 31 characters and
  // forbid a handful of symbols, so this can never be a dynamically
  // built string (e.g. one containing a record count that could grow
  // past that limit).
  final String sheetName;
  // The descriptive line shown above the header row in both formats -
  // this is where a record count like "(12 active, 3 archived)" goes,
  // free of Excel's sheet-naming restrictions.
  final String subtitle;
  final List<String> headers;
  final List<List<dynamic>> rows; // String, num, DateTime, or null
  const _ExportSection({
    required this.sheetName,
    required this.subtitle,
    required this.headers,
    required this.rows,
  });
}

class ExportDataScreen extends StatefulWidget {
  const ExportDataScreen({super.key});

  @override
  State<ExportDataScreen> createState() => _ExportDataScreenState();
}

class _ExportDataScreenState extends State<ExportDataScreen> {
  final Color primaryColor = const Color(0xFF2F5D62);
  final Color warmAmber = const Color(0xFFFFB200);
  final Color backgroundColor = const Color(0xFFFDFDF9);

  static const List<Map<String, String>> _dataTypes = [
    {'title': 'Sales & Transactions', 'subtitle': 'Sales (incl. archived) and transaction history'},
    {'title': 'Service Records', 'subtitle': 'Services performed (incl. archived), by client and category'},
    {'title': 'Product Inventory Catalog', 'subtitle': 'Current stock levels, costs, and SKU list'},
    {'title': 'Client Directory & Balances', 'subtitle': 'Client contacts and current outstanding balances'},
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
  // Starts empty rather than defaulting to a silently-picked range -
  // Generate stays disabled until the user explicitly chooses
  // something, even if that choice is All Time. See _hasChosenDateRange
  // below and the Generate button's onPressed logic.
  DateTimeRange? _selectedDateRange;
  bool _hasChosenDateRange = false;

  // xlsx is the default - real business software (QuickBooks, Xero,
  // Stripe) defaults exports to a real spreadsheet format; CSV remains
  // available for anyone who specifically wants plain, universal text.
  String _selectedFormat = 'xlsx';

  bool _isExporting = false;

  String _csvField(dynamic value) {
    if (value is DateTime) return DateFormat('yyyy-MM-dd HH:mm').format(value);
    final text = (value ?? '').toString();
    if (text.contains(',') || text.contains('"') || text.contains('\n')) {
      return '"${text.replaceAll('"', '""')}"';
    }
    return text;
  }

  String _csvRow(List<dynamic> values) => values.map(_csvField).join(',');

  DateTime? _asDate(dynamic value) =>
      value is Timestamp ? value.toDate() : null;

  /// Plain text - each section's title as its own line, then a header
  /// row, then data rows, with a blank line between sections. CSV has
  /// no notion of more than one table, so this is the closest it gets
  /// to the multi-sheet structure xlsx supports natively.
  String _renderCsv(List<_ExportSection> sections, String? dateRangeLabel) {
    final buffer = StringBuffer();
    if (dateRangeLabel != null) {
      buffer.writeln('Export Period: $dateRangeLabel');
      buffer.writeln();
    }
    for (var i = 0; i < sections.length; i++) {
      final section = sections[i];
      buffer.writeln(section.subtitle);
      buffer.writeln(_csvRow(section.headers));
      for (final row in section.rows) {
        buffer.writeln(_csvRow(row));
      }
      if (i < sections.length - 1) buffer.writeln();
    }
    return buffer.toString();
  }

  xl.CellValue _toCellValue(dynamic value) {
    if (value == null) return xl.TextCellValue('');
    if (value is DateTime) {
      return xl.DateTimeCellValue(
          year: value.year, month: value.month, day: value.day, hour: value.hour, minute: value.minute);
    }
    if (value is int) return xl.IntCellValue(value);
    if (value is double) return xl.DoubleCellValue(value);
    if (value is num) return xl.DoubleCellValue(value.toDouble());
    return xl.TextCellValue(value.toString());
  }

  /// A rough estimate of how wide a cell's content would print - used
  /// only to size columns sensibly, not for the actual cell value.
  int _cellDisplayLength(dynamic value) {
    if (value == null) return 0;
    if (value is DateTime) return 16; // "yyyy-MM-dd HH:mm" length
    if (value is num) return NumberFormat('#,##0').format(value).length;
    return value.toString().length;
  }

  /// Sizes each column to fit its longest value (header or data),
  /// clamped to a sane range - wide enough to read without truncation,
  /// capped so one unusually long outlier doesn't blow out the whole
  /// sheet. Excel's default width leaves most text truncated until a
  /// person manually widens every column themselves.
  void _autoSizeColumns(xl.Sheet sheet, _ExportSection section) {
    for (var c = 0; c < section.headers.length; c++) {
      var maxLen = section.headers[c].length;
      for (final row in section.rows) {
        if (c < row.length) {
          final len = _cellDisplayLength(row[c]);
          if (len > maxLen) maxLen = len;
        }
      }
      final width = (maxLen + 2).clamp(10, 40).toDouble();
      sheet.setColumnWidth(c, width);
    }
  }

  /// A real workbook - one sheet per section (so "Sales" and
  /// "Transactions" become two clean tabs instead of one file awkwardly
  /// stacking two tables with blank lines), bolded header row, and a
  /// merged title row up top stating the selected date range - all
  /// things CSV has no way to represent at all.
  Uint8List _renderXlsx(List<_ExportSection> sections, String? dateRangeLabel) {
    final workbook = xl.Excel.createExcel();
    final defaultSheetName = workbook.getDefaultSheet();

    final headerStyle = xl.CellStyle(bold: true, horizontalAlign: xl.HorizontalAlign.Center);
    final titleStyle = xl.CellStyle(bold: true, horizontalAlign: xl.HorizontalAlign.Center);
    // Matches this app's own money-formatting convention (thousand
    // separators, whole numbers) rather than leaving amounts as plain,
    // unformatted digits once opened in Excel.
    // A named constant rather than a custom-format constructor call -
    // NumFormat.standard_3 is Excel's built-in format ID 3, which the
    // OOXML spec defines as "#,##0" (thousand separators, no decimals),
    // matching this app's own money-formatting convention.
    final numberStyle = xl.CellStyle(numberFormat: xl.NumFormat.standard_3);

    for (final section in sections) {
      // The very first section reuses the workbook's own default sheet
      // (renamed to match) rather than leaving an unwanted empty
      // "Sheet1" tab alongside it.
      if (section == sections.first && defaultSheetName != null) {
        workbook.rename(defaultSheetName, section.sheetName);
      }
      final sheet = workbook[section.sheetName];
      _autoSizeColumns(sheet, section);

      // Every title row spans the full width of the table it sits
      // above, not just column A - a real column count of at least 1
      // even for a table with a single column, so merge is always
      // well-defined.
      final lastColumn = (section.headers.length - 1).clamp(0, section.headers.length);

      var rowIndex = 0;
      if (dateRangeLabel != null) {
        final start = xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex);
        final end = xl.CellIndex.indexByColumnRow(columnIndex: lastColumn, rowIndex: rowIndex);
        sheet.cell(start).value = xl.TextCellValue('Export Period: $dateRangeLabel');
        sheet.cell(start).cellStyle = titleStyle;
        sheet.merge(start, end);
        rowIndex++;
        rowIndex++; // blank spacer row
      }

      final subtitleStart = xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex);
      final subtitleEnd = xl.CellIndex.indexByColumnRow(columnIndex: lastColumn, rowIndex: rowIndex);
      sheet.cell(subtitleStart).value = xl.TextCellValue(section.subtitle);
      sheet.cell(subtitleStart).cellStyle = titleStyle;
      sheet.merge(subtitleStart, subtitleEnd);
      rowIndex++;

      for (var c = 0; c < section.headers.length; c++) {
        final cell = sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: rowIndex));
        cell.value = xl.TextCellValue(section.headers[c]);
        cell.cellStyle = headerStyle;
      }
      rowIndex++;

      for (final row in section.rows) {
        for (var c = 0; c < row.length; c++) {
          final cell = sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: rowIndex));
          cell.value = _toCellValue(row[c]);
          if (row[c] is num) {
            cell.cellStyle = numberStyle;
          }
        }
        rowIndex++;
      }
    }

    final bytes = workbook.encode();
    if (bytes == null) throw Exception('Could not generate the spreadsheet.');
    return Uint8List.fromList(bytes);
  }

  Future<void> _triggerExportPipeline() async {
    setState(() => _isExporting = true);
    Uint8List? bytes;
    String? fileName;

    try {
      final facilityId =
          Provider.of<FacilityProvider>(context, listen: false).selectedFacilityId;

      if (facilityId == null || facilityId.isEmpty) {
        throw Exception('No facility selected.');
      }

      final List<_ExportSection> sections;
      switch (_selectedDataType) {
        case 'Service Records':
          sections = await _buildServicesData(facilityId);
          break;
        case 'Product Inventory Catalog':
          sections = await _buildProductsData(facilityId);
          break;
        case 'Client Directory & Balances':
          sections = await _buildClientsData(facilityId);
          break;
        case 'Debtors / Outstanding Balances':
          sections = await _buildDebtorsData(facilityId);
          break;
        case 'Payments Ledger':
          sections = await _buildPaymentsData(facilityId);
          break;
        case 'Activity Log':
          sections = await _buildActivityLogData(facilityId);
          break;
        default:
          sections = await _buildSalesAndTransactionsData(facilityId);
      }

      final totalRows = sections.fold<int>(0, (sum, s) => sum + s.rows.length);
      if (totalRows == 0) {
        throw Exception('No records found for this selection. Try a different date range or category.');
      }

      final isSnapshot = _snapshotTypes.contains(_selectedDataType);
      final dateRangeLabel = isSnapshot
          ? null
          : _selectedDateRange == null
              ? 'All Records'
              : '${DateFormat('yyyy-MM-dd').format(_selectedDateRange!.start)} to '
                  '${DateFormat('yyyy-MM-dd').format(_selectedDateRange!.end)}';

      final baseName = _selectedDataType.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
      final timestamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());

      if (_selectedFormat == 'xlsx') {
        bytes = _renderXlsx(sections, dateRangeLabel);
        fileName = '${baseName}_$timestamp.xlsx';
      } else {
        bytes = Uint8List.fromList(utf8.encode(_renderCsv(sections, dateRangeLabel)));
        fileName = '${baseName}_$timestamp.csv';
      }

      if (!mounted) return;

      final mimeType = _selectedFormat == 'xlsx'
          ? 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
          : 'text/csv';

      // The Web Share API is a mobile pattern - genuinely useful there,
      // but well known to be unreliable for files on desktop browsers
      // even though the API exists. Deciding this upfront, rather than
      // trying it first and falling back on failure, avoids making the
      // user wait out a doomed attempt before the fast download path
      // ever runs.
      final isDesktopWeb = kIsWeb && MediaQuery.of(context).size.width >= 900;

      if (isDesktopWeb) {
        downloadFileWeb(bytes, fileName, mimeType: mimeType);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exported $_selectedDataType'), backgroundColor: Colors.green),
        );
        return;
      }

      final xfile = XFile.fromData(bytes, name: fileName, mimeType: mimeType);

      await Share.shareXFiles([xfile], text: 'VetBiz Pro export: $_selectedDataType');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Exported $_selectedDataType'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      // Confirmed on the receipt screens: desktop browsers' well-known
      // unreliable support for file-sharing through the Web Share API
      // - not worth showing as a scary error when there's a reliable
      // fallback that still gets the file onto the user's device.
      if (kIsWeb && bytes != null && fileName != null) {
        final mimeType = _selectedFormat == 'xlsx'
            ? 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
            : 'text/csv';
        downloadFileWeb(bytes, fileName, mimeType: mimeType);
        return;
      }
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
  /// section - two separate sheets/tabs in xlsx, two stacked tables in CSV.
  Future<List<_ExportSection>> _buildSalesAndTransactionsData(String facilityId) async {
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

    final saleRows = allSales.map((data) {
      final totalAmount = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
      final totalPaid = (data['totalPaid'] as num?)?.toDouble() ?? 0.0;
      final status = totalPaid >= totalAmount ? 'Paid' : (totalPaid > 0 ? 'Partial' : 'Unpaid');
      return [
        _asDate(data['timestamp']),
        data['clientName'] ?? 'Walk-in',
        totalAmount,
        totalPaid,
        status,
        data['totalProfit'] ?? 0,
      ];
    }).toList();

    final transactions =
        await _fetchWithRange(facilityId: facilityId, collection: 'transactions', dateField: 'date');
    transactions.sort((a, b) {
      final da = _asDate(a['date']) ?? DateTime(0);
      final db = _asDate(b['date']) ?? DateTime(0);
      return db.compareTo(da);
    });

    final transactionRows = transactions.map((data) {
      return [
        _asDate(data['date']),
        data['type'] ?? '',
        data['category'] ?? '',
        data['description'] ?? '',
        data['amount'] ?? 0,
        data['recordedBy'] ?? '',
      ];
    }).toList();

    return [
      _ExportSection(
        sheetName: 'Sales',
        subtitle: 'Sales (${liveSales.length} active, ${archivedSales.length} archived)',
        headers: ['Date', 'Client', 'Total Amount', 'Total Paid', 'Status', 'Profit'],
        rows: saleRows,
      ),
      _ExportSection(
        sheetName: 'Transactions',
        subtitle: 'Transactions',
        headers: ['Date', 'Type', 'Category', 'Description', 'Amount', 'Recorded By'],
        rows: transactionRows,
      ),
    ];
  }

  /// Services (live + archived, merged and sorted by serviceDate).
  Future<List<_ExportSection>> _buildServicesData(String facilityId) async {
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

    final rows = allServices.map((data) {
      final totalAmount = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
      final totalPaid = (data['totalPaid'] as num?)?.toDouble() ?? 0.0;
      final status = totalPaid >= totalAmount ? 'Paid' : (totalPaid > 0 ? 'Partial' : 'Unpaid');
      return [
        _asDate(data['serviceDate']),
        data['clientName'] ?? 'N/A',
        data['name'] ?? '',
        (data['category'] as String?)?.isNotEmpty == true ? data['category'] : 'Other',
        data['providedByName'] ?? 'N/A',
        totalAmount,
        totalPaid,
        status,
      ];
    }).toList();

    return [
      _ExportSection(
        sheetName: 'Service Records',
        subtitle: 'Services (${liveServices.length} active, ${archivedServices.length} archived)',
        headers: ['Date', 'Client', 'Service', 'Category', 'Provided By', 'Total Amount', 'Total Paid', 'Status'],
        rows: rows,
      ),
    ];
  }

  /// Inventory is a current snapshot - no date range applies.
  /// One row per batch (its own batch number, quantities, buy price, and
  /// expiry) - a product with three batches produces three rows, not one
  /// blended row. Products with no batch records yet (created before
  /// batch tracking existed) fall back to a single row using their own
  /// aggregate fields, same as before this existed.
  Future<List<_ExportSection>> _buildProductsData(String facilityId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('facilities')
        .doc(facilityId)
        .collection('products')
        .orderBy('name')
        .get();

    // Every product's batches fetched concurrently, not one query per
    // product waited on before starting the next - for a catalog of
    // any real size this is the difference between a quick export and
    // a genuinely slow one.
    final batchSnapshots = await Future.wait(
      snapshot.docs.map((doc) => doc.reference.collection('batches').get()),
    );

    final rows = <List<dynamic>>[];

    for (var i = 0; i < snapshot.docs.length; i++) {
      final doc = snapshot.docs[i];
      final data = doc.data();
      final name = data['name'] ?? '';
      final category = data['category'] ?? '';
      final type = data['type'] ?? '';
      final sellPrice = data['sellPrice'] ?? 0;

      final batchesSnap = batchSnapshots[i];

      if (batchesSnap.docs.isEmpty) {
        rows.add([
          name, category, type,
          data['batchNo'] ?? '',
          data['stockQty'] ?? 0,
          data['sellableQty'] ?? 0,
          data['buyPrice'] ?? 0,
          sellPrice,
          _asDate(data['expiry']),
        ]);
        continue;
      }

      for (final batchDoc in batchesSnap.docs) {
        final batchData = batchDoc.data();
        rows.add([
          name, category, type,
          batchData['batchNo'] ?? '',
          batchData['stockQty'] ?? 0,
          batchData['sellableQty'] ?? 0,
          batchData['buyPrice'] ?? 0,
          sellPrice,
          _asDate(batchData['expiry']),
        ]);
      }
    }

    return [
      _ExportSection(
        sheetName: 'Products',
        subtitle: 'Products (${rows.length} rows, one per batch)',
        headers: ['Name', 'Category', 'Type', 'Batch No', 'Stock Qty', 'Sellable Qty', 'Buy Price', 'Sell Price', 'Expiry'],
        rows: rows,
      ),
    ];
  }

  Future<List<_ExportSection>> _buildClientsData(String facilityId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('facilities')
        .doc(facilityId)
        .collection('clients')
        .orderBy('name')
        .get();

    final rows = snapshot.docs.map((doc) {
      final data = doc.data();
      return [
        data['name'] ?? '',
        data['type'] ?? '',
        data['phone'] ?? '',
        data['address'] ?? '',
        data['balance'] ?? 0,
      ];
    }).toList();

    return [
      _ExportSection(
        sheetName: 'Clients',
        subtitle: 'Clients (${rows.length})',
        headers: ['Name', 'Type', 'Phone', 'Address', 'Balance'],
        rows: rows,
      ),
    ];
  }

  /// Every currently outstanding debt, itemized - a snapshot of "who owes
  /// what right now", not filtered by date.
  Future<List<_ExportSection>> _buildDebtorsData(String facilityId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('facilities')
        .doc(facilityId)
        .collection('debts')
        .orderBy('timestamp', descending: true)
        .get();

    final rows = snapshot.docs.map((doc) {
      final data = doc.data();
      return [
        data['clientName'] ?? 'Unknown',
        data['clientPhone'] ?? '',
        data['source'] ?? '',
        data['amountOwed'] ?? 0,
        _asDate(data['timestamp']),
        _asDate(data['updatedAt']),
      ];
    }).toList();

    return [
      _ExportSection(
        sheetName: 'Debtors',
        subtitle: 'Debtors (${rows.length} outstanding)',
        headers: ['Client', 'Phone', 'Source', 'Amount Owed', 'Date Incurred', 'Last Updated'],
        rows: rows,
      ),
    ];
  }

  /// Every payment collected - sale payments, service payments, debt
  /// repayments, plus Other Income transactions, merged - same sources as
  /// the in-app Payments screen.
  Future<List<_ExportSection>> _buildPaymentsData(String facilityId) async {
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

    return [
      _ExportSection(
        sheetName: 'Payments',
        subtitle: 'Payments (${rows.length})',
        headers: ['Date', 'Type', 'Client / Description', 'Amount'],
        rows: rows.map((r) => [r['date'], r['type'], r['client'], r['amount']]).toList(),
      ),
    ];
  }

  Future<List<_ExportSection>> _buildActivityLogData(String facilityId) async {
    final logs = await _fetchWithRange(
        facilityId: facilityId, collection: 'activity_logs', dateField: 'timestamp');
    logs.sort((a, b) {
      final da = _asDate(a['timestamp']) ?? DateTime(0);
      final db = _asDate(b['timestamp']) ?? DateTime(0);
      return db.compareTo(da);
    });

    final rows = logs.map((data) {
      return [
        _asDate(data['timestamp']),
        data['userName'] ?? '',
        data['actionType'] ?? '',
        data['description'] ?? '',
      ];
    }).toList();

    return [
      _ExportSection(
        sheetName: 'Activity Log',
        subtitle: 'Activity Log (${rows.length} entries)',
        headers: ['Date', 'User', 'Action Type', 'Description'],
        rows: rows,
      ),
    ];
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    Future<void> apply(DateTimeRange? range) async {
      Navigator.pop(context);
      setState(() {
        _selectedDateRange = range;
        _hasChosenDateRange = true;
      });
    }

    Future<void> pickCustomRange() async {
      Navigator.pop(context);

      final DateTime? start = await showDatePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: now,
        initialDate: now,
        helpText: 'Select Start Date',
      );
      if (start == null || !mounted) return;

      final DateTime? end = await showDatePicker(
        context: context,
        firstDate: start,
        lastDate: now,
        initialDate: now.isBefore(start) ? start : now,
        helpText: 'Select End Date',
      );
      if (end == null || !mounted) return;

      setState(() {
        _selectedDateRange = DateTimeRange(start: start, end: end);
        _hasChosenDateRange = true;
      });
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        Widget presetTile(String label, DateTimeRange? Function() rangeBuilder, {IconData? icon}) {
          return ListTile(
            leading: icon != null ? Icon(icon, color: primaryColor, size: 20) : null,
            title: Text(label),
            hoverColor: warmAmber.withValues(alpha: 0.12),
            onTap: () => apply(rangeBuilder()),
          );
        }

        return AlertDialog(
          title: const Text('Date Range'),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                presetTile('Last 7 Days', () => DateTimeRange(
                    start: today.subtract(const Duration(days: 6)), end: today)),
                presetTile('Last 30 Days', () => DateTimeRange(
                    start: today.subtract(const Duration(days: 29)), end: today)),
                presetTile('This Month', () => DateTimeRange(
                    start: DateTime(today.year, today.month, 1), end: today)),
                presetTile('Last Month', () {
                  final lastMonth = DateTime(today.year, today.month - 1, 1);
                  final lastDayOfLastMonth = DateTime(today.year, today.month, 0);
                  return DateTimeRange(start: lastMonth, end: lastDayOfLastMonth);
                }),
                presetTile('This Year', () => DateTimeRange(
                    start: DateTime(today.year, 1, 1), end: today)),
                presetTile('All Time', () => null),
                const Divider(height: 16),
                ListTile(
                  leading: Icon(Icons.edit_calendar_outlined, color: primaryColor, size: 20),
                  title: const Text('Custom Range...'),
                  hoverColor: warmAmber.withValues(alpha: 0.12),
                  onTap: pickCustomRange,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: primaryColor)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const double cardElevation = 2.0;
    final isSnapshot = _snapshotTypes.contains(_selectedDataType);

    String dateRangeText = isSnapshot
        ? 'Not applicable - this is a current snapshot'
        : !_hasChosenDateRange
            ? 'Please select a date range below'
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
                      style: ButtonStyle(
                        foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                          if (states.contains(WidgetState.hovered)) return warmAmber;
                          return primaryColor;
                        }),
                      ),
                      child: const Text('Modify', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
            ),
          ),
          const SizedBox(height: 20),

          _buildSectionTitle('3. Output Document Layout'),
          const SizedBox(height: 6),
          Card(
            elevation: cardElevation,
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                _buildFormatTile(
                  value: 'xlsx',
                  title: 'Excel Workbook (.xlsx)',
                  subtitle: 'Bolded headers, multiple sheets, real dates - opens clean, ready to keep',
                ),
                Divider(height: 1, color: Colors.grey.shade200, indent: 56),
                _buildFormatTile(
                  value: 'csv',
                  title: 'CSV (Plain Text)',
                  subtitle: 'Universal, simple text - opens in Excel, Sheets, or any editor',
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          if (!isSnapshot && !_hasChosenDateRange) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8, left: 4),
              child: Text(
                'Select a date range above before exporting.',
                style: TextStyle(fontSize: 12.5, color: Colors.grey[700]),
              ),
            ),
          ],
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _isExporting
                  ? null
                  : () {
                      if (!isSnapshot && !_hasChosenDateRange) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please select a date range before exporting.'),
                          ),
                        );
                        return;
                      }
                      _triggerExportPipeline();
                    },
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                  if (states.contains(WidgetState.hovered)) return warmAmber;
                  return primaryColor;
                }),
                foregroundColor: WidgetStateProperty.all(Colors.white),
                shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                elevation: WidgetStateProperty.all(1),
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

  Widget _buildFormatTile({required String value, required String title, required String subtitle}) {
    return RadioListTile<String>(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 13)),
      value: value,
      groupValue: _selectedFormat,
      activeColor: primaryColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      onChanged: (val) {
        if (val != null) setState(() => _selectedFormat = val);
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
