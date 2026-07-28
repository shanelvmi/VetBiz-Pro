import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../models/client.dart';
import '../../models/sale.dart';
import '../../models/service.dart';
import '../../providers/client_provider.dart';
import '../../providers/service_provider.dart';
import '../../providers/facility_provider.dart';
import '../../services/auth_service.dart';

class AddPaymentScreen extends StatefulWidget {
  final Client? preselectedClient;
  final String? debtDocId;
  final double? amountOwed;
  final String? facilityId;

  const AddPaymentScreen({
    super.key,
    this.preselectedClient,
    this.debtDocId,
    this.amountOwed,
    this.facilityId,
  });

  @override
  State<AddPaymentScreen> createState() => _AddPaymentScreenState();
}

class _AddPaymentScreenState extends State<AddPaymentScreen> {
  Client? selectedClient;
  double amount = 0.0;
  final _formKey = GlobalKey<FormState>();
  final NumberFormat currencyFormat = NumberFormat('#,##0', 'en_US');
  final TextEditingController _amountController = TextEditingController();
  final FocusNode _amountFocus = FocusNode();

  final Color primaryDeepGreen = const Color(0xFF2F5D62);
  final Color warmAmber = const Color(0xFFFFB200);
  final Color offWhite = const Color(0xFFFDFDF9);

  @override
  void initState() {
    super.initState();
    selectedClient = widget.preselectedClient;

    if (widget.amountOwed != null) {
      amount = widget.amountOwed!;
      _amountController.text = currencyFormat.format(amount);
    }

    _amountController.addListener(() {
      final text = _amountController.text.replaceAll(',', '');
      final value = double.tryParse(text);
      if (value != null) {
        final newText = currencyFormat.format(value);
        if (_amountController.text != newText) {
          _amountController.value = _amountController.value.copyWith(
            text: newText,
            selection: TextSelection.collapsed(offset: newText.length),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  Future<void> _savePayment() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

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
      'debtId': widget.debtDocId,
      'saleId': sale?.id,
      'serviceId': service?.id,
      'items': items,
      'amount': amount,
      'timestamp': Timestamp.now(),
      'paidById': user.uid,
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

    try {
      await batch.commit();
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final clientProvider = Provider.of<ClientProvider>(context);

    return Scaffold(
      backgroundColor: offWhite,
      appBar: AppBar(
        backgroundColor: primaryDeepGreen,
        title: const Text('Add Payment', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Autocomplete<Client>(
                displayStringForOption: (c) => c.name,
                initialValue:
                    TextEditingValue(text: selectedClient?.name ?? ''),
                optionsBuilder: (TextEditingValue val) {
                  if (widget.preselectedClient != null) return const Iterable<Client>.empty();
                  return clientProvider.clients.where(
                      (c) => c.name.toLowerCase().contains(val.text.toLowerCase()));
                },
                onSelected: (c) => selectedClient = c,
                fieldViewBuilder: (context, controller, focusNode, onSubmit) {
                  return TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    enabled: widget.preselectedClient == null,
                    cursorColor: primaryDeepGreen,
                    decoration: const InputDecoration(
                      labelText: 'Select Client',
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (val) {
                      if (selectedClient == null) return 'Please select a client';
                      return null;
                    },
                  );
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _amountController,
                focusNode: _amountFocus,
                keyboardType: const TextInputType.numberWithOptions(decimal: false),
                cursorColor: primaryDeepGreen,
                decoration: const InputDecoration(
                  labelText: 'Payment Amount',
                  prefixText: 'Tsh ',
                  prefixIcon: Icon(Icons.attach_money),
                ),
                validator: (val) {
                  final parsed = double.tryParse(val?.replaceAll(',', '') ?? '');
                  if (parsed == null || parsed <= 0) return 'Enter a valid amount';
                  if ((widget.amountOwed ?? double.infinity) < parsed) {
                    return 'Cannot pay more than owed';
                  }
                  return null;
                },
                onSaved: (val) => amount = double.parse(val!.replaceAll(',', '')),
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
                  onPressed: _savePayment,
                  child: const Text(
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
