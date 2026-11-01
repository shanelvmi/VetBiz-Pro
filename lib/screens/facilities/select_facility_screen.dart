import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../providers/facility_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/sale_provider.dart';
import '../../providers/client_provider.dart';
import '../../providers/service_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/debt_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/user_role_provider.dart';
import '../../utils/provider_reset.dart';
import '../../data/collections.dart';
import '../../data/fields.dart';
import '../../models/facility_entry.dart';
import '../../config/app_timeouts.dart';
import '../../theme/app_text.dart';
import '../../theme/app_dimens.dart';
import '../../theme/theme_context.dart';
import '../../theme/app_motion.dart';
import '../../ui/feedback/friendly_error.dart';
import '../../l10n/l10n.dart';


class SelectFacilityScreen extends StatefulWidget {
  const SelectFacilityScreen({super.key});

  @override
  State<SelectFacilityScreen> createState() => _SelectFacilityScreenState();
}

class _SelectFacilityScreenState extends State<SelectFacilityScreen> {
  List<FacilityEntry> facilities = [];
  String? selectedFacilityId;
  bool isLoading = true;
  String? loadError;
  String? role;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _loadFacilities();
    }
  }

  Future<void> _loadFacilities() async {
    setState(() {
      isLoading = true;
      loadError = null;
    });

    try {
      // Read as untyped as they come (FX1): on the web the arguments and each
      // facility can be a Map<dynamic, dynamic>, and the old casts threw.
      final rawArgs = ModalRoute.of(context)?.settings.arguments;
      final args = rawArgs is Map ? rawArgs : null;
      final argFacilities = FacilityEntry.listFrom(args?['facilities']);
      role = FacilityEntry.safeString(args?[Fields.role]);

      if (argFacilities.isNotEmpty) {
        facilities = argFacilities;
      } else {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          final userDoc = await FirebaseFirestore.instance
              .collection(Collections.users)
              .doc(uid)
              .get()
              .timeout(AppTimeouts.facilityLoad);
          role = FacilityEntry.safeString(userDoc.data()?[Fields.role]) ?? role;

          facilities = FacilityEntry.listFrom(userDoc.data()?['facilities']);
        }
      }

      // Auto-navigate if only one facility
      if (facilities.length == 1) {
        _selectFacility(facilities.first);
      }
    } catch (e) {
      debugPrint("Error loading facilities: $e");
      loadError = e is TimeoutException
          ? L10n.current.selectFacility_slowLoad
          : L10n.current.selectFacility_loadFailed(FriendlyError.messageFor(e));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _selectFacility(FacilityEntry facility) {
    final facilityId = facility.id!; // listFrom keeps only entries with an id
    final facilityProvider = context.read<FacilityProvider>();
    final productProvider = context.read<ProductProvider>();
    final saleProvider = context.read<SaleProvider>();
    final clientProvider = context.read<ClientProvider>();
    final serviceProvider = context.read<ServiceProvider>();
    final transactionProvider = context.read<TransactionProvider>();
    final debtProvider = context.read<DebtProvider>();
    final subscriptionProvider = context.read<SubscriptionProvider>();

    // Clear all previous data - one shared, complete list (see
    // provider_reset.dart) instead of a separately-maintained partial
    // one here, so this can never again miss resetting something like
    // UserRoleProvider or SubscriptionProvider.
    resetAllUserProviders(context);

    // Set selected facility
    facilityProvider.setFacility(
      id: facilityId,
      name: facility.name ?? '',
      type: facility.type ?? '',
      typeDetail: facility.typeDetail,
    );

    // Listen to real-time updates
    productProvider.fetchProducts(facilityId); // fetch products immediately
    saleProvider.init(facilityId); // real-time sales
    clientProvider.listenToClients(facilityId); // real-time clients
    serviceProvider.listenToServices(facilityId); // needed
    transactionProvider.listenToTransactions(facilityId);
    debtProvider.listenToDebts(facilityId);
    subscriptionProvider.listenToFacility(facilityId);
    context.read<UserRoleProvider>().listenToCurrentUser();


    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushReplacementNamed(
        context,
        '/dashboard',
        arguments: {
          Fields.role: role,
          ...facility.toMap(),
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text(context.l10n.selectFacility_title),
        centerTitle: true,
        backgroundColor: context.colors.brandSurface,
        foregroundColor: context.colors.onBrandInk,
      ),
      body: loadError != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.s24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, color: context.colors.dangerAccent, size: AppIconSize.i40),
                    const SizedBox(height: AppSpacing.s12),
                    Text(loadError!, textAlign: TextAlign.center),
                    const SizedBox(height: AppSpacing.s16),
                    ElevatedButton(
                      onPressed: _loadFacilities,
                      style: ElevatedButton.styleFrom(backgroundColor: context.colors.primary, foregroundColor: context.colors.onPrimary),
                      child: Text(context.l10n.common_tryAgain),
                    ),
                  ],
                ),
              ),
            )
          : facilities.isEmpty
          ? Center(child: Text(context.l10n.facilities_noneFound))
          : ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.s24),
              itemCount: facilities.length,
              itemBuilder: (context, index) {
                final facility = facilities[index];
                final id = facility.id;
                return _HoverCard(
                  facility: facility,
                  isSelected: id == selectedFacilityId,
                  onTap: () {
                    setState(() {
                      selectedFacilityId = id;
                    });
                  },
                );
              },
            ),
      floatingActionButton: selectedFacilityId == null
          ? null
          : FloatingActionButton.extended(
              backgroundColor: context.colors.primary,
              foregroundColor: context.colors.background,
              icon: const Icon(Icons.arrow_forward),
              label: Text(context.l10n.selectFacility_proceed),
              onPressed: () {
                final facility = facilities.where((f) => f.id == selectedFacilityId).firstOrNull;
                if (facility == null) return;
                _selectFacility(facility);
              },
            ),
    );
  }
}

