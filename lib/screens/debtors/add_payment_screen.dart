import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../models/client.dart';
import '../../models/sale.dart';
import '../../models/service.dart';
import '../../providers/facility_provider.dart';
import '../../providers/service_provider.dart';
import '../../services/auth_service.dart';
import '../../utils/activity_logger.dart';
import '../../utils/thousands_input_formatter.dart';
import '../../widgets/payment_method_selector.dart';

class AddPaymentScreen extends StatefulWidget {
  final Client? preselectedClient;
  final String? debtDocId;
  final double? amountOwed;
  final String? facilityId;
  final bool isModal;

  const AddPaymentScreen({
    super.key,
    this.preselectedClient,
    this.debtDocId,
    this.amountOwed,
    this.facilityId,
    this.isModal = false,
  });

  @override
  State<AddPaymentScreen> createState() => _AddPaymentScreenState();
}

class _AddPaymentScreenState extends State<AddPaymentScreen> {
  bool _isSaving = false;
  Client? selectedClient;
  double amount = 0.0;
  String? paymentMethod;
  final _formKey = GlobalKey<FormState>();
  final NumberFormat currencyFormat = NumberFormat('#,##0', 'en_US');

  static const Color primaryDeepGreen = Color(0xFF2F5D62);
  static const Color warmAmber = Color(0xFFFFB200);

  @override
  void initState() {
    super.initState();
    selectedClient = widget.preselectedClient;
  }

