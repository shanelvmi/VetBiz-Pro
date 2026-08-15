import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

import '../../models/client.dart';
import '../../models/product.dart';
import '../../models/sale.dart';
import '../../models/debt.dart';

import '../../providers/client_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/sale_provider.dart';
import '../../providers/facility_provider.dart';
import '../../providers/debt_provider.dart';

import '../../services/auth_service.dart';
import '../clients/add_client_screen.dart';

// --- Custom Formatter ---
class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  final NumberFormat _formatter = NumberFormat('#,##0.##');

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue.copyWith(text: '');
    String cleaned = newValue.text.replaceAll(',', '');
    double? value = double.tryParse(cleaned);
    if (value == null) return oldValue;
    String newText = _formatter.format(value);
    int offset = newText.length - (cleaned.length - newValue.selection.end);
    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: offset.clamp(0, newText.length)),
    );
  }
}

// --- Add Sale Screen ---
class AddSaleScreen extends StatefulWidget {
  const AddSaleScreen({super.key});

  @override
  State<AddSaleScreen> createState() => _AddSaleScreenState();
}

class _AddSaleScreenState extends State<AddSaleScreen> {
  bool _isSaving = false;
  final TextEditingController clientController = TextEditingController();
  bool _showClientSuggestions = false;
  final TextEditingController totalPaidController = TextEditingController();

  Client? selectedClient;
  List<SaleItem> items = [];
  double totalPaid = 0.0;
  bool saleOnCredit = false;

  final Color primaryDeepGreen = const Color(0xFF2F5D62);
  final Color warmAmber = const Color(0xFFFFB200);
  final Color offWhite = const Color(0xFFFDFDF9);
  final Color deepTeal = const Color(0xFF004D40);

  final NumberFormat _thousandsFormat = NumberFormat.decimalPattern('en_US');

  double get totalAmount {
    return items.fold(
      0.0,
      (sum, item) => sum + (item.unitPrice * item.quantity) - item.discount,
    );
  }

  @override
  void initState() {
    super.initState();
    totalPaid = 0.0;
    totalPaidController.text = _thousandsFormat.format(totalPaid);
  }

  @override
  void dispose() {
    clientController.dispose();
    totalPaidController.dispose();
    super.dispose();
  }

