import 'package:flutter/material.dart';

class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  final Color primaryColor = const Color(0xFF2F5D62);
  final Color backgroundColor = const Color(0xFFFDFDF9);

  // Configuration States
  bool _autoPrintReceipts = false;
  String _selectedPaperSize = '58mm'; // Default common thermal size

  // Bluetooth Discovery States
  bool _isScanning = false;
  String? _connectedDeviceAddress;

  // Dummy list to mimic nearby discovered thermal devices
  final List<Map<String, String>> _discoveredPrinters = [
    {'name': 'MTP-II (Thermal Belt Printer)', 'address': '00:11:22:33:44:55'},
    {'name': 'RP80 Ultra POS Printer', 'address': '66:77:88:99:AA:BB'},
  ];

  void _startScan() async {
    setState(() => _isScanning = true);
    // Simulate searching for nearby hardware over the air
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() => _isScanning = false);
  }

  void _testPrint() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Sending diagnostic layout test page to printer...'),
        backgroundColor: primaryColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const double cardElevation = 2.0;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Printer Settings',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
        ),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionTitle('Preferences'),
          const SizedBox(height: 6),
          Card(
            elevation: cardElevation,
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                // Auto-print configuration switch
                SwitchListTile(
                  activeColor: primaryColor,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  secondary: Icon(Icons.print_sharp, color: primaryColor.withOpacity(0.85)),
                  title: const Text(
                    'Auto-Print Receipts',
                    style: TextStyle(color: Colors.black87, fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                  subtitle: const Text('Instantly issue a receipt upon completing a transaction'),
                  value: _autoPrintReceipts,
                  onChanged: (bool value) {
                    setState(() => _autoPrintReceipts = value);
                  },
                ),
                Divider(height: 1, thickness: 0.5, color: Colors.grey.shade200, indent: 56),
                
                // Paper width dropdown configuration
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: Icon(Icons.insert_drive_file_outlined, color: primaryColor.withOpacity(0.85)),
                  title: const Text(
                    'Receipt Paper Width',
                    style: TextStyle(color: Colors.black87, fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                  subtitle: const Text('Select layout column sizing width'),
                  trailing: DropdownButton<String>(
                    value: _selectedPaperSize,
                    underline: const SizedBox(),
                    icon: Icon(Icons.arrow_drop_down, color: primaryColor),
                    items: <String>['58mm', '80mm'].map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      if (newValue != null) {
                        setState(() => _selectedPaperSize = newValue);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          _buildSectionTitle('Hardware Pairing'),
          const SizedBox(height: 6),
          Card(
            elevation: cardElevation,
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Column(
                children: [
                  ListTile(
                    title: const Text(
                      'Nearby Hardware Devices',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black54),
                    ),
                    trailing: _isScanning
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor),
                          )
                        : TextButton.icon(
                            onPressed: _startScan,
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('Scan'),
                            style: TextButton.styleFrom(foregroundColor: primaryColor),
                          ),
                  ),
                  const Divider(height: 1),
                  
                  // Iterating through available local hardware devices
                  ..._discoveredPrinters.map((printer) {
                    final bool isConnected = _connectedDeviceAddress == printer['address'];
                    return ListTile(
                      leading: Icon(
                        Icons.print_rounded,
                        color: isConnected ? Colors.green : Colors.grey.shade400,
                      ),
                      title: Text(
                        printer['name']!,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(printer['address']!, style: const TextStyle(fontSize: 12)),
                      trailing: isConnected
                          ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
                          : OutlinedButton(
                              onPressed: () {
                                setState(() => _connectedDeviceAddress = printer['address']);
                              },
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: primaryColor),
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                              ),
                              child: Text('Connect', style: TextStyle(color: primaryColor, fontSize: 12)),
                            ),
                    );
                  }),
                ],
              ),
            ),
          ),
          
          // Show diagnostic panel only if a printer is paired actively
          if (_connectedDeviceAddress != null) ...[
            const SizedBox(height: 24),
            _buildSectionTitle('Diagnostics'),
            const SizedBox(height: 6),
            Card(
              elevation: cardElevation,
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(Icons.assignment_turned_in_outlined, color: Colors.green),
                title: const Text(
                  'Test Connection Pipeline',
                  style: TextStyle(color: Colors.black87, fontSize: 15, fontWeight: FontWeight.w500),
                ),
                subtitle: const Text('Spool and print a sample layout configuration layout'),
                trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                onTap: _testPrint,
              ),
            ),
          ],
        ],
      ),
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
          color: primaryColor.withOpacity(0.75),
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}