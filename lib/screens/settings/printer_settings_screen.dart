import 'package:flutter/material.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../../services/receipt_printer_service.dart';
import '../../theme/app_text.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_dimens.dart';
import '../../theme/theme_context.dart';
import '../../ui/feedback/app_feedback.dart';

class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {

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
            L10n.current.printer_unavailableConnect);
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
              L10n.current.printer_unavailableList;
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
        AppFeedback.success(L10n.current.printer_connected(device.name));
      } else {
        AppFeedback.error(L10n.current.printer_connectFailedNamed(device.name));
      }
    } catch (e, st) {
      AppFeedback.error(L10n.current.printer_connectFailed, error: e, stackTrace: st);
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  Future<void> _disconnect() async {
    try {
      await _printerService.disconnect();
      if (!mounted) return;
      setState(() => _isConnected = false);
    } catch (e, st) {
      AppFeedback.error(L10n.current.printer_disconnectFailed, error: e, stackTrace: st);
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
      if (success) {
        AppFeedback.success(L10n.current.printer_testSent);
      } else {
        AppFeedback.error(L10n.current.printer_testFailed, detail: L10n.current.common_printFailedDetail);
      }
    } catch (e, st) {
      AppFeedback.error(L10n.current.printer_testFailed, error: e, stackTrace: st);
    } finally {
      if (mounted) setState(() => _isTestPrinting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text(context.l10n.printer_title),
        backgroundColor: context.colors.primary,
        foregroundColor: context.colors.onPrimary,
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.s16),
            children: [
              if (_platformError != null)
                Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.s16),
                  padding: const EdgeInsets.all(AppSpacing.s12),
                  decoration: BoxDecoration(
                    color: context.colors.warning.withValues(alpha: AppAlpha.a10),
                    border: Border.all(color: context.colors.warning),
                    borderRadius: BorderRadius.circular(AppRadius.r8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, color: context.colors.warning),
                      const SizedBox(width: AppSpacing.s8),
                      Expanded(
                        child: Text(_platformError!, style: const TextStyle(fontSize: AppFontSize.f13)),
                      ),
                    ],
                  ),
                ),

              if (_lastPrinter != null) ...[
                Card(
                  elevation: AppElevation.e2,
                  child: ListTile(
                    leading: Icon(
                      _isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                      color: _isConnected ? context.colors.success : context.colors.textHint,
                    ),
                    title: Text(_lastPrinter!['name'] ?? context.l10n.printer_savedPrinter),
                    subtitle: Text(_isConnected ? context.l10n.printer_statusConnected : context.l10n.printer_statusNotConnected),
                    trailing: Wrap(
                      spacing: AppSpacing.s4,
                      children: [
                        if (_isConnected)
                          TextButton(onPressed: _disconnect, child: Text(context.l10n.printer_disconnect)),
                        IconButton(
                          icon: const Icon(Icons.close, size: AppIconSize.i18),
                          tooltip: context.l10n.printer_forget,
                          onPressed: _forgetPrinter,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.s16),
              ],

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(context.l10n.printer_paired, style: TextStyle(fontWeight: AppFontWeight.bold, color: context.colors.primary)),
                  TextButton.icon(
                    onPressed: _isLoadingDevices ? null : _refreshPairedDevices,
                    icon: _isLoadingDevices
                        ? SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: context.colors.primary),
                          )
                        : const Icon(Icons.refresh, size: AppIconSize.i18),
                    label: Text(context.l10n.common_refresh),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.s8),
                child: Text(
                  context.l10n.printer_pairHint,
                  style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textMuted),
                ),
              ),

              if (_pairedDevices.isEmpty && _platformError == null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.s12),
                  child: Text(context.l10n.printer_noPaired, style: TextStyle(color: context.colors.textMuted)),
                )
              else
                ..._pairedDevices.map((device) {
                  final isThisConnected = _isConnected && _lastPrinter?['mac'] == device.macAdress;
                  return Card(
                    elevation: AppElevation.e1,
                    child: ListTile(
                      leading: Icon(
                        isThisConnected ? Icons.bluetooth_connected : Icons.print_outlined,
                        color: isThisConnected ? context.colors.success : context.colors.primary,
                      ),
                      title: Text(device.name),
                      subtitle: Text(device.macAdress),
                      trailing: _isConnecting
                          ? const SizedBox(width: AppSpacing.s18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : (isThisConnected
                              ? Icon(Icons.check_circle, color: context.colors.success)
                              : TextButton(
                                  onPressed: () => _connectTo(device),
                                  child: Text(context.l10n.printer_connect),
                                )),
                    ),
                  );
                }),

              const SizedBox(height: AppSpacing.s20),
              Text(context.l10n.printer_printOptions, style: TextStyle(fontWeight: AppFontWeight.bold, color: context.colors.primary)),
              const SizedBox(height: AppSpacing.s8),
              Card(
                elevation: AppElevation.e2,
                child: Column(
                  children: [
                    ListTile(
                      title: Text(context.l10n.printer_paperSize),
                      trailing: DropdownButton<String>(
                        value: _paperSize,
                        items: [
                          DropdownMenuItem(value: '58', child: Text(context.l10n.printer_paperWidth('58'))),
                          DropdownMenuItem(value: '80', child: Text(context.l10n.printer_paperWidth('80'))),
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
                      title: Text(context.l10n.printer_autoPrint),
                      value: _autoPrint,
                      activeThumbColor: context.colors.primary,
                      onChanged: (value) async {
                        await _printerService.setAutoPrint(value);
                        if (mounted) setState(() => _autoPrint = value);
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.s20),
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: (_isConnected && !_isTestPrinting) ? _testPrint : null,
                  icon: _isTestPrinting
                      ? SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: context.colors.onPrimary),
                        )
                      : const Icon(Icons.print),
                  label: Text(_isTestPrinting ? context.l10n.printer_sending : context.l10n.printer_sendTest),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.colors.primary,
                    foregroundColor: context.colors.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.r12)),
                  ),
                ),
              ),
              if (!_isConnected)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.s8),
                  child: Text(
                    context.l10n.printer_connectFirst,
                    style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textMuted),
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
