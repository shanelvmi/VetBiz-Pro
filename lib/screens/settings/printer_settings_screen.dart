import 'package:flutter/material.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../../services/receipt_printer_service.dart';

class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  final Color primaryColor = const Color(0xFF2F5D62);
  final Color warmAmber = const Color(0xFFFFB200);
  final Color backgroundColor = const Color(0xFFFDFDF9);

  final ReceiptPrinterService _printerService = ReceiptPrinterService();

  List<BluetoothInfo> _pairedDevices = [];
  Map<String, String>? _lastPrinter;
  bool _isConnected = false;
  bool _isLoadingDevices = false;
  bool _isConnecting = false;
  bool _isTestPrinting = false;
  String _paperSize = '58';
  bool _autoPrint = false;

  // If a real Bluetooth call fails outright (e.g. this platform has no
  // Bluetooth support at all - which is the case running in Chrome right
  // now), this holds a plain-language explanation instead of crashing
  // the screen or pretending everything's fine.
  String? _platformError;

  @override
  void initState() {
    super.initState();
    _loadInitialState();
  }

  Future<void> _loadInitialState() async {
    final lastPrinter = await _printerService.getLastPrinter();
    final paperSize = await _printerService.getPaperSize();
    final autoPrint = await _printerService.getAutoPrint();

    if (mounted) {
      setState(() {
        _lastPrinter = lastPrinter;
        _paperSize = paperSize;
        _autoPrint = autoPrint;
      });
    }

    await _checkConnection();
    await _refreshPairedDevices();
  }

  Future<void> _checkConnection() async {
    try {
      final connected = await _printerService.isConnected;
      if (mounted) setState(() => _isConnected = connected);
    } catch (e) {
      if (mounted) {
        setState(() => _platformError =
            'Bluetooth printing isn\'t available on this platform. This screen needs a real Android or iOS build with Bluetooth hardware - it can\'t connect to a printer from a web browser.');
      }
    }
  }

  Future<void> _refreshPairedDevices() async {
    setState(() {
      _isLoadingDevices = true;
      _platformError = null;
    });

    try {
      final devices = await _printerService.getPairedDevices();
      if (mounted) {
        setState(() {
          _pairedDevices = devices;
          _isLoadingDevices = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingDevices = false;
          _platformError =
              'Bluetooth printing isn\'t available on this platform. This screen needs a real Android or iOS build with Bluetooth hardware - it can\'t list paired devices from a web browser.';
        });
      }
    }
  }

  Future<void> _connectTo(BluetoothInfo device) async {
    setState(() => _isConnecting = true);

    try {
      final success = await _printerService.connect(device.macAdress);

      if (success) {
        await _printerService.saveLastPrinter(mac: device.macAdress, name: device.name);
        if (!mounted) return;
        setState(() {
          _isConnected = true;
          _lastPrinter = {'mac': device.macAdress, 'name': device.name};
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connected to ${device.name}'), backgroundColor: Colors.green),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not connect to ${device.name}'), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connection failed: $e'), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  Future<void> _disconnect() async {
    try {
      await _printerService.disconnect();
      if (!mounted) return;
      setState(() => _isConnected = false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Disconnect failed: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _forgetPrinter() async {
    await _printerService.clearSavedPrinter();
    if (mounted) setState(() => _lastPrinter = null);
  }

  Future<void> _testPrint() async {
    setState(() => _isTestPrinting = true);
    try {
      final success = await _printerService.printTestPage();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Test page sent to printer' : 'Printer did not accept the test page'),
          backgroundColor: success ? Colors.green : Colors.redAccent,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Test print failed: $e'), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _isTestPrinting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Printer & Receipt Settings'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_platformError != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    border: Border.all(color: Colors.orange),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline, color: Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_platformError!, style: const TextStyle(fontSize: 13)),
                      ),
                    ],
                  ),
                ),

              if (_lastPrinter != null) ...[
                Card(
                  elevation: 2,
                  child: ListTile(
                    leading: Icon(
                      _isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                      color: _isConnected ? Colors.green : Colors.grey,
                    ),
                    title: Text(_lastPrinter!['name'] ?? 'Saved printer'),
                    subtitle: Text(_isConnected ? 'Connected' : 'Not connected'),
                    trailing: Wrap(
                      spacing: 4,
                      children: [
                        if (_isConnected)
                          TextButton(onPressed: _disconnect, child: const Text('Disconnect')),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          tooltip: 'Forget this printer',
                          onPressed: _forgetPrinter,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Paired Devices', style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor)),
                  TextButton.icon(
                    onPressed: _isLoadingDevices ? null : _refreshPairedDevices,
                    icon: _isLoadingDevices
                        ? SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor),
                          )
                        : const Icon(Icons.refresh, size: 18),
                    label: const Text('Refresh'),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Pair your printer in your device\'s Bluetooth settings first - this list only shows devices already paired there.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ),

              if (_pairedDevices.isEmpty && _platformError == null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text('No paired devices found.', style: TextStyle(color: Colors.grey[600])),
                )
              else
                ..._pairedDevices.map((device) {
                  final isThisConnected = _isConnected && _lastPrinter?['mac'] == device.macAdress;
                  return Card(
                    elevation: 1,
                    child: ListTile(
                      leading: Icon(
                        isThisConnected ? Icons.bluetooth_connected : Icons.print_outlined,
                        color: isThisConnected ? Colors.green : primaryColor,
                      ),
                      title: Text(device.name),
                      subtitle: Text(device.macAdress),
                      trailing: _isConnecting
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : (isThisConnected
                              ? const Icon(Icons.check_circle, color: Colors.green)
                              : TextButton(
                                  onPressed: () => _connectTo(device),
                                  child: const Text('Connect'),
                                )),
                    ),
                  );
                }),

              const SizedBox(height: 20),
              Text('Print Options', style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor)),
              const SizedBox(height: 8),
              Card(
                elevation: 2,
                child: Column(
                  children: [
                    ListTile(
                      title: const Text('Paper Size'),
                      trailing: DropdownButton<String>(
                        value: _paperSize,
                        items: const [
                          DropdownMenuItem(value: '58', child: Text('58mm')),
                          DropdownMenuItem(value: '80', child: Text('80mm')),
                        ],
                        onChanged: (value) async {
                          if (value == null) return;
                          await _printerService.setPaperSize(value);
                          if (mounted) setState(() => _paperSize = value);
                        },
                      ),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      title: const Text('Auto-print receipt after each sale'),
                      value: _autoPrint,
                      activeColor: primaryColor,
                      onChanged: (value) async {
                        await _printerService.setAutoPrint(value);
                        if (mounted) setState(() => _autoPrint = value);
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: (_isConnected && !_isTestPrinting) ? _testPrint : null,
                  icon: _isTestPrinting
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.print),
                  label: Text(_isTestPrinting ? 'Sending...' : 'Send Test Print'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              if (!_isConnected)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Connect a printer above before testing.',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
