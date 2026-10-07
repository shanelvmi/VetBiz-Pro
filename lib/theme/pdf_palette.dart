import 'package:pdf/pdf.dart';

import 'app_palette.dart';

/// Colours for PDFs and printing (receipts, daily reports).
///
/// Not themed on purpose: a printed receipt looks the same whatever colour
/// theme the person picked on screen. Values are exactly the ones the PDF
/// services use today (receipt_pdf_service.dart, daily_report_pdf_service.dart).
class PdfPalette {
  PdfPalette._();

  /// The brand green, from AppPalette (it was a pasted copy of the same hex).
  static final PdfColor brand = PdfColor.fromInt(AppPalette.primary.toARGB32());

  /// The receipt's amber. Not the brand accent (0xFFFFB200): a darker,
  /// print-friendly amber.
  static final PdfColor amber = PdfColor.fromInt(0xFFE0A32E);

  static final PdfColor danger = PdfColor.fromInt(0xFFC62828);
  static final PdfColor success = PdfColor.fromInt(0xFF2E7D32);
  static final PdfColor textMuted = PdfColor.fromInt(0xFF616161);
  static final PdfColor rule = PdfColor.fromInt(0xFFE0E0E0);

  /// Pill backgrounds: the danger and success colours at 0x1F alpha.
  static final PdfColor dangerPillBg = PdfColor.fromInt(0x1FC62828);
  static final PdfColor successPillBg = PdfColor.fromInt(0x1F2E7D32);

  // The pdf package's own greys, used as-is.
  static const PdfColor grey300 = PdfColors.grey300;
  static const PdfColor grey400 = PdfColors.grey400;
  static const PdfColor grey500 = PdfColors.grey500;
  static const PdfColor grey700 = PdfColors.grey700;
  static const PdfColor grey800 = PdfColors.grey800;
  static const PdfColor white = PdfColors.white;
  static const PdfColor black = PdfColors.black;
}
