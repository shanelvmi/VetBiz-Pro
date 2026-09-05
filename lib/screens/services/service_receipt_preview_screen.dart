import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

import '../../models/service.dart';
import '../../providers/facility_provider.dart';
import '../../services/receipt_printer_service.dart';
import '../settings/printer_settings_screen.dart';
import '../../utils/web_download.dart';

/// Shows the service receipt as it will actually look before doing
/// anything with it - same pattern as Sales' ReceiptPreviewScreen, just
/// for a Service instead of a Sale.
class ServiceReceiptPreviewScreen extends StatefulWidget {
  final Service service;
  const ServiceReceiptPreviewScreen({super.key, required this.service});

  @override
  State<ServiceReceiptPreviewScreen> createState() => _ServiceReceiptPreviewScreenState();
}

class _ServiceReceiptPreviewScreenState extends State<ServiceReceiptPreviewScreen> {
  static const Color primaryColor = Color(0xFF2F5D62);
  final GlobalKey _receiptKey = GlobalKey();
  final NumberFormat _moneyFormat = NumberFormat('#,##0', 'en_US');

  bool _isSharing = false;
  bool _isPrinting = false;

  @override
  void initState() {
    super.initState();
    // Same reasoning as ReceiptPreviewScreen - pre-cache the logo so it's
    // guaranteed loaded before a capture happens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final facilityProvider = Provider.of<FacilityProvider>(context, listen: false);
      final logoUrl = facilityProvider.selectedFacility?['logoUrl'] as String?;
      if (logoUrl != null && logoUrl.isNotEmpty) {
        precacheImage(NetworkImage(logoUrl), context);
      }
    });
  }

  Future<Uint8List?> _captureReceiptImage() async {
    final boundary =
        _receiptKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;

    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  Future<void> _shareOrSave() async {
    setState(() => _isSharing = true);
    Uint8List? bytes;
    try {
      bytes = await _captureReceiptImage();
      if (bytes == null) throw Exception('Could not capture the receipt image.');

      final xfile = XFile.fromData(
        bytes,
        name: 'service_receipt_${widget.service.id}.png',
        mimeType: 'image/png',
      );

      debugPrint('Receipt captured: ${bytes.length} bytes. Opening share sheet...');
      await Share.shareXFiles([xfile], text: 'Receipt');
      debugPrint('Share sheet closed normally.');
    } catch (e, stack) {
      if (!mounted) return;
      // Confirmed via testing: this is desktop browsers' well-known
      // unreliable support for file-sharing through the Web Share API
      // - not a benign cancellation, and not worth showing as a scary
      // error when there's a reliable fallback that still gets the
      // file onto the user's device.
      if (kIsWeb && bytes != null) {
        downloadFileWeb(bytes, 'service_receipt_${widget.service.id}.png');
        return;
      }
      debugPrint('Share receipt failed: ${e.runtimeType} - $e\n$stack');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: SelectableText('Could not share receipt: $e', style: const TextStyle(color: Colors.white)),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 10),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  Future<void> _print() async {
    setState(() => _isPrinting = true);
    final printerService = ReceiptPrinterService();

    try {
      final connected = await printerService.isConnected;

      if (!connected) {
        if (!mounted) return;
        final goToSettings = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('No Printer Connected'),
            content: const Text(
                'Connect a Bluetooth receipt printer in Printer Settings first.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Go to Printer Settings'),
              ),
            ],
          ),
        );
        if (goToSettings == true && mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PrinterSettingsScreen()),
          );
        }
        return;
      }

      final success = await printerService.printServiceReceipt(widget.service);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Receipt sent to printer' : 'Printer did not accept the receipt'),
          backgroundColor: success ? Colors.green : Colors.redAccent,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Print failed: $e'), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = widget.service;
    final balance = service.totalAmount - service.totalPaid;
    final facilityProvider = Provider.of<FacilityProvider>(context, listen: false);
    final facilityName = facilityProvider.selectedFacility?['name'] as String? ?? 'Facility';
    final facilityType = facilityProvider.selectedFacility?['type'] as String?;
    final logoUrl = facilityProvider.selectedFacility?['logoUrl'] as String?;
    final facilityEmail = facilityProvider.selectedFacility?['email'] as String?;
    final facilityPhone = facilityProvider.selectedFacility?['phone'] as String?;

    return Scaffold(
      backgroundColor: const Color(0xFFEDEDED),
      appBar: AppBar(
        title: const Text('Receipt Preview'),
        centerTitle: true,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final cardWidth = constraints.maxWidth < 360
              ? constraints.maxWidth - 40
              : 320.0;

          return Column(
            children: [
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFE4E4E4), Color(0xFFEFEFEF)],
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (constraints.maxWidth >= 900)
                        _buildSummaryPanel(service, balance, facilityName),
                      Expanded(
                        child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Container(
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.18),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: RepaintBoundary(
                          key: _receiptKey,
                          child: Container(
                            width: cardWidth,
                            padding: const EdgeInsets.all(24),
                            color: Colors.white,
                            child: DefaultTextStyle.merge(
                              style: const TextStyle(fontFamily: 'RobotoMono'),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                            if (logoUrl != null && logoUrl.isNotEmpty) ...[
                              Center(
                                child: SizedBox(
                                  width: 56,
                                  height: 56,
                                  child: Image.network(
                                    logoUrl,
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],
                            Text(
                              facilityType != null && facilityType.isNotEmpty && facilityType != 'Other'
                                  ? '$facilityName · $facilityType'
                                  : facilityName,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                            ),
                            Text(
                              balance > 0 ? 'Service Receipt - Balance Due' : 'Service Receipt',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 13),
                            ),
                            if ((facilityPhone != null && facilityPhone.isNotEmpty) ||
                                (facilityEmail != null && facilityEmail.isNotEmpty)) ...[
                              const SizedBox(height: 4),
                              if (facilityPhone != null && facilityPhone.isNotEmpty)
                                Text(
                                  facilityPhone,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 11, color: Colors.black87),
                                ),
                              if (facilityEmail != null && facilityEmail.isNotEmpty)
                                Text(
                                  facilityEmail,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 11, color: Colors.black87),
                                ),
                            ],
                            const SizedBox(height: 14),
                            const Text('- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -', maxLines: 1, overflow: TextOverflow.clip, style: TextStyle(letterSpacing: 1, height: 1)),
                            const SizedBox(height: 4),
                            if (service.receiptNumber != null) ...[
                              Text('Receipt #: ${service.receiptNumber}'),
                              const SizedBox(height: 2),
                            ],
                            Text(service.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                            const SizedBox(height: 4),
                            Text('Client: ${service.clientName ?? 'Walk-in'}'),
                            const SizedBox(height: 2),
                            Text('Provided by: ${service.providedByName ?? 'N/A'}'),
                            const SizedBox(height: 2),
                            if (service.serviceDate != null)
                              Text('Date: ${DateFormat('dd MMM yyyy, HH:mm').format(service.serviceDate!)}'),
                            const SizedBox(height: 4),
                            const Text('- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -', maxLines: 1, overflow: TextOverflow.clip, style: TextStyle(letterSpacing: 1, height: 1)),
                            if (service.itemsUsed.isNotEmpty)
                              ...service.itemsUsed.map((item) {
                                final name = (item['itemName'] ?? '').toString();
                                final price = (item['price'] is num) ? (item['price'] as num).toDouble() : 0.0;
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(child: Text(name)),
                                      Text(_moneyFormat.format(price)),
                                    ],
                                  ),
                                );
                              }),
                            const Text('- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -', maxLines: 1, overflow: TextOverflow.clip, style: TextStyle(letterSpacing: 1, height: 1)),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Total', style: TextStyle(fontWeight: FontWeight.bold)),
                                Text('Tsh ${_moneyFormat.format(service.totalAmount)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Paid'),
                                Text('Tsh ${_moneyFormat.format(service.totalPaid)}'),
                              ],
                            ),
                            if (balance > 0) const SizedBox(height: 4),
                            if (balance > 0)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Balance', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                                  Text('Tsh ${_moneyFormat.format(balance)}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                                ],
                              ),
                            const SizedBox(height: 18),
                            const Text('Thank you for your business!',
                                textAlign: TextAlign.center, style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12)),
                            const SizedBox(height: 12),
                            Text('Powered by VetBiz Pro',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 9, color: Colors.grey[500])),
                          ],
                        ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
                      ),
                    ],
                  ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isSharing ? null : _shareOrSave,
                            icon: _isSharing
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.share),
                            label: const Text('Share / Save'),
                            style: OutlinedButton.styleFrom(foregroundColor: primaryColor),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isPrinting ? null : _print,
                            icon: _isPrinting
                                ? const SizedBox(
                                    width: 16, height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.print),
                            label: const Text('Print'),
                            style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// A readable, desktop-sized summary shown beside the receipt on wide
  /// screens - same reasoning as the Sales receipt: the receipt's own
  /// text is deliberately tiny to match actual thermal-printer output,
  /// which is correct for the receipt but not great for someone
  /// reviewing it on a desktop monitor.
  Widget _buildSummaryPanel(Service service, double balance, String facilityName) {
    final statusColor = balance > 0 ? Colors.red : Colors.green;
    final statusText = balance > 0
        ? (service.totalPaid > 0 ? 'Partially Paid' : 'Balance Due')
        : 'Paid in Full';

    Widget row(String label, String value, {Color? valueColor, bool bold = false}) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                color: valueColor ?? Colors.black87,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: 260,
      margin: const EdgeInsets.only(right: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusColor.withValues(alpha: 0.4)),
            ),
            child: Text(
              statusText,
              style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          const SizedBox(height: 18),
          if (service.receiptNumber != null) row('Receipt Number', '#${service.receiptNumber}'),
          row('Facility', facilityName),
          row('Service', service.name),
          row('Client', service.clientName ?? 'Walk-in'),
          row('Provided By', service.providedByName ?? 'N/A'),
          if (service.serviceDate != null)
            row('Date', DateFormat('dd MMM yyyy, HH:mm').format(service.serviceDate!)),
          const Divider(height: 24),
          row('Total Amount', 'Tsh ${_moneyFormat.format(service.totalAmount)}', bold: true),
          row('Total Paid', 'Tsh ${_moneyFormat.format(service.totalPaid)}'),
          if (balance > 0) row('Balance Due', 'Tsh ${_moneyFormat.format(balance)}', valueColor: Colors.red, bold: true),
          if (service.paymentMethod != null) row('Payment Method', service.paymentMethod!),
        ],
      ),
    );
  }
}