  /// --- Add Sale Item Dialog ---
  Future<void> _showAddItemDialog() async {
    final productProvider = Provider.of<ProductProvider>(context, listen: false);

    Product? selectedProduct;
    int quantity = 1;
    double unitPrice = 0.0;
    double discount = 0.0;
    double costPrice = 0.0;

    final TextEditingController productSearchController = TextEditingController();
    final TextEditingController quantityController = TextEditingController(text: '1');
    final TextEditingController unitPriceController = TextEditingController(text: '0');
    final TextEditingController discountController = TextEditingController(text: '0');

    List<String> selectedProductIds = items.map((e) => e.productId).toList();
    List<Product> filteredProducts = productProvider.sellableProducts
    .where((p) => !selectedProductIds.contains(p.id))
    .toList();

    InputDecoration fieldDecoration(String label) => InputDecoration(
          labelText: label,
          filled: true,
          fillColor: deepTeal.withValues(alpha: 0.1),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        );

    final SaleItem? newItem = await showDialog<SaleItem>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, dialogSetState) {
          void updateProfit() {
            // Per-item profit automatically calculated in model
          }

          void filterProducts(String query) {
            final lowerQuery = query.toLowerCase();
            dialogSetState(() {
              filteredProducts = productProvider.sellableProducts
                .where((p) =>
                    !selectedProductIds.contains(p.id) &&
                    p.name.toLowerCase().contains(lowerQuery))
                .toList();
            });
          }

          void formatController(TextEditingController controller, double value) {
            final formatted = _thousandsFormat.format(value);
            controller.value = TextEditingValue(
              text: formatted,
              selection: TextSelection.collapsed(offset: formatted.length),
            );
          }

          return AlertDialog(
            backgroundColor: offWhite,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Add Sale Item'),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: productSearchController,
                      decoration: fieldDecoration('Search Product'),
                      onChanged: filterProducts,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 150,
                      child: filteredProducts.isEmpty
                          ? const Center(child: Text('No products found'))
                          : ListView.builder(
                              itemCount: filteredProducts.length,
                              itemBuilder: (context, index) {
                                final prod = filteredProducts[index];
                                final selected = selectedProduct?.id == prod.id;
                                return Container(
                                  decoration: BoxDecoration(
                                    color: selected ? warmAmber : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: ListTile(
                                    title: Text(prod.name),
                                    subtitle: Text(
                                        'Sell Price: Tsh ${_thousandsFormat.format(prod.sellPrice)}\n'
                                        'Sellable: ${prod.sellableQty} ${prod.unit}',
                                        style: TextStyle(color: Colors.black87),
                                      ),
                                    onTap: () {
                                      dialogSetState(() {
                                        selectedProduct = prod;
                                        unitPrice = prod.sellPrice;
                                        costPrice = prod.buyPrice;
                                        discount = 0.0;
                                        formatController(unitPriceController, unitPrice);
                                        formatController(discountController, discount);
                                        updateProfit();
                                      });
                                    },
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 12),
                    // Quantity
                    TextFormField(
                      controller: quantityController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Quantity',
                        suffixText: selectedProduct?.unit ?? '',
                        filled: true,
                        fillColor: deepTeal.withValues(alpha: 0.1),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onChanged: (val) {
                        String cleaned = val.replaceAll(',', '');
                        final q = int.tryParse(cleaned);
                        if (q != null && q > 0) {
                          dialogSetState(() {
                            quantity = q;
                            formatController(quantityController, quantity.toDouble());
                            updateProfit();
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    // Unit Price
                    TextFormField(
                      controller: unitPriceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: fieldDecoration('Unit Price'),
                      onChanged: (val) {
                        String cleaned = val.replaceAll(',', '');
                        final p = double.tryParse(cleaned);
                        if (p != null && p >= 0) {
                          dialogSetState(() {
                            unitPrice = p;
                            updateProfit();
                            formatController(unitPriceController, unitPrice);
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    // Discount per item
                    TextFormField(
                      controller: discountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: fieldDecoration('Discount'),
                      onChanged: (val) {
                        String cleaned = val.replaceAll(',', '');
                        final d = double.tryParse(cleaned);
                        if (d != null && d >= 0) {
                          dialogSetState(() {
                            discount = d > unitPrice ? unitPrice : d;
                            updateProfit();
                            formatController(discountController, discount);
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    // Display Profit
                    if (selectedProduct != null)
                      Text(
                        'Item Profit: Tsh ${_thousandsFormat.format((unitPrice - costPrice) * quantity - discount)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: ButtonStyle(
                  foregroundColor: WidgetStateProperty.all(Colors.black),
                  backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                    if (states.contains(WidgetState.hovered)) return Colors.grey.shade200;
                    return Colors.white;
                  }),
                  shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                    if (states.contains(WidgetState.hovered)) return warmAmber;
                    return primaryDeepGreen;
                  }),
                  foregroundColor: WidgetStateProperty.all(offWhite),
                  shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
                onPressed: () {
                  if (selectedProduct == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please select a product')),
                    );
                    return;
                  }
                  if (quantity <= 0 || unitPrice < 0 || discount < 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Check your values')),
                    );
                    return;
                  }
                  if (quantity > selectedProduct!.sellableQty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            'Insufficient stock for "${selectedProduct!.name}". Only ${selectedProduct!.sellableQty} ${selectedProduct!.unit} available for sale.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  Navigator.pop(
                    context,
                    SaleItem(
                      productId: selectedProduct!.id,
                      name: selectedProduct!.name,
                      quantity: quantity,
                      unitPrice: unitPrice,
                      discount: discount,
                      costPrice: costPrice,
                      unit: selectedProduct!.unit,
                    ),
                  );
                },
                child: const Text('Add Item'),
              ),
            ],
          );
        },
      ),
    );

    if (newItem != null) {
      setState(() {
        items.add(newItem);
        if (!saleOnCredit) {
          totalPaid = totalAmount;
          totalPaidController.text = _thousandsFormat.format(totalPaid);
        }
      });
    }
  }

  // --- Save Sale ---
  Future<void> _saveSale() async {
    if (_isSaving) return; // guards against a double-tap firing two saves at once

    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one item before saving')),
      );
      return;
    }

    if (saleOnCredit && selectedClient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Client selection is required for sale on credit')),
      );
      return;
    }

    if (saleOnCredit && totalPaid >= totalAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Total Paid must be less than Total Amount for credit sales')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // For cash sale, totalPaid equals totalAmount
      if (!saleOnCredit) totalPaid = totalAmount;

      final facilityProvider = Provider.of<FacilityProvider>(context, listen: false);
      final authService = Provider.of<AuthService>(context, listen: false);
      final saleProvider = Provider.of<SaleProvider>(context, listen: false);
      final debtProvider = Provider.of<DebtProvider>(context, listen: false);

      final facility = facilityProvider.selectedFacility;
      if (facility == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No facility selected')),
        );
        return;
      }

      final facilityId = facility['id'] ?? '';
      final user = authService.getCurrentUser();
      final soldById = user?.uid ?? '';
      String soldByName = 'Unknown';
      if (user != null) {
        try {
          final userDoc =
              await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
          if (userDoc.exists) {
            soldByName = userDoc.data()?['fullName'] ?? 'Unknown';
          }
        } catch (_) {}
      }

      // --- Compute per-item realized/unrealized profit ---
      final List<SaleItem> updatedItems = items.map((item) {
        double paymentRatio = 0.0;
        if (totalAmount > 0) paymentRatio = (totalPaid / totalAmount).clamp(0.0, 1.0);
        final realized = item.profit * paymentRatio;
        final unrealized = item.profit - realized;
        return item.copyWith(
          realizedProfit: realized,
          unrealizedProfit: unrealized,
        );
      }).toList();

      final totalProfit =
          updatedItems.fold(0.0, (sum, item) => sum + item.profit);
      final realizedProfit =
          updatedItems.fold(0.0, (sum, item) => sum + item.realizedProfit);
      final unrealizedProfit =
          updatedItems.fold(0.0, (sum, item) => sum + item.unrealizedProfit);

      final sale = Sale(
        id: '',
        clientId: selectedClient?.id,
        clientName: selectedClient?.name,
        timestamp: DateTime.now(),
        updatedAt: DateTime.now(),
        items: updatedItems,
        totalAmount: totalAmount,
        totalPaid: totalPaid,
        facilityId: facilityId,
        soldById: soldById,
        soldByName: soldByName,
        saleOnCredit: saleOnCredit,
        totalProfit: totalProfit,
        realizedProfit: realizedProfit,
        unrealizedProfit: unrealizedProfit,
      );

      final saleId = await saleProvider.addSale(sale, facilityId);
      if (saleId == null) throw Exception('Sale could not be saved.');

      final unpaidAmount = totalAmount - totalPaid;
      if (unpaidAmount > 0 && selectedClient != null) {
        final debt = Debt(
          id: '',
          clientId: selectedClient!.id,
          clientName: selectedClient!.name,
          clientPhone: selectedClient!.phone,
          saleId: saleId,
          amountOwed: unpaidAmount,
          items: items.map((i) => i.toMap()).toList(), // <-- FIXED
          timestamp: DateTime.now(),
          updatedAt: DateTime.now(),
          source: 'Sale',
        );
        await debtProvider.addDebt(debt, facilityId);
      }


      if (!mounted) return;

      // Snackbar for sale type
      if (saleOnCredit) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saved in Sales and Debt successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sales saved successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Reset form
      setState(() {
        selectedClient = null;
        items.clear();
        totalPaid = 0.0;
        saleOnCredit = false;
        totalPaidController.text = _thousandsFormat.format(totalPaid);
        clientController.clear();
      });

      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save sale: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final clientProvider = Provider.of<ClientProvider>(context);

    return Scaffold(
      backgroundColor: offWhite,
      appBar: AppBar(
        backgroundColor: primaryDeepGreen,
        title: const Text('Add Sale', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Checkbox(
                  value: saleOnCredit,
                  onChanged: (val) {
                    setState(() {
                      saleOnCredit = val ?? false;
                      if (!saleOnCredit) {
                        selectedClient = null;
                        clientController.clear();
                        totalPaid = totalAmount;
                        totalPaidController.text = _thousandsFormat.format(totalPaid);
                      } else {
                        totalPaid = 0;
                        totalPaidController.text = _thousandsFormat.format(totalPaid);
                      }
                    });
                  },
                ),
                const Text('Sale on Credit (requires client)'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: clientController,
                        decoration: InputDecoration(
                          labelText: saleOnCredit
                              ? 'Select Client (required)'
                              : 'Select Client (optional)',
                          filled: true,
                          fillColor: deepTeal.withValues(alpha: 0.1),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.person, color: Colors.black54),
                        ),
                        onTap: () => setState(() {
                          _showClientSuggestions = clientController.text.trim().isNotEmpty;
                        }),
                        onChanged: (val) {
                          setState(() {
                            selectedClient = null; // typing clears any prior selection
                            _showClientSuggestions = val.trim().isNotEmpty;
                          });
                        },
                      ),
                      if (_showClientSuggestions && clientController.text.trim().isNotEmpty)
                        Builder(builder: (context) {
                          final query = clientController.text.toLowerCase();
                          final matches = clientProvider.clients
                              .where((c) => c.name.toLowerCase().contains(query))
                              .take(6)
                              .toList();

                          if (matches.isEmpty) return const SizedBox.shrink();

                          return Container(
                            margin: const EdgeInsets.only(top: 4),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: matches.map((client) {
                                return ListTile(
                                  title: Text(client.name),
                                  hoverColor: warmAmber.withValues(alpha: 0.15),
                                  onTap: () {
                                    setState(() {
                                      selectedClient = client;
                                      clientController.text = client.name;
                                      _showClientSuggestions = false;
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: 'Add New Client',
                  style: ButtonStyle(
                    foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                      if (states.contains(WidgetState.hovered)) return warmAmber;
                      return primaryDeepGreen;
                    }),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => AddClientScreen()),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.add_shopping_cart),
              label: const Text('Add Item'),
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                  if (states.contains(WidgetState.hovered)) return const Color(0xFFFFC400);
                  return warmAmber;
                }),
                foregroundColor: WidgetStateProperty.all(Colors.black),
                shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
              onPressed: _showAddItemDialog,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: items.isEmpty
                  ? const Center(child: Text('No items added'))
                  : ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          color: offWhite,
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            title: Text(item.name),
                            subtitle: Text(
                                'Qty: ${item.quantity} ${item.unit}\n'
                                'Unit Price: Tsh ${_thousandsFormat.format(item.unitPrice)}\n'
                                'Discount: Tsh ${_thousandsFormat.format(item.discount)}\n'
                                'Profit: Tsh ${_thousandsFormat.format(item.profit)}',
                                style: const TextStyle(color: Colors.black87)),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete),
                              style: ButtonStyle(
                                foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                                  if (states.contains(WidgetState.hovered)) return Colors.red.shade900;
                                  return Colors.red;
                                }),
                              ),
                              onPressed: () {
                                setState(() {
                                  items.removeAt(index);
                                  if (!saleOnCredit) {
                                    totalPaid = totalAmount;
                                    totalPaidController.text =
                                        _thousandsFormat.format(totalPaid);
                                  }
                                });
                              },
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: totalPaidController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Total Paid',
                filled: true,
                fillColor: deepTeal.withValues(alpha: 0.1),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (val) {
                final cleaned = val.replaceAll(',', '');
                final paid = double.tryParse(cleaned) ?? 0.0;
                setState(() {
                  totalPaid = paid;
                });
              },
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total Amount: Tsh ${_thousandsFormat.format(totalAmount)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text('Total Profit: Tsh ${_thousandsFormat.format(items.fold(0.0, (sum, i) => sum + i.profit))}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveSale,
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                    if (states.contains(WidgetState.hovered)) return warmAmber;
                    return primaryDeepGreen;
                  }),
                  foregroundColor: WidgetStateProperty.all(offWhite),
                  padding: WidgetStateProperty.all(const EdgeInsets.symmetric(vertical: 14)),
                  shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Save Sale', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
