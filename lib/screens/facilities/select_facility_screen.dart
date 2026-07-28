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


class AppColors {
  static const deepGreen = Color(0xFF2F5D62);
  static const warmAmber = Color(0xFFFFB200);
  static const offWhite = Color(0xFFFDFDF9);
}

class SelectFacilityScreen extends StatefulWidget {
  const SelectFacilityScreen({super.key});

  @override
  State<SelectFacilityScreen> createState() => _SelectFacilityScreenState();
}

class _SelectFacilityScreenState extends State<SelectFacilityScreen> {
  List<Map<String, dynamic>> facilities = [];
  String? selectedFacilityId;
  bool isLoading = true;
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
    setState(() => isLoading = true);

    try {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      final argFacilities = (args?['facilities'] as List?)?.cast<Map<String, dynamic>>();
      role = args?['role'] as String?;

      if (argFacilities != null && argFacilities.isNotEmpty) {
        facilities = argFacilities;
      } else {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
          role = userDoc.data()?['role'] ?? role;

          facilities = (userDoc.data()?['facilities'] as List<dynamic>?)
                  ?.map((f) => {
                        'facilityId': f['facilityId'],
                        'facilityName': f['name'],
                        'facilityType': f['type'],
                      })
                  .toList() ??
              [];
        }
      }

      // Auto-navigate if only one facility
      if (facilities.length == 1) {
        _selectFacility(facilities.first);
      }
    } catch (e) {
      debugPrint("Error loading facilities: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _selectFacility(Map<String, dynamic> facility) {
    final facilityProvider = context.read<FacilityProvider>();
    final productProvider = context.read<ProductProvider>();
    final saleProvider = context.read<SaleProvider>();
    final clientProvider = context.read<ClientProvider>();
    final serviceProvider = context.read<ServiceProvider>();
    final transactionProvider = context.read<TransactionProvider>();
    final debtProvider = context.read<DebtProvider>();

    // Clear all previous data
    productProvider.clear();
    saleProvider.clear();
    clientProvider.clear(); 
    serviceProvider.clear();
    transactionProvider.clear();
    debtProvider.clear();

    // Set selected facility
    facilityProvider.setFacility(
      id: facility['facilityId'],
      name: facility['facilityName'],
      type: facility['facilityType'],
    );

    // Listen to real-time updates
    productProvider.fetchProducts(facility['facilityId']); // fetch products immediately
    saleProvider.init(facility['facilityId']); // real-time sales
    clientProvider.listenToClients(facility['facilityId']); // real-time clients
    serviceProvider.listenToServices(facility['facilityId']); // needed
    transactionProvider.listenToTransactions(facility['facilityId']);
    debtProvider.listenToDebts(facility['facilityId']);


    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushReplacementNamed(
        context,
        '/dashboard',
        arguments: {
          'role': role,
          'facilityId': facility['facilityId'],
          'facilityName': facility['facilityName'],
          'facilityType': facility['facilityType'],
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
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        title: const Text('Select Facility'),
        centerTitle: true,
        backgroundColor: AppColors.deepGreen,
        foregroundColor: AppColors.offWhite,
      ),
      body: facilities.isEmpty
          ? const Center(child: Text('No facilities found.'))
          : ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: facilities.length,
              itemBuilder: (context, index) {
                final facility = facilities[index];
                final id = facility['facilityId'];
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
              backgroundColor: AppColors.deepGreen,
              foregroundColor: AppColors.offWhite,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Proceed'),
              onPressed: () {
                final facility = facilities.firstWhere(
                  (f) => f['facilityId'] == selectedFacilityId,
                  orElse: () => {},
                );
                if (facility.isEmpty) return;
                _selectFacility(facility);
              },
            ),
    );
  }
}

class _HoverCard extends StatefulWidget {
  final Map<String, dynamic> facility;
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
    final name = widget.facility['facilityName'] ?? 'Unnamed';
    final type = widget.facility['facilityType'] ?? '';
    final icon = _getFacilityIcon(type);

    return MouseRegion(
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? AppColors.warmAmber.withValues(alpha: 0.3)
                : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.isSelected
                  ? AppColors.deepGreen
                  : Colors.transparent,
              width: 2,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.deepGreen),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.deepGreen,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      type,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.deepGreen.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedOpacity(
                opacity: isHovered ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                child: Padding(
                  padding: const EdgeInsets.only(left: 12.0),
                  child: Text(
                    widget.isSelected ? 'Selected' : 'Click to select',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.deepGreen.withValues(alpha: 0.8),
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
