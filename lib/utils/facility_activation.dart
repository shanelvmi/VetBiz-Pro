import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
import '../screens/dashboard/dashboard_screen.dart';

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
  debugPrint('[NAV] activateFacilityAndGoToDashboard starting for facility=${facility['facilityId']} role=$role');
  if (!context.mounted) {
    debugPrint('[NAV] activateFacilityAndGoToDashboard: context not mounted - aborting');
    return;
  }

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
  debugPrint('[NAV] Previous user\'s providers cleared, wiring up facility=${facility['facilityId']}');

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
  if (navState == null) {
    debugPrint('[NAV] activateFacilityAndGoToDashboard: navigatorKey.currentState is null - cannot navigate');
    return;
  }

  // A fixed delay, not a frame callback - addPostFrameCallback ties
  // to the browser's own paint-frame scheduling on web, which can be
  // throttled or simply never fire if nothing visually needs to
  // change, leaving this navigation waiting indefinitely until some
  // external event (like the browser's own back/forward buttons)
  // forces a repaint. A timer-based delay fires regardless of that.
  // 300ms also safely clears AppEntryPoint's own 220ms
  // AnimatedSwitcher transition between its login/deciding states -
  // pushing a new route while that's still mid-flight was a
  // plausible separate source of the same symptom.
  await Future.delayed(const Duration(milliseconds: 300));

  debugPrint('[NAV] Navigating to /dashboard for facility=${facility['facilityId']} role=$role');
  try {
    // pushAndRemoveUntil against a custom route (rather than
    // pushNamedAndRemoveUntil against the static named one) - this is
    // what actually allows a custom transition animation; the plain
    // named route always used Flutter's default page transition
    // regardless of what's passed here. A gentle fade with a subtle
    // scale-up (curved, not linear) reads as a deliberate, polished
    // context switch rather than an abrupt cut - especially relevant
    // here since this operation also removes every route above the
    // first one in the same step, not just pushing on top of what's
    // already there.
    //
    // DashboardScreen doesn't read the arguments the previous version
    // of this call passed (it pulls role/facility state from providers,
    // already wired up above) - dropped here since there's nothing to
    // carry over.
    navState.pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            _DashboardEntryLoader(facilityName: facility['facilityName'] as String? ?? 'your facility'),
        transitionDuration: const Duration(milliseconds: 380),
        reverseTransitionDuration: const Duration(milliseconds: 380),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.96, end: 1.0).animate(curved),
              child: child,
            ),
          );
        },
      ),
      (route) => route.isFirst,
    );
    debugPrint('[NAV] pushAndRemoveUntil(DashboardScreen) call completed');
  } catch (e, st) {
    debugPrint('[NAV] Navigation to /dashboard failed: $e\n$st');
  }
}

/// Shown for a brief, bounded moment right as a facility's Dashboard
/// opens - not an indefinite loading block, just enough of a grace
/// period for the real-time listeners started just above (products,
/// sales, clients, services, transactions, debts) to receive their
/// first snapshot before the real Dashboard is revealed. Without this,
/// a facility that's genuinely full of data could flash misleadingly
/// empty or zero-value sections for a moment, since those providers'
/// lists start empty until their first snapshot arrives - on a slow
/// connection, or for a facility with a lot to load, that gap could be
/// noticeable rather than instant. Proceeds to the real Dashboard
/// regardless once the grace period passes, whether or not every
/// listener has reported back yet - an unusually slow connection should
/// never leave someone stuck here longer than this.
class _DashboardEntryLoader extends StatefulWidget {
  final String facilityName;
  const _DashboardEntryLoader({required this.facilityName});

  @override
  State<_DashboardEntryLoader> createState() => _DashboardEntryLoaderState();
}

class _DashboardEntryLoaderState extends State<_DashboardEntryLoader> {
  static const Color _primaryDeepGreen = Color(0xFF2F5D62);
  static const Color _offWhite = Color(0xFFFDFDF9);

  bool _ready = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      switchInCurve: Curves.easeOut,
      transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
      child: _ready
          ? const DashboardScreen(key: ValueKey('dashboard'))
          : Scaffold(
              key: const ValueKey('loading'),
              backgroundColor: _offWhite,
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: _primaryDeepGreen),
                    const SizedBox(height: 20),
                    Text(
                      'Setting up ${widget.facilityName}...',
                      style: const TextStyle(color: _primaryDeepGreen, fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
