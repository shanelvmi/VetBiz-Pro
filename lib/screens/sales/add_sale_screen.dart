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
import '../../widgets/product_thumbnail.dart';

// --- Custom Formatter ---
// --- Add Sale Screen ---
class AddSaleScreen extends StatefulWidget {
  final bool isModal;
  final Product? prefilledProduct;
  const AddSaleScreen({super.key, this.isModal = false, this.prefilledProduct});

  @override
  State<AddSaleScreen> createState() => _AddSaleScreenState();
}

class _AddSaleScreenState extends State<AddSaleScreen> {
  bool _isSaving = false;
  final TextEditingController clientController = TextEditingController();
  bool _showClientSuggestions = false;
  final TextEditingController totalPaidController = TextEditingController();
  final TextEditingController notesController = TextEditingController();
  final TextEditingController productSearchController = TextEditingController();
  bool _showProductSuggestions = false;

  Client? selectedClient;
  List<SaleItem> items = [];
  double totalPaid = 0.0;
  double saleDiscount = 0.0;
  // Computed, not stored - true whenever a registered client is selected
  // and the amount received so far is less than the total. Replaces a
  // manually-toggled bool that could drift out of sync (e.g. a
  // registered client who ends up paying in full stayed marked "on
  // credit" forever, since nothing ever reset it back to false).
  bool get saleOnCredit => !isWalkIn && selectedClient != null && totalPaid < totalAmount;
  // Replaces the old "Sale on Credit" checkbox as the trigger for
  // saleOnCredit/selectedClient - true means "Walk-in Customer" is the
  // active radio choice, matching the mockup's default state. Selecting
  // an actual client and choosing "Walk-in" are mutually exclusive,
  // radio-style, exactly like the mockup shows.
  bool isWalkIn = true;
  String? paymentMethod = 'Cash';

  // Used to measure the client field's actual on-screen position, so
  // the suggestions overlay below can be placed precisely under it
  // rather than guessing a fixed pixel offset.
  final GlobalKey _clientFieldRowKey = GlobalKey();
  // Same purpose as _clientFieldRowKey, for the product search field's
  // own suggestions overlay in the Products card.
  final GlobalKey _productFieldRowKey = GlobalKey();
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

  double get subtotal {
    return items.fold(0.0, (sum, item) => sum + (item.unitPrice * item.quantity));
  }

  double get totalAmount => subtotal - saleDiscount;

  // Adds a product from the search suggestions or the Browse Products
  // dialog. If it's already in the sale, increments its quantity
  // instead of adding a second row for the same product - tapping the
  // same product again reads naturally as "one more of these."
  void _addProductToSale(Product product) {
    if (product.sellableQty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${product.name} has no stock available on the shelf')),
      );
      return;
    }

