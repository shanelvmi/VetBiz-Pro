import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';

import '../../models/service.dart';
import '../../providers/facility_provider.dart';
import '../../services/receipt_printer_service.dart';
import '../../services/receipt_pdf_service.dart';
import '../settings/printer_settings_screen.dart';
import '../../utils/web_download.dart';
import '../../config/money.dart';
import '../../config/app_rules.dart';
import '../../config/payment_methods.dart';
import '../../config/app_date_format.dart';
import '../../config/app_info.dart';
import '../../theme/app_text.dart';
import '../../theme/app_dimens.dart';
import '../../theme/theme_context.dart';
import '../../theme/app_breakpoints.dart';
// The receipt's brand green is the fixed brand colour, not the theme's:
// the preview matches the printed receipt (PdfPalette.brand).
import '../../theme/app_palette.dart';
import '../../ui/feedback/app_feedback.dart';

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
  final GlobalKey _receiptKey = GlobalKey();

  bool _isSharing = false;
  bool _isPrinting = false;
  String _selectedFormat = 'thermal';

  @override
  void initState() {
    super.initState();
    // Same reasoning as ReceiptPreviewScreen - pre-cache the logo so it's
    // guaranteed loaded before a capture happens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final facilityProvider = Provider.of<FacilityProvider>(context, listen: false);
      final logoUrl = facilityProvider.selectedFacility?['logoUrl'];
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
    if (_selectedFormat == 'a4') {
      await _shareOrPrintA4Pdf();
      return;
    }
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
      // The raw error used to be shown as selectable text for 10 s; it is
      // now behind Details (owner's rule: no inline raw error text).
      AppFeedback.error("Couldn't share the receipt", error: e, stackTrace: stack);
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  Future<void> _print() async {
    if (_selectedFormat == 'a4') {
      await _shareOrPrintA4Pdf();
      return;
    }
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
      if (success) {
        AppFeedback.success('Receipt sent to printer');
      } else {
        AppFeedback.error("Couldn't print the receipt", detail: 'The printer did not accept it');
      }
    } catch (e, st) {
      AppFeedback.error("Couldn't print the receipt", error: e, stackTrace: st);
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  // Generates the A4 PDF and opens the OS's native print/share preview -
  // used by both _shareOrSave and _print, since Printing.layoutPdf's own
  // preview already offers both actions, unlike the thermal path where
  // print and share are genuinely different mechanisms (Bluetooth vs a
  // captured image).
  Future<void> _shareOrPrintA4Pdf() async {
    setState(() {
      _isSharing = true;
      _isPrinting = true;
    });
    try {
      final facility = Provider.of<FacilityProvider>(context, listen: false).selectedFacility;
      await ReceiptPdfService.printOrDownloadService(
        widget.service,
        facilityName: facility?['name'] ?? 'Facility',
        facilityType: facility?['type'],
        facilityPhone: facility?['phone'],
        facilityEmail: facility?['email'],
        facilityAddress: facility?['address'],
        facilityTagline: facility?['tagline'],
        facilityTin: facility?['tin'],
      );
    } catch (e, st) {
      AppFeedback.error("Couldn't generate the PDF", error: e, stackTrace: st);
    } finally {
      if (mounted) {
        setState(() {
          _isSharing = false;
          _isPrinting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = widget.service;
    final balance = service.totalAmount - service.totalPaid;
    final facilityProvider = Provider.of<FacilityProvider>(context, listen: false);
    final facility = facilityProvider.selectedFacility;
    final facilityName = facility?['name'] ?? 'Facility';
    final facilityType = facility?['type'];
    final logoUrl = facility?['logoUrl'];
    final facilityPhone = facility?['phone'];
    final facilityEmail = facility?['email'];
    final facilityAddress = facility?['address'];
    final facilityTagline = facility?['tagline'];
    final facilityTin = facility?['tin'];
    final statusText = balance > 0
        ? (service.totalPaid > 0 ? 'Partially Paid' : 'Balance Due')
        : 'Paid in Full';
    final statusColor = balance > 0 ? context.colors.danger : context.colors.success;

    return Scaffold(
      backgroundColor: context.colors.surfaceMuted,
      appBar: AppBar(
        title: const Text('Receipt Preview'),
        centerTitle: true,
        backgroundColor: context.colors.primary,
        foregroundColor: context.colors.onPrimary,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= AppBreakpoints.medium;
          final thermalReceipt = Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.s24),
              child: RepaintBoundary(
                key: _receiptKey,
                child: _buildReceiptCard(
                  service: service,
                  balance: balance,
                  facilityName: facilityName,
                  facilityType: facilityType,
                  logoUrl: logoUrl,
                  facilityPhone: facilityPhone,
                  facilityEmail: facilityEmail,
                  facilityAddress: facilityAddress,
                  facilityTagline: facilityTagline,
                  facilityTin: facilityTin,
                  statusText: statusText,
                ),
              ),
            ),
          );

          // A4 shows a real in-app PDF preview before any print/share
          // action, matching the Sales receipt's identical treatment.
          final receipt = _selectedFormat == 'a4'
              ? Padding(
                  padding: const EdgeInsets.all(AppSpacing.s24),
                  child: PdfPreview(
                    build: (format) => ReceiptPdfService.buildServiceBytes(
                      service,
                      facilityName: facilityName,
                      facilityType: facilityType,
                      facilityPhone: facilityPhone,
                      facilityEmail: facilityEmail,
                      facilityAddress: facilityAddress,
                      facilityTagline: facilityTagline,
                      facilityTin: facilityTin,
                    ),
                    allowPrinting: false,
                    allowSharing: false,
                    canChangePageFormat: false,
                    canChangeOrientation: false,
                    canDebug: false,
                    useActions: false,
                  ),
                )
              : thermalReceipt;

          if (!isWide) {
            return Column(
              children: [
                Expanded(child: receipt),
                _buildActionBar(),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildFormatSidebar(),
              Expanded(
                child: Column(
                  children: [
                    Expanded(child: receipt),
                  ],
                ),
              ),
              _buildDetailsSidebar(
                service: service,
                balance: balance,
                facilityName: facilityName,
                facilityType: facilityType,
                statusText: statusText,
                statusColor: statusColor,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFormatSidebar() {
    Widget miniLine(double widthFraction, {bool dark = false}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s2),
        child: FractionallySizedBox(
          widthFactor: widthFraction,
          alignment: Alignment.centerLeft,
          child: Container(height: 2.5, color: dark ? context.colors.textHint : context.colors.border),
        ),
      );
    }

    Widget miniReceiptPreview({required bool selected, required bool isThermal}) {
      return Container(
        width: isThermal ? 68 : 98,
        height: 100,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: AppSpacing.s8),
        decoration: BoxDecoration(
          color: context.colors.surface,
          border: Border.all(color: context.colors.textHint.withValues(alpha: AppAlpha.a20)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Icon(Icons.storefront_outlined, size: AppIconSize.i12, color: selected ? context.colors.primary : context.colors.textDisabled),
            const SizedBox(height: AppSpacing.s4),
            miniLine(0.8, dark: true),
            const SizedBox(height: AppSpacing.s4),
            miniLine(1.0),
            miniLine(0.6),
            miniLine(0.9),
            const SizedBox(height: AppSpacing.s4),
            miniLine(1.0),
            miniLine(1.0),
            miniLine(0.7),
            const SizedBox(height: AppSpacing.s4),
            miniLine(0.8, dark: true),
          ],
        ),
      );
    }

    Widget thumbnail({required String formatKey, required bool isThermal, required String label}) {
      final selected = _selectedFormat == formatKey;
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.s16),
        child: InkWell(
          onTap: () => setState(() => _selectedFormat = formatKey),
          borderRadius: BorderRadius.circular(AppRadius.r8),
          child: Column(
            children: [
              Container(
                width: 98,
                height: 115,
                decoration: BoxDecoration(
                  color: context.colors.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppRadius.r8),
                  border: Border.all(color: selected ? context.colors.primary : context.colors.textHint.withValues(alpha: AppAlpha.a30), width: selected ? 2 : 1),
                ),
                alignment: Alignment.center,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.r4),
                  child: miniReceiptPreview(selected: selected, isThermal: isThermal),
                ),
              ),
              const SizedBox(height: AppSpacing.s6),
              Text(label, style: TextStyle(fontSize: AppFontSize.f11_5, color: selected ? context.colors.primary : context.colors.textMuted, fontWeight: selected ? AppFontWeight.semibold : AppFontWeight.regular)),
            ],
          ),
        ),
      );
    }

    return Container(
      width: 148,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s20, horizontal: AppSpacing.s20),
      child: Column(
        children: [
          thumbnail(formatKey: 'thermal', isThermal: true, label: 'Receipt (Thermal)'),
          thumbnail(formatKey: 'a4', isThermal: false, label: 'A4 Format'),
        ],
      ),
    );
  }

  Widget _buildReceiptCard({
    required Service service,
    required double balance,
    required String facilityName,
    required String? facilityType,
    required String? logoUrl,
    required String? facilityPhone,
    required String? facilityEmail,
    required String? facilityAddress,
    required String? facilityTagline,
    required String? facilityTin,
    required String statusText,
  }) {
    // The service fee itself, separate from the medicine/supplies used
    // during the visit - service.totalAmount already includes both, so
    // this is what's left once the itemsUsed total is taken out.
    final itemsUsedTotal = service.itemsUsed.fold(0.0, (sum, item) {
      final p = item['price'];
      return sum + (p is num ? p.toDouble() : 0.0);
    });
    final serviceFeePortion = service.totalAmount - itemsUsedTotal;

    Widget divider() => Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.s12),
          child: Divider(height: 1, color: context.colors.textHint.withValues(alpha: AppAlpha.a30)),
        );

    Widget contactRow(IconData icon, String text) {
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.s3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: AppIconSize.i12, color: context.colors.textMuted),
            const SizedBox(width: AppSpacing.s4),
            Text(text, style: TextStyle(fontSize: AppFontSize.f11_5, color: context.colors.textSoft)),
          ],
        ),
      );
    }

    Widget infoLine(String label1, String value1, {String? label2, String? value2}) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.s3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: RichText(
                text: TextSpan(
                  style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textPrimary),
                  children: [
                    TextSpan(text: '$label1: ', style: const TextStyle(fontWeight: AppFontWeight.semibold)),
                    TextSpan(text: value1),
                  ],
                ),
              ),
            ),
            if (label2 != null && value2 != null)
              Expanded(
                flex: 2,
                child: Text('$label2: $value2', textAlign: TextAlign.right, style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textPrimary)),
              ),
          ],
        ),
      );
    }

    Widget itemsTableHeader() {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s10, vertical: AppSpacing.s8),
        decoration: BoxDecoration(color: context.colors.primary, borderRadius: BorderRadius.circular(AppRadius.r4)),
        child: Row(
          children: [
            Expanded(flex: 4, child: Text('Item / Service', style: TextStyle(color: context.colors.onPrimary, fontSize: AppFontSize.f11_5, fontWeight: AppFontWeight.semibold))),
            Expanded(flex: 1, child: Text('Qty', style: TextStyle(color: context.colors.onPrimary, fontSize: AppFontSize.f11_5, fontWeight: AppFontWeight.semibold))),
            Expanded(flex: 2, child: Text('Unit Price', textAlign: TextAlign.right, style: TextStyle(color: context.colors.onPrimary, fontSize: AppFontSize.f11_5, fontWeight: AppFontWeight.semibold))),
            Expanded(flex: 2, child: Text('Amount', textAlign: TextAlign.right, style: TextStyle(color: context.colors.onPrimary, fontSize: AppFontSize.f11_5, fontWeight: AppFontWeight.semibold))),
          ],
        ),
      );
    }

    Widget lineRow(String name, double amount) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 4, child: Text(name, style: const TextStyle(fontSize: AppFontSize.f12_5, fontWeight: AppFontWeight.semibold))),
            const Expanded(flex: 1, child: Text('1', style: TextStyle(fontSize: AppFontSize.f12_5))),
            Expanded(flex: 2, child: Text(Money.plain(amount), textAlign: TextAlign.right, style: const TextStyle(fontSize: AppFontSize.f12_5))),
            Expanded(flex: 2, child: Text(Money.plain(amount), textAlign: TextAlign.right, style: const TextStyle(fontSize: AppFontSize.f12_5, fontWeight: AppFontWeight.semibold))),
          ],
        ),
      );
    }

    Widget totalsRow(String label, String value, {bool bold = false, Color? color}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: AppFontSize.f12_5, fontWeight: bold ? AppFontWeight.bold : AppFontWeight.regular, color: color)),
            Text(value, style: TextStyle(fontSize: AppFontSize.f12_5, fontWeight: bold ? AppFontWeight.bold : AppFontWeight.regular, color: color)),
          ],
        ),
      );
    }

    return ClipPath(
      clipper: _TornEdgeClipper(),
      child: Container(
        width: 400,
        color: context.colors.surface,
        padding: const EdgeInsets.fromLTRB(AppSpacing.s24, AppSpacing.s28, AppSpacing.s24, AppSpacing.s28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ---- Header ----
            Center(
              child: Column(
                children: [
                  if (logoUrl != null && logoUrl.isNotEmpty) ...[
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: Image.network(
                        logoUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s6),
                  ],
                  RichText(
                    text: const TextSpan(
                      style: TextStyle(fontSize: AppFontSize.f16, fontWeight: AppFontWeight.bold),
                      children: [
                        TextSpan(text: 'VetBiz ', style: TextStyle(color: AppPalette.primary)),
                        TextSpan(text: 'Pro', style: TextStyle(color: Color(0xFFE0A32E))),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  Text(
                    facilityType != null && facilityType.isNotEmpty && facilityType != 'Other'
                        ? '$facilityName $facilityType'
                        : facilityName,
                    style: const TextStyle(fontSize: AppFontSize.f19, fontWeight: AppFontWeight.bold, color: AppPalette.primary),
                    textAlign: TextAlign.center,
                  ),
                  if (facilityTagline != null && facilityTagline.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.s2),
                      child: Text(facilityTagline, style: TextStyle(fontSize: AppFontSize.f11_5, color: context.colors.textMuted), textAlign: TextAlign.center),
                    ),
                  if (facilityPhone != null && facilityPhone.isNotEmpty) contactRow(Icons.phone, facilityPhone),
                  if (facilityEmail != null && facilityEmail.isNotEmpty) contactRow(Icons.email_outlined, facilityEmail),
                  if (facilityAddress != null && facilityAddress.isNotEmpty) contactRow(Icons.location_on_outlined, facilityAddress),
                  if (facilityTin != null && facilityTin.isNotEmpty) contactRow(Icons.badge_outlined, 'TIN: $facilityTin'),
                ],
              ),
            ),
            divider(),
            // ---- Receipt meta ----
            infoLine('Receipt #', service.receiptNumber?.toString() ?? service.id.substring(0, service.id.length < AppRules.fallbackReceiptIdLength ? service.id.length : AppRules.fallbackReceiptIdLength),
                label2: service.serviceDate != null ? 'Date' : null,
                value2: service.serviceDate != null ? AppDateFormat.dateTime24.format(service.serviceDate!) : null),
            infoLine('Customer', service.clientName ?? 'Walk-in'),
            infoLine('Provided By', service.providedByName ?? 'N/A'),
            infoLine('Payment Method', service.paymentMethod ?? PaymentMethod.onCredit),
            const SizedBox(height: AppSpacing.s10),
            // ---- Items table ----
            itemsTableHeader(),
            lineRow(service.name, serviceFeePortion),
            for (final item in service.itemsUsed)
              lineRow((item['itemName'] ?? '').toString(), (item['price'] is num) ? (item['price'] as num).toDouble() : 0.0),
            divider(),
            // ---- Totals ----
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s10, vertical: AppSpacing.s8),
              color: context.colors.primary.withValues(alpha: AppAlpha.a10),
              child: totalsRow('TOTAL', 'TSh ${Money.plain(service.totalAmount)}', bold: true),
            ),
            const SizedBox(height: AppSpacing.s8),
            totalsRow('Paid', Money.plain(service.totalPaid)),
            totalsRow('Balance', Money.plain(balance), bold: balance > 0, color: balance > 0 ? context.colors.danger : null),
            const SizedBox(height: AppSpacing.s10),
            Row(
              children: [
                Icon(Icons.credit_card, size: AppIconSize.i16, color: context.colors.textSoft),
                const SizedBox(width: AppSpacing.s6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Payment Method', style: TextStyle(fontSize: AppFontSize.f10_5, color: context.colors.textMuted)),
                      Text(service.paymentMethod ?? PaymentMethod.onCredit, style: const TextStyle(fontSize: AppFontSize.f12_5, fontWeight: AppFontWeight.semibold)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: AppSpacing.s3),
                  decoration: BoxDecoration(color: (balance > 0 ? context.colors.danger : context.colors.success).withValues(alpha: AppAlpha.a10), borderRadius: BorderRadius.circular(AppRadius.r20)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, size: AppIconSize.i12, color: balance > 0 ? context.colors.danger : context.colors.success),
                      const SizedBox(width: AppSpacing.s4),
                      Text(statusText, style: TextStyle(fontSize: AppFontSize.f10_5, fontWeight: AppFontWeight.semibold, color: balance > 0 ? context.colors.danger : context.colors.success)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s22),
            Center(
              child: Text('Thank you for choosing us.',
                  style: TextStyle(fontSize: AppFontSize.f13, fontStyle: FontStyle.italic, color: context.colors.textSoft)),
            ),
            const SizedBox(height: AppSpacing.s10),
            Center(
              child: RichText(
                text: const TextSpan(
                  style: TextStyle(fontSize: AppFontSize.f13, fontWeight: AppFontWeight.bold),
                  children: [
                    TextSpan(text: 'VetBiz ', style: TextStyle(color: AppPalette.primary)),
                    TextSpan(text: 'Pro', style: TextStyle(color: Color(0xFFE0A32E))),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s2),
            Center(
              child: Text('Powered by ${AppInfo.name}', style: TextStyle(fontSize: AppFontSize.f9, color: context.colors.textHint)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionBar() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      color: context.colors.surface,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isSharing ? null : _shareOrSave,
                  icon: _isSharing
                      ? const SizedBox(width: AppSpacing.s16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.share),
                  label: const Text('Share / Save'),
                  style: OutlinedButton.styleFrom(foregroundColor: context.colors.primary),
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isPrinting ? null : _print,
                  icon: _isPrinting
                      ? SizedBox(width: AppSpacing.s16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: context.colors.onPrimary))
                      : const Icon(Icons.print),
                  label: const Text('Print'),
                  style: ElevatedButton.styleFrom(backgroundColor: context.colors.primary, foregroundColor: context.colors.onPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailsSidebar({
    required Service service,
    required double balance,
    required String facilityName,
    required String? facilityType,
    required String statusText,
    required Color statusColor,
  }) {
    Widget field(IconData icon, String label, String value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: AppIconSize.i18, color: context.colors.primary),
            const SizedBox(width: AppSpacing.s10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: AppFontSize.f11_5, color: context.colors.textMuted)),
                  const SizedBox(height: AppSpacing.s2),
                  Text(value, style: const TextStyle(fontSize: AppFontSize.f13_5, fontWeight: AppFontWeight.semibold), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: 340,
      margin: const EdgeInsets.fromLTRB(0, AppSpacing.s20, AppSpacing.s20, AppSpacing.s20),
      padding: const EdgeInsets.all(AppSpacing.s18),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.r14),
        boxShadow: [BoxShadow(color: context.colors.shadow.withValues(alpha: AppAlpha.a05), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.s6),
                  decoration: BoxDecoration(color: context.colors.primary.withValues(alpha: AppAlpha.a10), borderRadius: BorderRadius.circular(AppRadius.r8)),
                  child: Icon(Icons.receipt_long_outlined, size: AppIconSize.i18, color: context.colors.primary),
                ),
                const SizedBox(width: AppSpacing.s8),
                const Expanded(child: Text('Receipt Details', style: TextStyle(fontSize: AppFontSize.f16, fontWeight: AppFontWeight.bold))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s10, vertical: AppSpacing.s4),
                  decoration: BoxDecoration(color: statusColor.withValues(alpha: AppAlpha.a10), borderRadius: BorderRadius.circular(AppRadius.r20)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, size: AppIconSize.i12, color: statusColor),
                      const SizedBox(width: AppSpacing.s3),
                      Text(statusText, style: TextStyle(fontSize: AppFontSize.f10_5, fontWeight: AppFontWeight.semibold, color: statusColor)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s8),
            const Divider(height: 20),
            if (service.receiptNumber != null) field(Icons.tag, 'Receipt Number', '${service.receiptNumber}'),
            field(
              Icons.storefront_outlined,
              'Facility',
              facilityType != null && facilityType.isNotEmpty && facilityType != 'Other'
                  ? '$facilityName $facilityType'
                  : facilityName,
            ),
            field(Icons.medical_services_outlined, 'Service', service.name),
            field(Icons.person_outline, 'Customer', service.clientName ?? 'Walk-in'),
            field(Icons.badge_outlined, 'Provided By', service.providedByName ?? 'N/A'),
            if (service.serviceDate != null)
              field(Icons.calendar_today_outlined, 'Date & Time', AppDateFormat.dateTime24.format(service.serviceDate!)),
            field(Icons.payment_outlined, 'Payment Method', service.paymentMethod ?? PaymentMethod.onCredit),
            const Divider(height: 28),
            Row(
              children: [
                Icon(Icons.bolt, size: AppIconSize.i16, color: context.colors.primary),
                const SizedBox(width: AppSpacing.s6),
                const Text('Quick Actions', style: TextStyle(fontSize: AppFontSize.f13_5, fontWeight: AppFontWeight.bold)),
              ],
            ),
            const SizedBox(height: AppSpacing.s12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isSharing ? null : _shareOrSave,
                    icon: _isSharing
                        ? const SizedBox(width: AppSpacing.s14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.share_outlined, size: AppIconSize.i16),
                    label: const Text('Share', style: TextStyle(fontSize: AppFontSize.f12_5)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.colors.primary,
                      backgroundColor: context.colors.primary.withValues(alpha: AppAlpha.a10),
                      side: BorderSide.none,
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s10),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.s8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isPrinting ? null : _print,
                    icon: _isPrinting
                        ? SizedBox(width: AppSpacing.s14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: context.colors.onPrimary))
                        : const Icon(Icons.print_outlined, size: AppIconSize.i16),
                    label: const Text('Print Receipt', style: TextStyle(fontSize: AppFontSize.f12_5)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.colors.primary,
                      foregroundColor: context.colors.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s10),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s16),
            Container(
              padding: const EdgeInsets.all(AppSpacing.s12),
              decoration: BoxDecoration(color: context.colors.surfaceMuted, borderRadius: BorderRadius.circular(AppRadius.r10)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: AppIconSize.i16, color: Colors.blueGrey[400]),
                  const SizedBox(width: AppSpacing.s8),
                  Expanded(
                    child: Text(
                      'This receipt shows the final amount paid for the selected transaction. You can print or share it for your records.',
                      style: TextStyle(fontSize: AppFontSize.f11, color: Colors.blueGrey[600], height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Same torn-paper edge clipper as the Sales receipt (kept as a separate
// copy here rather than a shared import, matching how this file already
// duplicates the rest of ReceiptPreviewScreen's structure for Service
// instead of Sale).
class _TornEdgeClipper extends CustomClipper<Path> {
  static const double toothWidth = 12;
  static const double toothDepth = 6;

  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, toothDepth);
    var x = 0.0;
    var goingDown = false;
    while (x < size.width) {
      final nextX = (x + toothWidth).clamp(0, size.width).toDouble();
      path.lineTo(nextX, goingDown ? toothDepth * 2 : 0);
      goingDown = !goingDown;
      x = nextX;
    }
    path.lineTo(size.width, size.height - toothDepth);
    x = size.width;
    goingDown = false;
    while (x > 0) {
      final nextX = (x - toothWidth).clamp(0, size.width).toDouble();
      path.lineTo(nextX, size.height - (goingDown ? toothDepth * 2 : 0));
      goingDown = !goingDown;
      x = nextX;
    }
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
