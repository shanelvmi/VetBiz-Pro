import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/facility_provider.dart';
import '../providers/product_provider.dart';
import '../providers/sale_provider.dart';
import '../providers/client_provider.dart';
import '../providers/service_provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/debt_provider.dart';
import '../providers/subscription_provider.dart';
import '../providers/user_role_provider.dart';
import 'provider_reset.dart';
import 'navigator_key.dart';

/// The one place that turns "here's a facility" into "you're now looking
/// at its Dashboard" - resets every provider, wires up every real-time
/// listener for the chosen facility, and navigates. Used directly from
/// the main login path (main.dart) for the common single-facility case,
/// and from the facility picker for the rarer multi-facility case - both
/// go through this exact same logic, so there's only one place that can
/// ever get this sequence wrong, not two slightly-different copies of it.
Future<void> activateFacilityAndGoToDashboard({
  required BuildContext context,
  required Map<String, dynamic> facility,
  String? role,
}) async {
  if (!context.mounted) return;

  final facilityProvider = context.read<FacilityProvider>();
  final productProvider = context.read<ProductProvider>();
  final saleProvider = context.read<SaleProvider>();
  final clientProvider = context.read<ClientProvider>();
  final serviceProvider = context.read<ServiceProvider>();
  final transactionProvider = context.read<TransactionProvider>();
  final debtProvider = context.read<DebtProvider>();
  final subscriptionProvider = context.read<SubscriptionProvider>();

  // Clear all previous data first - one shared, complete list (see
  // provider_reset.dart), so this can never miss resetting something
  // like UserRoleProvider or SubscriptionProvider.
  resetAllUserProviders(context);

  facilityProvider.setFacility(
    id: facility['facilityId'],
    name: facility['facilityName'],
    type: facility['facilityType'],
  );
  facilityProvider.listenToFacility(facility['facilityId']);

  productProvider.fetchProducts(facility['facilityId']);
  saleProvider.init(facility['facilityId']);
  clientProvider.listenToClients(facility['facilityId']);
  serviceProvider.listenToServices(facility['facilityId']);
  transactionProvider.listenToTransactions(facility['facilityId']);
  debtProvider.listenToDebts(facility['facilityId']);
  subscriptionProvider.listenToFacility(facility['facilityId']);
  context.read<UserRoleProvider>().listenToCurrentUser();

  // Pushes rather than replaces - AppEntryPoint must stay alive
  // underneath Dashboard in the navigation stack, not be destroyed by
  // this. On the very first navigation after sign-in, AppEntryPoint is
  // still the only route in the stack - pushReplacementNamed here would
  // replace AppEntryPoint itself (since it's "the current route"),
  // permanently removing the one thing that reacts to auth state for
  // the rest of the session. force_logout.dart's popUntil((route) =>
  // route.isFirst) depends on AppEntryPoint genuinely being that first
  // route - pushing (not replacing) is what keeps that true.
  final navState = navigatorKey.currentState;
  if (navState != null) {
    navState.pushNamed(
      '/dashboard',
      arguments: {
        'role': role,
        'facilityId': facility['facilityId'],
        'facilityName': facility['facilityName'],
        'facilityType': facility['facilityType'],
      },
    );
  }
}
