import 'dart:typed_data';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/sale.dart';
import '../models/service.dart';

/// Real Bluetooth thermal-printer integration - connects to a printer
/// already paired at the OS/Bluetooth-settings level (classic SPP
/// thermal printers can't be freshly discovered from inside a normal
/// app, only paired devices can be listed and connected to), remembers
/// the chosen printer and paper size across app restarts, and builds a
/// genuine ESC/POS-formatted receipt from a real Sale.
///
/// IMPORTANT: this can only be tested on a real Android/iOS build with
/// real Bluetooth thermal printer hardware - it cannot run in Chrome/web
/// at all (no Web Bluetooth support for this kind of device), so none of
/// this has been verified end-to-end yet. If the exact API shape of
/// `print_bluetooth_thermal` or `esc_pos_utils_plus` has shifted from
/// what's used here, expect small adjustments once you can actually
/// build and run this on a device.
class ReceiptPrinterService {
  static const _prefKeyMac = 'printer_mac_address';
  static const _prefKeyName = 'printer_name';
  static const _prefKeyPaperSize = 'printer_paper_size'; // '58' or '80'
  static const _prefKeyAutoPrint = 'printer_auto_print';

  /// Devices already paired via the phone/tablet's own Bluetooth settings.
  Future<List<BluetoothInfo>> getPairedDevices() {
    return PrintBluetoothThermal.pairedBluetooths;
  }

  Future<bool> get isConnected => PrintBluetoothThermal.connectionStatus;

  Future<bool> connect(String macAddress) {
    return PrintBluetoothThermal.connect(macPrinterAddress: macAddress);
  }

  Future<bool> disconnect() {
    return PrintBluetoothThermal.disconnect;
  }

