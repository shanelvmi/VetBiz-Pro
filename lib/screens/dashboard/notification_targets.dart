import 'package:flutter/material.dart';

import '../../models/notification_model.dart';
import '../../navigation/app_destinations.dart';
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

/// LAY6a: the shell place a notification's target is, when it has one (the
/// wide shell opens it there, that place highlighted). Only the places that
/// live in the shell; the others open as before.
AppDestination? notificationTargetPlace(FacilityNotification n) {
  if (n.relatedEntityId == null) return null;
  // LAY6b: a payment opens Payments.
  return switch (n.relatedEntityType) {
    'client' => AppDestination.clients,
    'payment' => AppDestination.payments,
    // LAY6d: a service opens Services.
    'service' => AppDestination.services,
    _ => null,
  };
}
