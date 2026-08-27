import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

import '../../models/client.dart';
import '../../models/product.dart';
import '../../models/sale.dart';
import '../../models/debt.dart';
import '../../widgets/payment_method_selector.dart';
import '../../utils/thousands_input_formatter.dart';

import '../../providers/client_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/sale_provider.dart';
import '../../providers/facility_provider.dart';
import '../../providers/debt_provider.dart';

import '../../services/auth_service.dart';
import '../clients/add_client_screen.dart';

// --- Custom Formatter ---
// --- Add Sale Screen ---
class AddSaleScreen extends StatefulWidget {
  final bool isModal;
  const AddSaleScreen({super.key, this.isModal = false});

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
  String? paymentMethod;

  // Used to measure the client field's actual on-screen position, so
  // the suggestions overlay below can be placed precisely under it
  // rather than guessing a fixed pixel offset.
  final GlobalKey _clientFieldRowKey = GlobalKey();
  // The Stack the overlay is positioned within - used as the exact
  // reference frame for converting the field's global position to a
  // local one, rather than the whole Scaffold (which would also
  // include the AppBar's own height in that conversion).
  final GlobalKey _stackKey = GlobalKey();

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
                                    subtitle: Row(
                                      children: [
                                        Text(
                                          'Tsh ${_thousandsFormat.format(prod.sellPrice)}',
                                          style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          '${prod.sellableQty} ${prod.unit} available',
                                          style: TextStyle(color: Colors.grey[600], fontSize: 12.5),
                                        ),
                                      ],
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
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, ThousandsSeparatorInputFormatter()],
                      decoration: fieldDecoration('Unit Price'),
                      onChanged: (val) {
                        final p = parseThousands(val);
                        dialogSetState(() {
                          unitPrice = p;
                          updateProfit();
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    // Discount per item
                    TextFormField(
                      controller: discountController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, ThousandsSeparatorInputFormatter()],
                      decoration: fieldDecoration('Discount'),
                      onChanged: (val) {
                        final d = parseThousands(val);
                        final clamped = d > unitPrice ? unitPrice : d;
                        dialogSetState(() {
                          discount = clamped;
                          updateProfit();
                        });
                        if (clamped != d) {
                          formatController(discountController, clamped);
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

    if (totalPaid > 0 && paymentMethod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select how this payment was made')),
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
        paymentMethod: totalPaid > 0 ? paymentMethod : null,
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
        centerTitle: true,
        title: const Text('Record Sale', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        automaticallyImplyLeading: !widget.isModal,
        leading: widget.isModal
            ? IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 480;
          return Stack(
            key: _stackKey,
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: SingleChildScrollView(
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
              key: _clientFieldRowKey,
              children: [
                Expanded(
                  child: TextField(
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
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.add, color: Colors.white),
                  tooltip: 'Add New Client',
                  style: ButtonStyle(
                    shape: WidgetStateProperty.all(const CircleBorder()),
                    backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                      if (states.contains(WidgetState.hovered)) return warmAmber;
                      return primaryDeepGreen;
                    }),
                  ),
                  onPressed: () {
                    showAddClientScreen(context);
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
            items.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('No items added')),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        color: offWhite,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 20),
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
                                ],
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 20,
                                runSpacing: 6,
                                children: [
                                  _SaleItemStat(label: 'Qty', value: '${item.quantity} ${item.unit}'),
                                  _SaleItemStat(
                                      label: 'Unit Price', value: 'Tsh ${_thousandsFormat.format(item.unitPrice)}'),
                                  if (item.discount > 0)
                                    _SaleItemStat(
                                        label: 'Discount', value: 'Tsh ${_thousandsFormat.format(item.discount)}'),
                                  _SaleItemStat(
                                    label: 'Profit',
                                    value: 'Tsh ${_thousandsFormat.format(item.profit)}',
                                    valueColor: Colors.green[700],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
            const SizedBox(height: 16),
            TextFormField(
              controller: totalPaidController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, ThousandsSeparatorInputFormatter()],
              decoration: InputDecoration(
                labelText: 'Total Paid',
                filled: true,
                fillColor: deepTeal.withValues(alpha: 0.1),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (val) {
                final paid = parseThousands(val);
                setState(() {
                  totalPaid = paid;
                });
              },
            ),
            if (totalPaid > 0) ...[
              const SizedBox(height: 16),
              PaymentMethodSelector(
                value: paymentMethod,
                activeColor: primaryDeepGreen,
                onChanged: (method) => setState(() => paymentMethod = method),
              ),
            ],
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
                  ),
                ),
              _buildClientSuggestionsOverlay(clientProvider, isNarrow),
            ],
          );
        },
      ),
    );
  }

  /// The client-name suggestions, shown as a genuine overlay positioned
  /// just under the client field - rather than sitting inline in the
  /// form's own layout flow, where it would push the Add Item button
  /// and everything below it down every time it appeared. Measures the
  /// client field's actual on-screen position via its GlobalKey, rather
  /// than assuming a fixed pixel offset that could drift if anything
  /// above it (like the Sale on Credit checkbox row) ever wraps to a
  /// second line on a narrow screen.
  Widget _buildClientSuggestionsOverlay(ClientProvider clientProvider, bool isNarrow) {
    if (!_showClientSuggestions || clientController.text.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    final renderBox = _clientFieldRowKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return const SizedBox.shrink();

    final fieldPosition = renderBox.localToGlobal(Offset.zero);
    final fieldSize = renderBox.size;

    // Convert the field's global position back to a position relative
    // to the Stack it's being positioned within - not the whole
    // Scaffold, which would also fold the AppBar's own height into
    // this conversion and throw the overlay's position off.
    final stackBox = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    final localTop = stackBox != null
        ? stackBox.globalToLocal(fieldPosition).dy
        : fieldPosition.dy;

    final query = clientController.text.toLowerCase();
    final matches = clientProvider.clients
        .where((c) => c.name.toLowerCase().contains(query))
        .take(6)
        .toList();

    if (matches.isEmpty) return const SizedBox.shrink();

    // Same centering/max-width as the form itself, so the overlay
    // lines up with the field beneath it instead of stretching to the
    // full screen width on desktop.
    final horizontalInset = isNarrow
        ? 16.0
        : (MediaQuery.of(context).size.width - 700).clamp(0, double.infinity) / 2 + 16;

    return Positioned(
      top: localTop + fieldSize.height + 4,
      left: horizontalInset,
      right: horizontalInset,
      child: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 260),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
            color: offWhite,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
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
        ),
      ),
    );
  }
}

/// The one entry point for opening Add Sale - a full-screen push on
/// mobile, a large, centered, dismissable modal on desktop/tablet-
/// width screens. Same reasoning as showSubscriptionScreen/
/// showPromotionsScreen elsewhere in this app: recording a sale is a
/// quick, frequent, in-and-out action, and a full page navigation away
/// from the Dashboard (and all the way back) doesn't fit that as well
/// as a dismissable overlay does.
Future<void> showAddSaleScreen(BuildContext context) async {
  final isWideScreen = MediaQuery.of(context).size.width >= 900;

  if (!isWideScreen) {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AddSaleScreen()),
    );
    return;
  }

  await showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Record Sale',
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
            child: const Material(
              child: AddSaleScreen(isModal: true),
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

/// A single label+value stat within a sale item's card - a compact,
/// scannable pair (small grey label above, bold value below) rather
/// than a line of prose like "Qty: 3 pcs". Laid out in a Wrap so
/// several sit side by side and read at a glance.
class _SaleItemStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _SaleItemStat({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        Text(
          value,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: valueColor ?? Colors.black87),
        ),
      ],
    );
  }
}