    setState(() {
      final existingIndex = items.indexWhere((i) => i.productId == product.id);
      if (existingIndex != -1) {
        final current = items[existingIndex];
        if (current.quantity < product.sellableQty) {
          items[existingIndex] = current.copyWith(quantity: current.quantity + 1);
        }
      } else {
        items.add(SaleItem(
          productId: product.id,
          name: product.name,
          quantity: 1,
          unitPrice: product.sellPrice,
          costPrice: product.buyPrice,
          unit: product.unit,
        ));
      }
      _showProductSuggestions = false;
      productSearchController.clear();
    });
  }

  // Looks up a sale item's originating product from the provider's
  // already-loaded list - used for both the qty stepper's stock cap and
  // the table's batch/expiry display, so there's one lookup, not two
  // separate copies of the same try/catch.
  Product? _findProduct(ProductProvider provider, String productId) {
    try {
      return provider.products.firstWhere((p) => p.id == productId);
    } catch (_) {
      return null;
    }
  }

  // How many units of this product are already in the sale - 0 if
  // none. This is what lets the Browse Products dialog show a live,
  // honest quantity per row instead of every row looking identical
  // regardless of what's actually been added.
  int _quantityInSale(String productId) {
    try {
      return items.firstWhere((i) => i.productId == productId).quantity;
    } catch (_) {
      return 0;
    }
  }

  // The table row's +/- stepper - delta is +1 or -1. Silently does
  // nothing rather than erroring if the change would go below 1 (use
  // the row's delete action for that) or above the product's actual
  // shelf stock, since either is just the stepper hitting its natural
  // limit, not a real error to report.
  void _changeItemQuantity(int index, int delta) {
    final item = items[index];
    final newQty = item.quantity + delta;
    if (newQty < 1) return;

    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    final product = _findProduct(productProvider, item.productId);
    if (product != null && newQty > product.sellableQty) return;

    setState(() {
      items[index] = item.copyWith(quantity: newQty);
    });
  }

  // The Sale Summary sidebar's pencil-icon dialog for setting a
  // sale-wide discount - replaces the old per-item discount entry that
  // Phase 2 removed from the add-product flow, matching the mockup's
  // single editable "Discount" line rather than a per-line amount.
  Future<void> _showEditDiscountDialog() async {
    final controller =
        TextEditingController(text: saleDiscount > 0 ? _thousandsFormat.format(saleDiscount) : '');

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Sale Discount'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, ThousandsSeparatorInputFormatter()],
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Discount Amount (Tsh)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final value = parseThousands(controller.text);
                // A discount larger than the sale itself doesn't make
                // sense - clamped to the subtotal rather than allowing
                // a negative total.
                setState(() => saleDiscount = value.clamp(0.0, subtotal));
                Navigator.pop(dialogContext);
              },
              style: ElevatedButton.styleFrom(backgroundColor: primaryDeepGreen, foregroundColor: Colors.white),
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );
  }

  // Both perform the real change via the same logic the rest of the
  // screen uses (so the actual sale updates correctly), then also call
  // setDialogState to force the dialog's own row to redraw immediately -
  // a showDialog route doesn't automatically rebuild just because the
  // calling screen's setState fires, so without this the row would
  // keep showing a stale quantity until the dialog closes.
  void _dialogIncrement(Product product, void Function(void Function()) setDialogState) {
    final index = items.indexWhere((i) => i.productId == product.id);
    if (index == -1) {
      _addProductToSale(product);
    } else {
      _changeItemQuantity(index, 1);
    }
    setDialogState(() {});
  }

  void _dialogDecrement(Product product, void Function(void Function()) setDialogState) {
    final index = items.indexWhere((i) => i.productId == product.id);
    if (index == -1) return;
    // Decrementing to zero removes the item entirely, rather than
    // leaving a lingering "0" row - matches what "-" at the bottom of
    // a stepper should intuitively do.
    if (items[index].quantity <= 1) {
      _removeItemAt(index);
    } else {
      _changeItemQuantity(index, -1);
    }
    setDialogState(() {});
  }

  // The "Browse Products" button's dialog - a searchable, scrollable
  // view of the full sellable catalog rather than just the quick
  // inline search suggestions, for when someone wants to look through
  // everything rather than type a specific name. Each row shows the
  // actual, live quantity already in the sale (0 if none) with its own
  // +/- - tapping the row itself does nothing, only the +/- buttons
  // change anything, so browsing never silently adds or stacks up
  // quantity by accident.
  Future<void> _showBrowseProductsDialog() async {
    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    final allProducts = productProvider.sellableProducts;
    final categories = allProducts.map((p) => p.category).where((c) => c.isNotEmpty).toSet().toList()..sort();
    String dialogQuery = '';
    String? selectedCategory;
    Offset dialogOffset = Offset.zero;

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Browse Products',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final filtered = allProducts.where((p) {
              final matchesQuery = dialogQuery.trim().isEmpty ||
                  p.name.toLowerCase().contains(dialogQuery.toLowerCase()) ||
                  p.category.toLowerCase().contains(dialogQuery.toLowerCase()) ||
                  (p.batchNo?.toLowerCase().contains(dialogQuery.toLowerCase()) ?? false);
              final matchesCategory = selectedCategory == null || p.category == selectedCategory;
              return matchesQuery && matchesCategory;
            }).toList();

            return Material(
              color: Colors.transparent,
              child: Center(
                child: Transform.translate(
                  offset: dialogOffset,
                  child: Container(
                    width: 480,
                    constraints: const BoxConstraints(maxHeight: 560),
                    decoration: BoxDecoration(
                      color: offWhite,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 20)],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Only this title bar responds to drag - the
                        // search field and list below are ordinary,
                        // untouched widgets with their own gestures.
                        GestureDetector(
                          onPanUpdate: (details) => setDialogState(() {
                            dialogOffset += details.delta;
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: primaryDeepGreen,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.open_with, color: Colors.white70, size: 16),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Text('Browse Products',
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, color: Colors.white, size: 20),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () => Navigator.pop(dialogContext),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: SizedBox(
                            width: 448,
                            height: 480,
                            child: Column(
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        decoration: InputDecoration(
                                          hintText: 'Filter by name, batch no or category...',
                                          prefixIcon: const Icon(Icons.search, size: 20),
                                          isDense: true,
                                          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        onChanged: (val) => setDialogState(() => dialogQuery = val),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    PopupMenuButton<String?>(
                                      initialValue: selectedCategory,
                                      tooltip: 'Filter by category',
                                      onSelected: (category) => setDialogState(() => selectedCategory = category),
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(value: null, child: Text('All Categories')),
                                        ...categories.map((c) => PopupMenuItem(value: c, child: Text(c))),
                                      ],
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: selectedCategory != null
                                              ? primaryDeepGreen.withValues(alpha: 0.1)
                                              : Colors.white,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: selectedCategory != null
                                                ? primaryDeepGreen
                                                : Colors.grey.withValues(alpha: 0.35),
                                          ),
                                        ),
                                        child: Icon(Icons.filter_list, size: 20,
                                            color: selectedCategory != null ? primaryDeepGreen : Colors.black54),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Expanded(
                                  child: filtered.isEmpty
                                      ? const Center(child: Text('No products found'))
                                      : ListView.builder(
                                          itemCount: filtered.length,
                                          itemBuilder: (context, index) {
                                            final product = filtered[index];
                                            final outOfStock = product.sellableQty <= 0;
                                            final qtyInSale = _quantityInSale(product.id);
                                            // How much is actually still available to add
                                            // to THIS sale - shelf stock minus what's
                                            // already been added - not the raw,
                                            // unchanging shelf total. Visibly decreases
                                            // as + is tapped, increases as - is tapped.
                                            final remainingAvailable = product.sellableQty - qtyInSale;
                                            final canAddMore = !outOfStock && remainingAvailable > 0;

                                            return Padding(
                                              padding: const EdgeInsets.symmetric(vertical: 6),
                                              child: Row(
                                                children: [
                                                  ProductThumbnail.square(
                                                    imageUrl: product.imageUrl,
                                                    size: 44,
                                                    backgroundColor: primaryDeepGreen.withValues(alpha: 0.08),
                                                    iconColor: primaryDeepGreen,
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(product.name,
                                                            style: const TextStyle(fontWeight: FontWeight.w600),
                                                            overflow: TextOverflow.ellipsis),
                                                        const SizedBox(height: 2),
                                                        Text(
                                                          outOfStock
                                                              ? 'Out of stock'
                                                              : '$remainingAvailable ${product.unit} available · Tsh ${_thousandsFormat.format(product.sellPrice)}',
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color: outOfStock ? Colors.red : Colors.grey[600],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  SizedBox(
                                                    width: 92,
                                                    child: outOfStock
                                                        ? const SizedBox.shrink()
                                                        : (qtyInSale == 0
                                                            ? Align(
                                                                alignment: Alignment.centerRight,
                                                                child: InkWell(
                                                                  borderRadius: BorderRadius.circular(20),
                                                                  onTap: () => _dialogIncrement(product, setDialogState),
                                                                  child: Icon(Icons.add_circle, color: primaryDeepGreen, size: 26),
                                                                ),
                                                              )
                                                            : Row(
                                                                mainAxisAlignment: MainAxisAlignment.end,
                                                                children: [
                                                                  InkWell(
                                                                    borderRadius: BorderRadius.circular(20),
                                                                    onTap: () => _dialogDecrement(product, setDialogState),
                                                                    child: Icon(Icons.remove_circle_outline,
                                                                        color: Colors.grey[700], size: 22),
                                                                  ),
                                                                  SizedBox(
                                                                    width: 26,
                                                                    child: Text(
                                                                      '$qtyInSale',
                                                                      textAlign: TextAlign.center,
                                                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                                                    ),
                                                                  ),
                                                                  InkWell(
                                                                    borderRadius: BorderRadius.circular(20),
                                                                    onTap: canAddMore
                                                                        ? () => _dialogIncrement(product, setDialogState)
                                                                        : null,
                                                                    child: Icon(Icons.add_circle,
                                                                        color: canAddMore ? primaryDeepGreen : Colors.grey[350],
                                                                        size: 22),
                                                                  ),
                                                                ],
                                                              )),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    totalPaid = 0.0;
    totalPaidController.text = _thousandsFormat.format(totalPaid);
    if (widget.prefilledProduct != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _addProductToSale(widget.prefilledProduct!);
      });
    }
  }

  @override
  void dispose() {
    clientController.dispose();
    totalPaidController.dispose();
    notesController.dispose();
    productSearchController.dispose();
    super.dispose();
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

    if (isWalkIn && totalPaid < totalAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Walk-in sales must be paid in full - select a registered client to allow partial payment')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Caps the recorded amount at the actual total whenever the sale
      // isn't on credit - covers both an exact cash payment and an
      // overpayment expecting change (e.g. Tsh 50,000 tendered on a
      // Tsh 45,000 sale): the excess is change handed back, not extra
      // sale revenue, so only the total itself should be recorded.
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
        notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
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
        isWalkIn = true;
        items.clear();
        totalPaid = 0.0;
        saleDiscount = 0.0;
        paymentMethod = 'Cash';
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
    final productProvider = Provider.of<ProductProvider>(context);

    return Scaffold(
      backgroundColor: offWhite,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Container(
          color: primaryDeepGreen,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                const Icon(Icons.shopping_cart_outlined, color: Colors.white, size: 22),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Record Sale',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                ),
                if (widget.isModal)
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  )
                else
                  const BackButton(color: Colors.white),
              ],
            ),
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 480;
          final isTwoColumn = constraints.maxWidth >= 860;
          return Stack(
            key: _stackKey,
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1080),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: isTwoColumn
                        ? IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 2, child: _buildLeftColumn(isNarrow)),
                                const SizedBox(width: 16),
                                Expanded(flex: 1, child: _buildSaleSummarySidebar()),
                              ],
                            ),
                          )
                        : Column(
                            children: [
                              _buildLeftColumn(isNarrow),
                              const SizedBox(height: 16),
                              _buildSaleSummarySidebar(),
                            ],
                          ),
                  ),
                ),
              ),
              _buildClientSuggestionsOverlay(clientProvider),
              _buildProductSuggestionsOverlay(productProvider),
            ],
          );
        },
      ),
      bottomNavigationBar: _buildFooter(),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 14, 20, 14 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.withValues(alpha: 0.15))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.close, size: 16),
            label: const Text('Cancel'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.black87,
              side: BorderSide(color: Colors.grey.withValues(alpha: 0.4)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          ),
          ElevatedButton(
            onPressed: _isSaving ? null : _saveSale,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryDeepGreen,
              foregroundColor: Colors.white,
              disabledBackgroundColor: primaryDeepGreen.withValues(alpha: 0.5),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 16),
                      SizedBox(width: 8),
                      Text('Record Sale'),
                      SizedBox(width: 6),
                      Icon(Icons.arrow_forward, size: 16),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 18, color: primaryDeepGreen),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: primaryDeepGreen)),
      ],
    );
  }

  Widget _buildSaleSummarySidebar() {
    final totalItemCount = items.fold<int>(0, (sum, i) => sum + i.quantity);
    final change = (totalPaid - totalAmount) > 0 ? (totalPaid - totalAmount) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeader(Icons.receipt_long_outlined, 'Sale Summary'),
              const SizedBox(height: 14),
              _summaryRow('Total Items', '$totalItemCount'),
              const SizedBox(height: 10),
              _summaryRow('Subtotal', _thousandsFormat.format(subtotal)),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Discount', style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                  Row(
                    children: [
                      Text(_thousandsFormat.format(saleDiscount),
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(width: 6),
                      InkWell(
                        borderRadius: BorderRadius.circular(4),
                        onTap: items.isEmpty ? null : _showEditDiscountDialog,
                        child: Icon(Icons.edit_outlined, size: 15, color: items.isEmpty ? Colors.grey[300] : Colors.grey[500]),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: primaryDeepGreen.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: primaryDeepGreen.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total Amount', style: TextStyle(fontSize: 12.5, color: Colors.grey[700])),
              const SizedBox(height: 4),
              Text('Tsh ${_thousandsFormat.format(totalAmount)}',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: primaryDeepGreen)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: primaryDeepGreen.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: primaryDeepGreen.withValues(alpha: 0.15)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.credit_card_outlined, size: 16, color: primaryDeepGreen),
                  const SizedBox(width: 8),
                  Text('Payment Method',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: primaryDeepGreen)),
                ],
              ),
              const SizedBox(height: 10),
              PopupMenuButton<String>(
                initialValue: paymentMethod,
                onSelected: (method) => setState(() => paymentMethod = method),
                itemBuilder: (context) => kPaymentMethods.map((method) {
                  return PopupMenuItem(
                    value: method,
                    child: Row(
                      children: [
                        Icon(iconForPaymentMethod(method), size: 18, color: primaryDeepGreen),
                        const SizedBox(width: 10),
                        Text(method),
                      ],
                    ),
                  );
                }).toList(),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(iconForPaymentMethod(paymentMethod ?? 'Cash'), size: 18, color: primaryDeepGreen),
                      const SizedBox(width: 10),
                      Expanded(child: Text(paymentMethod ?? 'Cash')),
                      Icon(Icons.expand_more, size: 18, color: Colors.grey[600]),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text('Amount Received (Tsh) *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 6),
        TextFormField(
          controller: totalPaidController,
          enabled: items.isNotEmpty,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, ThousandsSeparatorInputFormatter()],
          decoration: InputDecoration(
            hintText: '0.00',
            filled: true,
            fillColor: Colors.white,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.35)),
            ),
          ),
          onChanged: (val) {
            final paid = parseThousands(val);
            setState(() => totalPaid = paid);
          },
        ),
        const SizedBox(height: 14),
        const Text('Change (Tsh)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.25)),
          ),
          child: Text(_thousandsFormat.format(change), style: TextStyle(color: Colors.grey[600])),
        ),
      ],
    );
  }

  Widget _summaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      ],
    );
  }

  Widget _buildLeftColumn(bool isNarrow) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildClientInfoCard(isNarrow),
        const SizedBox(height: 16),
        _buildProductsCard(isNarrow),
        const SizedBox(height: 16),
        _buildNotesCard(),
      ],
    );
  }

  Widget _buildClientInfoCard(bool isNarrow) {
    final searchRow = Row(
      key: _clientFieldRowKey,
      children: [
        Expanded(
          child: TextField(
            controller: clientController,
            decoration: InputDecoration(
              hintText: 'Search or select client...',
              hintStyle: const TextStyle(fontSize: 14),
              filled: true,
              fillColor: Colors.white,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.35)),
              ),
              prefixIcon: const Icon(Icons.person_outline, color: Colors.black54),
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
          padding: const EdgeInsets.all(10),
          constraints: const BoxConstraints(),
          style: ButtonStyle(
            shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
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
    );

    final walkInCard = InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => setState(() {
        isWalkIn = !isWalkIn;
        selectedClient = null;
        clientController.clear();
        totalPaid = 0;
        totalPaidController.text = _thousandsFormat.format(totalPaid);
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isWalkIn ? primaryDeepGreen.withValues(alpha: 0.06) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isWalkIn ? primaryDeepGreen : Colors.grey.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.person_outline, size: 22, color: primaryDeepGreen),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Walk-in Customer',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: primaryDeepGreen)),
                  Text('No client selected', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              ),
            ),
            Radio<bool>(
              value: true,
              groupValue: isWalkIn,
              activeColor: primaryDeepGreen,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              onChanged: (_) => setState(() {
                isWalkIn = !isWalkIn;
                selectedClient = null;
                clientController.clear();
                totalPaid = 0;
                totalPaidController.text = _thousandsFormat.format(totalPaid);
              }),
            ),
          ],
        ),
      ),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(Icons.shopping_cart_outlined, 'Client Information'),
          const SizedBox(height: 12),
          const Text('Select Client *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          isNarrow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    searchRow,
                    const SizedBox(height: 10),
                    walkInCard,
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: searchRow),
                    const SizedBox(width: 10),
                    Expanded(flex: 2, child: walkInCard),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildProductsCard(bool isNarrow) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(Icons.shopping_cart_outlined, 'Products'),
          const SizedBox(height: 12),
          Row(
            key: _productFieldRowKey,
            children: [
              Expanded(
                child: TextField(
                  controller: productSearchController,
                  decoration: InputDecoration(
                    hintText: 'Search product by name, batch no or category...',
                    hintStyle: const TextStyle(fontSize: 14),
                    filled: true,
                    fillColor: Colors.white,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.35)),
                    ),
                    prefixIcon: const Icon(Icons.search, color: Colors.black54),
                  ),
                  onTap: () => setState(() {
                    _showProductSuggestions = productSearchController.text.trim().isNotEmpty;
                  }),
                  onChanged: (val) => setState(() {
                    _showProductSuggestions = val.trim().isNotEmpty;
                  }),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.grid_view_outlined, size: 16),
                label: const Text('Browse Products'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: primaryDeepGreen,
                  side: BorderSide(color: primaryDeepGreen.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _showBrowseProductsDialog,
              ),
            ],
          ),
          const SizedBox(height: 16),
          items.isEmpty
              ? _buildEmptyProductsState()
              : (isNarrow ? _buildProductsCompactList() : _buildProductsTable()),
        ],
      ),
    );
  }

  Widget _buildEmptyProductsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: [
            Icon(Icons.playlist_add_outlined, size: 40, color: Colors.grey[350]),
            const SizedBox(height: 10),
            Text('No products added yet',
                style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[600])),
            const SizedBox(height: 4),
            Text('Search and add products to this sale',
                style: TextStyle(fontSize: 12.5, color: Colors.grey[500])),
          ],
        ),
      ),
    );
  }

  static const TextStyle _tableHeaderStyle =
      TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.black54);

  // The wide, desktop-width table matching the mockup's column layout
  // (#, Product, Batch No., Expiry Date, Unit Price, Qty, Total,
  // Action). Batch No./Expiry Date come from the product's own current
  // top-level fields (already loaded in memory via the provider) rather
  // than querying its batches subcollection per row - actual FIFO batch
  // allocation only happens when the sale is saved, so this is a
  // preview of what it'll most likely draw from, not a locked-in
  // allocation.
  Widget _buildProductsTable() {
    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    final dateFormat = DateFormat('dd MMM yyyy');

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.06),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          ),
          child: const Row(
            children: [
              SizedBox(width: 22, child: Text('#', style: _tableHeaderStyle)),
              Expanded(flex: 3, child: Text('Product', style: _tableHeaderStyle)),
              Expanded(flex: 2, child: Text('Batch No.', style: _tableHeaderStyle)),
              Expanded(flex: 2, child: Text('Expiry Date', style: _tableHeaderStyle)),
              Expanded(flex: 2, child: Text('Unit Price (Tsh)', style: _tableHeaderStyle)),
              SizedBox(width: 96, child: Text('Qty', style: _tableHeaderStyle, textAlign: TextAlign.center)),
              Expanded(flex: 2, child: Text('Total (Tsh)', style: _tableHeaderStyle)),
              SizedBox(width: 32, child: SizedBox.shrink()),
            ],
          ),
        ),
        ...items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final product = _findProduct(productProvider, item.productId);
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.12))),
            ),
            child: Row(
              children: [
                SizedBox(width: 22, child: Text('${index + 1}', style: const TextStyle(fontSize: 13))),
                Expanded(
                  flex: 3,
                  child: Text(item.name,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis),
                ),
                Expanded(
                  flex: 2,
                  child: Text(product?.batchNo ?? '-',
                      style: TextStyle(fontSize: 12.5, color: Colors.grey[600])),
                ),
                Expanded(
                  flex: 2,
                  child: Text(product?.expiry != null ? dateFormat.format(product!.expiry!) : '-',
                      style: TextStyle(fontSize: 12.5, color: Colors.grey[600])),
                ),
                Expanded(
                  flex: 2,
                  child: Text(_thousandsFormat.format(item.unitPrice), style: const TextStyle(fontSize: 13)),
                ),
                SizedBox(
                  width: 96,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _changeItemQuantity(index, -1),
                        child: Icon(Icons.remove_circle_outline, size: 18, color: Colors.grey[600]),
                      ),
                      SizedBox(
                        width: 26,
                        child: Text('${item.quantity}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _changeItemQuantity(index, 1),
                        child: Icon(Icons.add_circle_outline, size: 18, color: primaryDeepGreen),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    _thousandsFormat.format((item.unitPrice * item.quantity) - item.discount),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
                SizedBox(
                  width: 32,
                  child: IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    color: Colors.red,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => _removeItemAt(index),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // Narrower, card-style stand-in for the table on small screens, where
  // eight table columns genuinely can't fit legibly - same data and the
  // same +/- stepper/delete actions, just stacked instead of in
  // columns.
  Widget _buildProductsCompactList() {
    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    final dateFormat = DateFormat('dd MMM yyyy');

    return Column(
      children: items.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        final product = _findProduct(productProvider, item.productId);
        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          color: offWhite,
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(item.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          overflow: TextOverflow.ellipsis),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      color: Colors.red,
                      onPressed: () => _removeItemAt(index),
                    ),
                  ],
                ),
                if (product?.batchNo != null || product?.expiry != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      [
                        if (product?.batchNo != null) 'Batch: ${product!.batchNo}',
                        if (product?.expiry != null) 'Exp: ${dateFormat.format(product!.expiry!)}',
                      ].join('  •  '),
                      style: TextStyle(fontSize: 11.5, color: Colors.grey[600]),
                    ),
                  ),
                Row(
                  children: [
                    Text('Tsh ${_thousandsFormat.format(item.unitPrice)}',
                        style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                    const Spacer(),
                    InkWell(
                      onTap: () => _changeItemQuantity(index, -1),
                      child: Icon(Icons.remove_circle_outline, size: 20, color: Colors.grey[600]),
                    ),
                    SizedBox(
                      width: 30,
                      child: Text('${item.quantity}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    ),
                    InkWell(
                      onTap: () => _changeItemQuantity(index, 1),
                      child: Icon(Icons.add_circle_outline, size: 20, color: primaryDeepGreen),
                    ),
                    const SizedBox(width: 10),
                    Text('Tsh ${_thousandsFormat.format((item.unitPrice * item.quantity) - item.discount)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // Shared by both the table's and the compact list's delete action.
  void _removeItemAt(int index) {
    setState(() {
      items.removeAt(index);
    });
  }

  Widget _buildNotesCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(Icons.description_outlined, 'Notes'),
          const SizedBox(height: 12),
          TextFormField(
            controller: notesController,
            maxLines: 2,
            maxLength: 200,
            decoration: InputDecoration(
              hintText: 'Add any additional notes (optional)...',
              filled: true,
              fillColor: Colors.white,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.35)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClientSuggestionsOverlay(ClientProvider clientProvider) {
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

    // Aligns with the field's own actual on-screen left edge and width,
    // rather than assuming the field is centered within some fixed
    // page width - correct regardless of which column the field sits
    // in, how it's nested inside its card, or the screen size.
    final localLeft = stackBox != null
        ? stackBox.globalToLocal(fieldPosition).dx
        : fieldPosition.dx;

    return Positioned(
      top: localTop + fieldSize.height + 4,
      left: localLeft,
      width: fieldSize.width,
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
                    isWalkIn = false;
                    totalPaid = 0;
                    totalPaidController.text = _thousandsFormat.format(totalPaid);
                  });
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  /// Same pattern as _buildClientSuggestionsOverlay - a genuine overlay
  /// measured off the product search field's own on-screen position,
  /// not sitting inline in the form's layout flow. Matches by name,
  /// category, and batch number.
  Widget _buildProductSuggestionsOverlay(ProductProvider productProvider) {
    if (!_showProductSuggestions || productSearchController.text.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    final renderBox = _productFieldRowKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return const SizedBox.shrink();

    final fieldPosition = renderBox.localToGlobal(Offset.zero);
    final fieldSize = renderBox.size;

    final stackBox = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    final localTop = stackBox != null
        ? stackBox.globalToLocal(fieldPosition).dy
        : fieldPosition.dy;
    final localLeft = stackBox != null
        ? stackBox.globalToLocal(fieldPosition).dx
        : fieldPosition.dx;

    final query = productSearchController.text.toLowerCase();
    final matches = productProvider.sellableProducts
        .where((p) =>
            p.name.toLowerCase().contains(query) ||
            p.category.toLowerCase().contains(query) ||
            (p.batchNo?.toLowerCase().contains(query) ?? false))
        .take(6)
        .toList();

    if (matches.isEmpty) return const SizedBox.shrink();

    return Positioned(
      top: localTop + fieldSize.height + 4,
      left: localLeft,
      width: fieldSize.width,
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
            children: matches.map((product) {
              return ListTile(
                leading: ProductThumbnail.square(
                  imageUrl: product.imageUrl,
                  size: 40,
                  backgroundColor: primaryDeepGreen.withValues(alpha: 0.08),
                  iconColor: primaryDeepGreen,
                ),
                title: Text(product.name),
                subtitle: Text('${product.sellableQty} ${product.unit} available · Tsh ${_thousandsFormat.format(product.sellPrice)}'),
                hoverColor: warmAmber.withValues(alpha: 0.15),
                onTap: () => _addProductToSale(product),
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
Future<void> showAddSaleScreen(BuildContext context, {Product? product}) async {
  final isWideScreen = MediaQuery.of(context).size.width >= 900;

  if (!isWideScreen) {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AddSaleScreen(prefilledProduct: product)),
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
      final modalWidth = (screenSize.width * 0.60).clamp(0, 940).toDouble();
      // Never shorter than the Browse Products dialog (480px, fixed) -
      // 88% of screen height comfortably exceeds that on most windows,
      // but this guarantees it even on a smaller one.
      final modalHeight = (screenSize.height * 0.88) < 480 ? 480.0 : screenSize.height * 0.88;
      return Center(
        child: SizedBox(
          width: modalWidth,
          height: modalHeight,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Material(
              child: AddSaleScreen(isModal: true, prefilledProduct: product),
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
