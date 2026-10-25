import 'package:flutter/material.dart';

import '../../models/notification_model.dart';
import '../admin/manage_assistants_screen.dart';
import '../clients/clients_screen.dart';
import '../payments/payments_screen.dart';
import '../products/stock_alerts_screen.dart';
import '../services/services_screen.dart';

/// Where a notification's Open goes (NOTIF-2c): the screen for the kind of
/// record it is about, as the server writes relatedEntityType (stored
/// values: functions/index.js, functions/membership.js). Null when there
/// is nowhere to go.
Widget? notificationTargetScreen(FacilityNotification n) {
  if (n.relatedEntityId == null) return null;
  switch (n.relatedEntityType) {
    case 'product':
      return const StockAlertsScreen();
    case 'payment':
      return const PaymentsScreen();
    case 'service':
      return const ServicesScreen();
    case 'client':
      return const ClientsScreen();
    case 'assistant':
      return const ManageAssistantsScreen();
    default:
      return null;
  }
}