  Future<void> _savePayment() async {
    if (_isSaving) return; // guards against a double-tap firing two saves at once
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    if (paymentMethod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select how this payment was made')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final facilityProvider =
          Provider.of<FacilityProvider>(context, listen: false);
      final authService = Provider.of<AuthService>(context, listen: false);
      final serviceProvider =
          Provider.of<ServiceProvider>(context, listen: false);

      final facilityId = widget.facilityId ?? facilityProvider.selectedFacility?['id'];
      if (facilityId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No facility selected')),
        );
        return;
      }

      final user = authService.getCurrentUser();
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not authenticated')),
        );
        return;
      }

      if (selectedClient == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select a client')),
        );
        return;
      }

      final debtRef = widget.debtDocId != null
          ? FirebaseFirestore.instance
              .collection('facilities')
              .doc(facilityId)
              .collection('debts')
              .doc(widget.debtDocId)
          : null;

      String? saleId;
      String? serviceId;
      Sale? sale;
      Service? service;

      if (debtRef != null) {
        final debtSnap = await debtRef.get();
        if (debtSnap.exists) {
          final data = debtSnap.data()!;
          saleId = data['saleId'] as String?;
          serviceId = data['serviceId'] as String?;
        }
      }

      if (saleId != null) {
        final saleSnap = await FirebaseFirestore.instance
            .collection('facilities')
            .doc(facilityId)
            .collection('sales')
            .doc(saleId)
            .get();
        if (saleSnap.exists && saleSnap.data() != null) {
          sale = Sale.fromFirestore(saleSnap.data()!, saleSnap.id);
        }
      }

      if (serviceId != null) {
        final serviceSnap = await FirebaseFirestore.instance
            .collection('facilities')
            .doc(facilityId)
            .collection('services')
            .doc(serviceId)
            .get();
        if (serviceSnap.exists && serviceSnap.data() != null) {
          service = Service.fromFirestore(serviceSnap.data()!, serviceSnap.id);
        }
      }

      final clientRef = FirebaseFirestore.instance
          .collection('facilities')
          .doc(facilityId)
          .collection('clients')
          .doc(selectedClient!.id);

      final batch = FirebaseFirestore.instance.batch();

      final paymentRef = FirebaseFirestore.instance
          .collection('facilities')
          .doc(facilityId)
          .collection('payments')
          .doc();

      final List<Map<String, dynamic>> items = [];
      if (sale != null) {
        items.addAll(sale.items.map((i) => {
              ...i.toMap(),
              'serviceName': service?.name ?? 'N/A',
              'category': service?.category ?? 'N/A',
            }));
      } else if (service != null) {
        items.add({
          'serviceName': service.name,
          'category': service.category,
          'totalAmount': service.totalAmount,
          'totalPaid': service.totalPaid,
        });
      }

      batch.set(paymentRef, {
        'clientId': selectedClient!.id,
        // Stored directly on the payment document too - previously
        // missing here, which meant this entry could only ever be
        // matched by clientId, not shown or searched by name. That
        // specifically caused a real bug: the Payments screen, when
        // opened from a debtor's card, pre-fills its search box with
        // the client's name, and a payment missing this field would
        // silently fail that text match even though its clientId was
        // correct - so a later repayment could disappear from view
        // entirely while an earlier one (saved before this field was
        // added) still showed.
        'clientName': selectedClient!.name,
        'debtId': widget.debtDocId,
        'saleId': sale?.id,
        'serviceId': service?.id,
        'items': items,
        'amount': amount,
        'timestamp': FieldValue.serverTimestamp(),
        'paidById': user.uid,
        'source': 'debt_repayment',
        'paymentMethod': paymentMethod,
      });

      batch.update(clientRef, {
        'balance': FieldValue.increment(-amount),
      });

      if (debtRef != null) {
        final remaining = (widget.amountOwed ?? 0) - amount;
        if (remaining <= 0) {
          batch.delete(debtRef);
        } else {
          batch.update(debtRef, {'amountOwed': remaining});
        }
      }

      if (sale != null) {
        final updatedSale = sale.applyPayment(amount);
        final saleRef = FirebaseFirestore.instance
            .collection('facilities')
            .doc(facilityId)
            .collection('sales')
            .doc(updatedSale.id);
        batch.update(saleRef, updatedSale.toMap());
      }

      if (service != null) {
        final updatedService = service.copyWith(
          totalPaid: service.totalPaid + amount,
          updatedAt: DateTime.now(),
        );
        final serviceRef = FirebaseFirestore.instance
            .collection('facilities')
            .doc(facilityId)
            .collection('services')
            .doc(updatedService.id);
        batch.update(serviceRef, updatedService.toMap());

        // ✅ Live update totalServiceProfit in ServiceProvider
        serviceProvider.updateLocalService(updatedService);
      }

      await batch.commit();

      final userInfo = await ActivityLogger.getCurrentUserInfo();
      await ActivityLogger.logActivity(
        facilityId: facilityId,
        userId: userInfo['userId']!,
        userName: userInfo['userName'],
        actionType: 'Debtors',
        description: 'Recorded payment of Tsh ${amount.toStringAsFixed(0)} from ${selectedClient!.name}',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Payment of Tsh ${currencyFormat.format(amount)} recorded for ${selectedClient!.name}'),
          backgroundColor: Colors.green,
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save payment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFDF9),
      appBar: AppBar(
        title: const Text('Record Payment'),
        centerTitle: true,
        backgroundColor: primaryDeepGreen,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: !widget.isModal,
        leading: widget.isModal
            ? IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              if (selectedClient != null)
                Text(
                  'Client: ${selectedClient!.name}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              const SizedBox(height: 16),
              if (widget.amountOwed != null)
                Text(
                  'Amount owed: Tsh ${currencyFormat.format(widget.amountOwed)}',
                  style: const TextStyle(fontSize: 14, color: Colors.redAccent),
                ),
              const SizedBox(height: 12),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Payment Amount',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, ThousandsSeparatorInputFormatter()],
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Enter an amount';
                  final parsed = parseThousands(val);
                  if (parsed <= 0) return 'Enter a valid amount';
                  if (widget.amountOwed != null && parsed > widget.amountOwed!) {
                    return 'Cannot pay more than owed';
                  }
                  return null;
                },
                onSaved: (val) => amount = parseThousands(val ?? ''),
              ),
              const SizedBox(height: 20),
              PaymentMethodSelector(
                value: paymentMethod,
                activeColor: primaryDeepGreen,
                onChanged: (method) => setState(() => paymentMethod = method),
              ),
              const SizedBox(height: 30),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: ElevatedButton(
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                      if (states.contains(WidgetState.hovered)) return warmAmber;
                      return primaryDeepGreen;
                    }),
                    minimumSize: WidgetStateProperty.all(const Size.fromHeight(50)),
                  ),
                  onPressed: _isSaving ? null : _savePayment,
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFDFDF9)),
                        )
                      : const Text(
                          'Save Payment',
                          style: TextStyle(color: Color(0xFFFDFDF9), fontSize: 18),
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

/// Shows AddPaymentScreen as a centered dialog on wide/desktop screens,
/// or a full-screen push on narrow ones - same modal-on-desktop pattern
/// as every other Add/Edit screen in the app. Returns the same bool?
/// result AddPaymentScreen itself pops with, so callers can tell
/// whether a payment was actually recorded.
Future<bool?> showAddPaymentScreen(
  BuildContext context, {
  Client? preselectedClient,
  String? debtDocId,
  double? amountOwed,
  String? facilityId,
}) async {
  final isWideScreen = MediaQuery.of(context).size.width >= 900;

  if (!isWideScreen) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddPaymentScreen(
          preselectedClient: preselectedClient,
          debtDocId: debtDocId,
          amountOwed: amountOwed,
          facilityId: facilityId,
        ),
      ),
    );
  }

  return showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Record Payment',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, animation, secondaryAnimation) {
      final screenSize = MediaQuery.of(context).size;
      return Center(
        child: SizedBox(
          width: screenSize.width * 0.8,
          height: screenSize.height * 0.85,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Material(
              child: AddPaymentScreen(
                preselectedClient: preselectedClient,
                debtDocId: debtDocId,
                amountOwed: amountOwed,
                facilityId: facilityId,
                isModal: true,
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero).animate(curved),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1.0).animate(curved),
            child: child,
          ),
        ),
      );
    },
  );
}
