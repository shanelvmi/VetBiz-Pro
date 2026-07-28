import 'package:flutter/material.dart';

class ExportDataScreen extends StatefulWidget {
  const ExportDataScreen({super.key});

  @override
  State<ExportDataScreen> createState() => _ExportDataScreenState();
}

class _ExportDataScreenState extends State<ExportDataScreen> {
  final Color primaryColor = const Color(0xFF2F5D62);
  final Color backgroundColor = const Color(0xFFFDFDF9);

  // Filter States
  String _selectedDataType = 'Sales & Transactions';
  String _selectedFormat = 'CSV (Spreadsheet)';
  DateTimeRange? _selectedDateRange;

  bool _isExporting = false;

  void _triggerExportPipeline() async {
    setState(() => _isExporting = true);

    try {
      // TODO: Connect to your Provider models or local database streams here
      // Pass _selectedDataType, _selectedFormat, and _selectedDateRange parameters
      await Future.delayed(const Duration(seconds: 2)); // UX Mock Delay

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully exported $_selectedDataType!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Export pipeline encountered an error.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      setState(() => _isExporting = false);
    }
  }

  Future<void> _pickDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      currentDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: primaryColor,
              onPrimary: Colors.white,
              surface: backgroundColor,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDateRange = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    const double cardElevation = 2.0;

    String dateRangeText = _selectedDateRange == null
        ? 'All Records (No Filters Applied)'
        : '${_selectedDateRange!.start.toString().split(' ')[0]}  to  ${_selectedDateRange!.end.toString().split(' ')[0]}';

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Export Center',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
        ),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionTitle('1. Select Dataset Category'),
          const SizedBox(height: 6),
          Card(
            elevation: cardElevation,
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                _buildRadioTile('Sales & Transactions', 'Invoices, revenues, and receipt logging histories'),
                Divider(height: 1, color: Colors.grey.shade200, indent: 56),
                _buildRadioTile('Product Inventory Catalog', 'Stock ledger levels, purchase costs, and SKU lists'),
                Divider(height: 1, color: Colors.grey.shade200, indent: 56),
                _buildRadioTile('Client Ledger & Directory', 'Customer tracking portfolios and outstanding balances'),
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
              title: const Text(
                'Date Selection Scope',
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
              ),
              subtitle: Text(dateRangeText),
              trailing: TextButton(
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
            child: Column(
              children: [
                _buildFormatTile('CSV (Spreadsheet)', Icons.table_chart_outlined),
                Divider(height: 1, color: Colors.grey.shade200, indent: 56),
                _buildFormatTile('PDF Document Report', Icons.picture_as_pdf_outlined),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Core Execution Action Button
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
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Text(
                      'Generate & Export Data',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
            ),
          ),
        ],
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

  Widget _buildFormatTile(String format, IconData icon) {
    return RadioListTile<String>(
      secondary: Icon(icon, color: primaryColor.withOpacity(0.85)),
      title: Text(format, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
      value: format,
      groupValue: _selectedFormat,
      activeColor: primaryColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      onChanged: (value) {
        if (value != null) setState(() => _selectedFormat = value);
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
          color: primaryColor.withOpacity(0.75),
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}