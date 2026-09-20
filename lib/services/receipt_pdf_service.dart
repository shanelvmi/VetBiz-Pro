import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/sale.dart';
import '../models/service.dart';

/// Builds a genuine A4 PDF receipt for a Sale or a Service - a real,
/// correctly-sized printable document, not a screenshot of the on-screen
/// thermal-style preview stretched wider. Matches the same style/helper
/// conventions already established in DailyReportPdfService, so both PDF
/// features in this app look and feel consistent with each other.
///
/// Deliberately text-only in the header (no logo) - same precedent as
/// DailyReportPdfService, which doesn't fetch a logo image either.
/// Fetching a network image reliably into a PDF (across web and mobile)
/// is a separate piece of complexity this doesn't take on.
class ReceiptPdfService {
  static final _money = NumberFormat.decimalPattern();
  static final _fullDate = DateFormat('EEEE, d MMMM yyyy');
  static final _dateTime = DateFormat('d MMM yyyy, h:mm a');

  static final _deepGreen = PdfColor.fromInt(0xFF2F5D62);
  static final _amber = PdfColor.fromInt(0xFFE0A32E);
  static final _red = PdfColor.fromInt(0xFFC62828);
  static final _green = PdfColor.fromInt(0xFF2E7D32);
  static final _grey = PdfColor.fromInt(0xFF616161);
  static final _lightGrey = PdfColor.fromInt(0xFFE0E0E0);
  static final _redPillBg = PdfColor.fromInt(0x1FC62828);
  static final _greenPillBg = PdfColor.fromInt(0x1F2E7D32);

  /// Opens the OS's native print/share preview for a Sale receipt.
  static Future<void> printOrDownloadSale(
    Sale sale, {
    required String facilityName,
    String? facilityType,
    String? facilityPhone,
    String? facilityEmail,
    String? facilityAddress,
    String? facilityTagline,
    String? facilityTin,
  }) async {
    final doc = await _buildSaleDocument(
      sale,
      facilityName: facilityName,
      facilityType: facilityType,
      facilityPhone: facilityPhone,
      facilityEmail: facilityEmail,
      facilityAddress: facilityAddress,
      facilityTagline: facilityTagline,
      facilityTin: facilityTin,
    );
    await Printing.layoutPdf(
      onLayout: (format) => doc.save(),
      name: 'receipt-${sale.receiptNumber ?? sale.id}.pdf',
    );
  }

  /// Opens the OS's native print/share preview for a Service receipt.
  static Future<void> printOrDownloadService(
    Service service, {
    required String facilityName,
    String? facilityType,
    String? facilityPhone,
    String? facilityEmail,
    String? facilityAddress,
    String? facilityTagline,
    String? facilityTin,
  }) async {
    final doc = await _buildServiceDocument(
      service,
      facilityName: facilityName,
      facilityType: facilityType,
      facilityPhone: facilityPhone,
      facilityEmail: facilityEmail,
      facilityAddress: facilityAddress,
      facilityTagline: facilityTagline,
      facilityTin: facilityTin,
    );
    await Printing.layoutPdf(
      onLayout: (format) => doc.save(),
      name: 'receipt-${service.receiptNumber ?? service.id}.pdf',
    );
  }

  /// Returns the raw PDF bytes for a Sale receipt - for showing an
  /// in-app preview (via PdfPreview) before any print/share action,
  /// rather than only being usable through printOrDownloadSale's
  /// straight-to-OS-dialog flow.
  static Future<Uint8List> buildSaleBytes(
    Sale sale, {
    required String facilityName,
    String? facilityType,
    String? facilityPhone,
    String? facilityEmail,
    String? facilityAddress,
    String? facilityTagline,
    String? facilityTin,
  }) async {
    final doc = await _buildSaleDocument(
      sale,
      facilityName: facilityName,
      facilityType: facilityType,
      facilityPhone: facilityPhone,
      facilityEmail: facilityEmail,
      facilityAddress: facilityAddress,
      facilityTagline: facilityTagline,
      facilityTin: facilityTin,
    );
    return doc.save();
  }