  Future<void> saveLastPrinter({required String mac, required String name}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyMac, mac);
    await prefs.setString(_prefKeyName, name);
  }

  Future<Map<String, String>?> getLastPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    final mac = prefs.getString(_prefKeyMac);
    final name = prefs.getString(_prefKeyName);
    if (mac == null) return null;
    return {'mac': mac, 'name': name ?? 'Saved printer'};
  }

  Future<void> clearSavedPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKeyMac);
    await prefs.remove(_prefKeyName);
  }

  Future<String> getPaperSize() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefKeyPaperSize) ?? '58';
  }

  Future<void> setPaperSize(String size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyPaperSize, size);
  }

  Future<bool> getAutoPrint() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKeyAutoPrint) ?? false;
  }

  Future<void> setAutoPrint(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeyAutoPrint, value);
  }

  Future<Generator> _generator() async {
    final paperSize = await getPaperSize();
    final profile = await CapabilityProfile.load();
    return Generator(paperSize == '80' ? PaperSize.mm80 : PaperSize.mm58, profile);
  }

  /// Sends a small real test page - not a fake SnackBar claiming success,
  /// this genuinely writes ESC/POS bytes to the connected printer.
  Future<bool> printTestPage() async {
    final generator = await _generator();
    List<int> bytes = [];

    bytes += generator.text(
      'VetBiz Pro',
      styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2),
    );
    bytes += generator.text('Test Print', styles: const PosStyles(align: PosAlign.center));
    bytes += generator.hr();
    bytes += generator.text('If you can read this clearly,');
    bytes += generator.text('your printer is connected correctly.');
    bytes += generator.hr();
    bytes += generator.feed(2);
    bytes += generator.cut();

    return PrintBluetoothThermal.writeBytes(Uint8List.fromList(bytes));
  }

  /// Formats and prints a real sale receipt.
  Future<bool> printSaleReceipt(Sale sale) async {
    final generator = await _generator();
    List<int> bytes = [];

    bytes += generator.text(
      'VetBiz Pro',
      styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2),
    );
    bytes += generator.text('Sales Receipt', styles: const PosStyles(align: PosAlign.center));
    bytes += generator.hr();

    bytes += generator.text('Client: ${sale.clientName ?? 'Walk-in'}');
    bytes += generator.text('Sold by: ${sale.soldByName}');
    bytes += generator.text('Date: ${sale.timestamp.toLocal().toString().split('.').first}');
    bytes += generator.hr();

    for (final item in sale.items) {
      bytes += generator.text(item.name, styles: const PosStyles(bold: true));
      bytes += generator.row([
        PosColumn(text: '${item.quantity} ${item.unit} x ${item.unitPrice.toStringAsFixed(0)}', width: 8),
        PosColumn(
          text: (item.quantity * item.unitPrice - item.discount).toStringAsFixed(0),
          width: 4,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
    }

    bytes += generator.hr();
    bytes += generator.row([
      PosColumn(text: 'Total', width: 6, styles: const PosStyles(bold: true)),
      PosColumn(
        text: 'Tsh ${sale.totalAmount.toStringAsFixed(0)}',
        width: 6,
        styles: const PosStyles(align: PosAlign.right, bold: true),
      ),
    ]);
    bytes += generator.row([
      PosColumn(text: 'Paid', width: 6),
      PosColumn(
        text: 'Tsh ${sale.totalPaid.toStringAsFixed(0)}',
        width: 6,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);

    if (sale.totalPaid < sale.totalAmount) {
      bytes += generator.row([
        PosColumn(text: 'Balance', width: 6, styles: const PosStyles(bold: true)),
        PosColumn(
          text: 'Tsh ${(sale.totalAmount - sale.totalPaid).toStringAsFixed(0)}',
          width: 6,
          styles: const PosStyles(align: PosAlign.right, bold: true),
        ),
      ]);
    }

    bytes += generator.hr();
    bytes += generator.text('Thank you for your business!', styles: const PosStyles(align: PosAlign.center));
    bytes += generator.feed(2);
    bytes += generator.cut();

    return PrintBluetoothThermal.writeBytes(Uint8List.fromList(bytes));
  }

  /// Formats and prints a real service receipt - same layout convention
  /// as printSaleReceipt above, adapted for a Service instead of a Sale.
  Future<bool> printServiceReceipt(Service service) async {
    final generator = await _generator();
    List<int> bytes = [];

    bytes += generator.text(
      'VetBiz Pro',
      styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2),
    );
    bytes += generator.text('Service Receipt', styles: const PosStyles(align: PosAlign.center));
    bytes += generator.hr();

    bytes += generator.text(service.name, styles: const PosStyles(bold: true));
    bytes += generator.text('Client: ${service.clientName ?? 'Walk-in'}');
    bytes += generator.text('Provided by: ${service.providedByName ?? 'N/A'}');
    if (service.serviceDate != null) {
      bytes += generator.text('Date: ${service.serviceDate!.toLocal().toString().split('.').first}');
    }
    bytes += generator.hr();

    for (final item in service.itemsUsed) {
      final name = (item['itemName'] ?? '').toString();
      final price = (item['price'] is num) ? (item['price'] as num).toDouble() : 0.0;
      bytes += generator.row([
        PosColumn(text: name, width: 8),
        PosColumn(
          text: price.toStringAsFixed(0),
          width: 4,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
    }

    bytes += generator.hr();
    bytes += generator.row([
      PosColumn(text: 'Total', width: 6, styles: const PosStyles(bold: true)),
      PosColumn(
        text: 'Tsh ${service.totalAmount.toStringAsFixed(0)}',
        width: 6,
        styles: const PosStyles(align: PosAlign.right, bold: true),
      ),
    ]);
    bytes += generator.row([
      PosColumn(text: 'Paid', width: 6),
      PosColumn(
        text: 'Tsh ${service.totalPaid.toStringAsFixed(0)}',
        width: 6,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);

    if (service.totalPaid < service.totalAmount) {
      bytes += generator.row([
        PosColumn(text: 'Balance', width: 6, styles: const PosStyles(bold: true)),
        PosColumn(
          text: 'Tsh ${(service.totalAmount - service.totalPaid).toStringAsFixed(0)}',
          width: 6,
          styles: const PosStyles(align: PosAlign.right, bold: true),
        ),
      ]);
    }

    bytes += generator.hr();
    bytes += generator.text('Thank you for your business!', styles: const PosStyles(align: PosAlign.center));
    bytes += generator.feed(2);
    bytes += generator.cut();

    return PrintBluetoothThermal.writeBytes(Uint8List.fromList(bytes));
  }
}
