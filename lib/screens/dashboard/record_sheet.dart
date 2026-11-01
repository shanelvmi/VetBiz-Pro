import 'package:flutter/material.dart';

import '../../models/client.dart';
import '../../utils/subscription_guard.dart';

/// The locked-facility guard's shape (navigateOrShowLockedDialog).
typedef RecordGuard = Future<void> Function(
  BuildContext context,
  Widget destination, {
  Future<void> Function()? onNavigate,
});

/// What each row of the "+" sheet does. [RecordSheetActions.real] opens the
/// app's existing forms; tests pass stand-ins.
class RecordSheetActions {
  final Future<void> Function(BuildContext context) recordSale;
  final Future<void> Function(BuildContext context) recordVisit;
  final Future<void> Function(BuildContext context, List<Client> debtors) recordPayment;
  final Future<void> Function(BuildContext context) addClient;

  /// Every client who owes money now (fetchAllDebtorClients).
  final Future<List<Client>> Function(BuildContext context) fetchDebtors;

  const RecordSheetActions({
    required this.recordSale,
    required this.recordVisit,
    required this.recordPayment,
    required this.addClient,
    required this.fetchDebtors,
  });

  static RecordSheetActions get real => throw UnimplementedError();
}

/// PH3 (4): the "+" sheet (phone_shell.md D1 and section 3), opened from
/// every tab: Record Sale, Record Visit, Record Payment, Add Client, each
/// through the locked-facility guard so a locked facility stays read-only for
/// all four. [onDone] runs after a form closes.
Future<void> showRecordSheet(
  BuildContext context, {
  RecordSheetActions? actions,
  RecordGuard guard = navigateOrShowLockedDialog,
  VoidCallback? onDone,
}) {
  throw UnimplementedError();
}