  /// Same as buildSaleBytes, for a Service receipt.
  static Future<Uint8List> buildServiceBytes(
    Service service, {
    required String facilityName,
    String? facilityType,
    String? facilityPhone,
    String? facilityEmail,
    String? facilityAddress,
    String? facilityTagline,
    String? facilityTin,
  }) async {
    final doc = await _buildServiceDocument(
      service,
      facilityName: facilityName,
      facilityType: facilityType,
      facilityPhone: facilityPhone,
      facilityEmail: facilityEmail,
      facilityAddress: facilityAddress,
      facilityTagline: facilityTagline,
      facilityTin: facilityTin,
    );
    return doc.save();
  }

  // ---------- Sale document ----------

  static Future<pw.Document> _buildSaleDocument(
    Sale sale, {
    required String facilityName,
    String? facilityType,
    String? facilityPhone,
    String? facilityEmail,
    String? facilityAddress,
    String? facilityTagline,
    String? facilityTin,
  }) async {
    final doc = pw.Document();
    final balance = sale.totalAmount - sale.totalPaid;
    final statusText = balance > 0 ? (sale.totalPaid > 0 ? 'Partially Paid' : 'Balance Due') : 'Paid in Full';
    final statusColor = balance > 0 ? _red : _green;
    final discountTotal = sale.items.fold(0.0, (sum, i) => sum + i.discount);
    final subtotal = sale.totalAmount + discountTotal;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(32, 28, 32, 28),
        header: (context) => _pageHeader('Sale Receipt', facilityName, sale.timestamp, context.pageNumber, context.pagesCount),
        footer: (context) => _pageFooter(context.pageNumber, context.pagesCount),
        build: (context) => [
          _facilityHeaderBlock(
            facilityName: facilityName,
            facilityType: facilityType,
            facilityPhone: facilityPhone,
            facilityEmail: facilityEmail,
            facilityAddress: facilityAddress,
            facilityTagline: facilityTagline,
            facilityTin: facilityTin,
          ),
          pw.SizedBox(height: 16),
          _metaSection([
            _kvPair('Receipt #', sale.receiptNumber?.toString() ?? sale.id.substring(0, sale.id.length < 6 ? sale.id.length : 6)),
            _kvPair('Date', _dateTime.format(sale.timestamp)),
            _kvPair('Customer', sale.clientName ?? 'Walk-in'),
            _kvPair('Payment Method', sale.paymentMethod ?? 'On Credit'),
          ]),
          pw.SizedBox(height: 14),
          _itemsTable(
            sale.items
                .map((item) => [
                      item.category.isNotEmpty ? '${item.name}\n${item.category}' : item.name,
                      '${item.quantity}',
                      _money.format(item.unitPrice),
                      _money.format(item.quantity * item.unitPrice - item.discount),
                    ])
                .toList(),
          ),
          pw.SizedBox(height: 12),
          _totalsBlock(
            subtotal: subtotal,
            discount: discountTotal,
            total: sale.totalAmount,
            paid: sale.totalPaid,
            balance: balance,
            statusText: statusText,
            statusColor: statusColor,
          ),
          pw.SizedBox(height: 20),
          _thankYouBlock(),
        ],
      ),
    );

    return doc;
  }

  // ---------- Service document ----------

  static Future<pw.Document> _buildServiceDocument(
    Service service, {
    required String facilityName,
    String? facilityType,
    String? facilityPhone,
    String? facilityEmail,
    String? facilityAddress,
    String? facilityTagline,
    String? facilityTin,
  }) async {
    final doc = pw.Document();
    final balance = service.totalAmount - service.totalPaid;
    final statusText = balance > 0 ? (service.totalPaid > 0 ? 'Partially Paid' : 'Balance Due') : 'Paid in Full';
    final statusColor = balance > 0 ? _red : _green;
    final itemsUsedTotal = service.itemsUsed.fold(0.0, (sum, item) {
      final p = item['price'];
      return sum + (p is num ? p.toDouble() : 0.0);
    });
    final serviceFeePortion = service.totalAmount - itemsUsedTotal;
    final serviceDate = service.serviceDate ?? DateTime.now();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(32, 28, 32, 28),
        header: (context) => _pageHeader('Service Receipt', facilityName, serviceDate, context.pageNumber, context.pagesCount),
        footer: (context) => _pageFooter(context.pageNumber, context.pagesCount),
        build: (context) => [
          _facilityHeaderBlock(
            facilityName: facilityName,
            facilityType: facilityType,
            facilityPhone: facilityPhone,
            facilityEmail: facilityEmail,
            facilityAddress: facilityAddress,
            facilityTagline: facilityTagline,
            facilityTin: facilityTin,
          ),
          pw.SizedBox(height: 16),
          _metaSection([
            _kvPair('Receipt #', service.receiptNumber?.toString() ?? service.id.substring(0, service.id.length < 6 ? service.id.length : 6)),
            _kvPair('Date', _dateTime.format(serviceDate)),
            _kvPair('Customer', service.clientName ?? 'Walk-in'),
            _kvPair('Provided By', service.providedByName ?? 'N/A'),
            _kvPair('Payment Method', service.paymentMethod ?? 'On Credit'),
          ]),
          pw.SizedBox(height: 14),
          _itemsTable([
            [service.name, '1', _money.format(serviceFeePortion), _money.format(serviceFeePortion)],
            for (final item in service.itemsUsed)
              [
                (item['itemName'] ?? '').toString(),
                '1',
                _money.format((item['price'] is num) ? (item['price'] as num).toDouble() : 0.0),
                _money.format((item['price'] is num) ? (item['price'] as num).toDouble() : 0.0),
              ],
          ]),
          pw.SizedBox(height: 12),
          _totalsBlock(
            subtotal: service.totalAmount,
            discount: 0,
            total: service.totalAmount,
            paid: service.totalPaid,
            balance: balance,
            statusText: statusText,
            statusColor: statusColor,
          ),
          pw.SizedBox(height: 20),
          _thankYouBlock(),
        ],
      ),
    );

    return doc;
  }

  // ---------- Shared building blocks ----------

  static pw.Widget _pageHeader(String kind, String facilityName, DateTime date, int pageNumber, int pagesCount) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.75))),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('VetBiz Pro - $kind', style: pw.TextStyle(fontSize: 9, color: _grey, fontWeight: pw.FontWeight.bold)),
          pw.Text('$facilityName - ${_fullDate.format(date)}  |  Page $pageNumber of $pagesCount',
              style: pw.TextStyle(fontSize: 9, color: _grey)),
        ],
      ),
    );
  }

  static pw.Widget _pageFooter(int pageNumber, int pagesCount) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.75))),
      child: pw.Text('Generated by VetBiz Pro', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
    );
  }

  static pw.Widget _facilityHeaderBlock({
    required String facilityName,
    String? facilityType,
    String? facilityPhone,
    String? facilityEmail,
    String? facilityAddress,
    String? facilityTagline,
    String? facilityTin,
  }) {
    final displayName = facilityType != null && facilityType.isNotEmpty && facilityType != 'Other'
        ? '$facilityName $facilityType'
        : facilityName;

    final contactLines = <String>[
      if (facilityPhone != null && facilityPhone.isNotEmpty) facilityPhone,
      if (facilityEmail != null && facilityEmail.isNotEmpty) facilityEmail,
      if (facilityAddress != null && facilityAddress.isNotEmpty) facilityAddress,
      if (facilityTin != null && facilityTin.isNotEmpty) 'TIN: $facilityTin',
    ];

    return pw.Center(
      child: pw.Column(
        children: [
          pw.RichText(
            text: pw.TextSpan(
              children: [
                pw.TextSpan(text: 'VetBiz ', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: _deepGreen)),
                pw.TextSpan(text: 'Pro', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: _amber)),
              ],
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(displayName, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: _deepGreen)),
          if (facilityTagline != null && facilityTagline.isNotEmpty) ...[
            pw.SizedBox(height: 2),
            pw.Text(facilityTagline, style: pw.TextStyle(fontSize: 10, color: _grey)),
          ],
          if (contactLines.isNotEmpty) ...[
            pw.SizedBox(height: 6),
            pw.Text(contactLines.join('   |   '), style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
          ],
        ],
      ),
    );
  }

  static pw.Widget _kvPair(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        children: [
          pw.SizedBox(width: 100, child: pw.Text(label, style: pw.TextStyle(fontSize: 10.5, color: _grey))),
          pw.Text(value, style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  static pw.Widget _metaSection(List<pw.Widget> rows) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 8),
      decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.75))),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: rows),
    );
  }

  static pw.Widget _itemsTable(List<List<String>> rows) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: const {0: pw.FlexColumnWidth(4), 1: pw.FlexColumnWidth(1), 2: pw.FlexColumnWidth(2), 3: pw.FlexColumnWidth(2)},
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _deepGreen),
          children: ['Item / Service', 'Qty', 'Unit Price', 'Amount']
              .asMap()
              .entries
              .map((e) => pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                    child: pw.Text(e.value,
                        textAlign: e.key == 0 ? pw.TextAlign.left : pw.TextAlign.right,
                        style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                  ))
              .toList(),
        ),
        for (final row in rows)
          pw.TableRow(
            children: row
                .asMap()
                .entries
                .map((e) => pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                      child: pw.Text(e.value,
                          textAlign: e.key == 0 ? pw.TextAlign.left : pw.TextAlign.right,
                          style: pw.TextStyle(fontSize: 9.5, color: e.key == 0 ? PdfColors.grey700 : PdfColors.black)),
                    ))
                .toList(),
          ),
      ],
    );
  }

  static pw.Widget _totalsBlock({
    required double subtotal,
    required double discount,
    required double total,
    required double paid,
    required double balance,
    required String statusText,
    required PdfColor statusColor,
  }) {
    pw.Widget row(String label, String value, {bool bold = false, PdfColor? color}) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label, style: pw.TextStyle(fontSize: 10, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, color: color)),
            pw.Text(value, style: pw.TextStyle(fontSize: 10, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, color: color)),
          ],
        ),
      );
    }

    return pw.Container(
      alignment: pw.Alignment.centerRight,
      child: pw.SizedBox(
        width: 260,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            if (discount > 0) ...[
              row('Subtotal', 'Tsh ${_money.format(subtotal)}'),
              row('Discount', '- Tsh ${_money.format(discount)}'),
            ],
            pw.Container(
              margin: const pw.EdgeInsets.symmetric(vertical: 4),
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              color: _lightGrey,
              child: row('TOTAL', 'Tsh ${_money.format(total)}', bold: true),
            ),
            row('Paid', 'Tsh ${_money.format(paid)}'),
            if (balance > 0) row('Balance', 'Tsh ${_money.format(balance)}', bold: true, color: _red),
            pw.SizedBox(height: 6),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: pw.BoxDecoration(color: statusColor == _red ? _redPillBg : _greenPillBg),
                child: pw.Text(statusText, style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: statusColor)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _thankYouBlock() {
    return pw.Center(
      child: pw.Column(
        children: [
          pw.Text('Thank you for choosing us.', style: pw.TextStyle(fontSize: 11, fontStyle: pw.FontStyle.italic, color: _grey)),
          pw.SizedBox(height: 4),
          pw.Text('Powered by VetBiz Pro', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
        ],
      ),
    );
  }
}