class _HoverCard extends StatefulWidget {
  final FacilityEntry facility;
  final VoidCallback onTap;
  final bool isSelected;

  const _HoverCard({
    required this.facility,
    required this.onTap,
    required this.isSelected,
  });

  @override
  State<_HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<_HoverCard> {
  bool isHovered = false;

  IconData _getFacilityIcon(String type) {
    switch (type.toLowerCase()) {
      case 'agrovet':
        return Icons.store;
      case 'clinic':
        return Icons.local_hospital;
      case 'lab':
        return Icons.science;
      default:
        return Icons.business;
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.facility.name ?? context.l10n.selectFacility_unnamed;
    final type = widget.facility.type ?? '';
    final icon = _getFacilityIcon(type);

    return MouseRegion(
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppMotion.normal,
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
          padding: const EdgeInsets.all(AppSpacing.s16),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? context.colors.selectedCardFill
                : context.colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.r8),
            border: Border.all(
              color: widget.isSelected
                  ? context.colors.selectableCardInk
                  : Colors.transparent,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: context.colors.shadow.withValues(alpha: AppAlpha.a10),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, color: context.colors.selectableCardInk),
              const SizedBox(width: AppSpacing.s16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: AppFontSize.f16,
                        fontWeight: AppFontWeight.bold,
                        color: context.colors.selectableCardInk,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    Text(
                      context.l10n.facilityTypeDisplay(widget.facility.type, widget.facility.typeDetail),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: AppFontSize.f14,
                        color: context.colors.selectableCardInk.withValues(alpha: AppAlpha.a85),
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedOpacity(
                opacity: isHovered ? 1.0 : 0.0,
                duration: AppMotion.normal,
                curve: Curves.easeInOut,
                child: Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.s12),
                  child: Text(
                    widget.isSelected ? context.l10n.selectFacility_selected : context.l10n.selectFacility_clickToSelect,
                    style: TextStyle(
                      fontSize: AppFontSize.f12,
                      color: context.colors.selectableCardInk.withValues(alpha: AppAlpha.a85),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
