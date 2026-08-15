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

/// Resets every provider that holds data tied to a specific signed-in
/// user or facility - call this on logout AND on facility switch, before
/// signing out / picking a new facility. There were previously three
/// separate places doing this (logout on Dashboard, "switch facility" on
/// the Facility screen, and facility selection itself), each clearing a
/// different, incomplete subset - notably, none of them reset the user's
/// role or subscription status, so switching from an Admin account to an
/// Assistant account (or vice versa) left the whole app still behaving
/// like the previous user until something else happened to refresh it.
/// One shared, complete list now, used everywhere this needs to happen.
void resetAllUserProviders(BuildContext context) {
  Provider.of<FacilityProvider>(context, listen: false).clearFacility();
  Provider.of<ProductProvider>(context, listen: false).clear();
  Provider.of<SaleProvider>(context, listen: false).clear();
  Provider.of<ClientProvider>(context, listen: false).clear();
  Provider.of<ServiceProvider>(context, listen: false).clear();
  Provider.of<TransactionProvider>(context, listen: false).clear();
  Provider.of<DebtProvider>(context, listen: false).clear();
  Provider.of<SubscriptionProvider>(context, listen: false).clear();
  Provider.of<UserRoleProvider>(context, listen: false).clear();
}
