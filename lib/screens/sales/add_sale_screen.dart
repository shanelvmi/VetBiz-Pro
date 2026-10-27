import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import '../../utils/sentence_capitalization_formatter.dart';

import '../../models/client.dart';
import '../../models/product.dart';
import '../../models/sale.dart';
import '../../widgets/payment_method_selector.dart';
import '../../utils/thousands_input_formatter.dart';

import '../../providers/client_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/sale_provider.dart';
import '../../providers/facility_provider.dart';

import '../../services/auth_service.dart';
import '../clients/add_client_screen.dart';
import '../../widgets/product_thumbnail.dart';
import '../../data/collections.dart';
import '../../config/money.dart';
import '../../config/app_defaults.dart';
import '../../config/app_timeouts.dart';
import '../../config/app_date_format.dart';
import '../../ui/feedback/app_feedback.dart';
import '../../theme/app_text.dart';
import '../../theme/app_dimens.dart';
import '../../theme/theme_context.dart';
import '../../theme/app_breakpoints.dart';
import '../../theme/app_tap_target.dart';
import '../../theme/app_motion.dart';
import '../../l10n/l10n.dart';
import '../../widgets/app_sheet.dart';

// --- Custom Formatter ---
// --- Add Sale Screen ---
class AddSaleScreen extends StatefulWidget {
  final bool isModal;
  final Product? prefilledProduct;
  /// Null: the app's own Firestore. Tests pass an in-memory one (PH2a).
  final FirebaseFirestore? firestore;

  const AddSaleScreen({super.key, this.isModal = false, this.prefilledProduct, this.firestore});

  @override
  State<AddSaleScreen> createState() => _AddSaleScreenState();
}

class _AddSaleScreenState extends State<AddSaleScreen> {
  // Null widget.firestore: the app's own Firestore (PH2a seam).
  FirebaseFirestore get _db => widget.firestore ?? FirebaseFirestore.instance;

  bool _isSaving = false;
  // Set synchronously on the first tap, so a double-click cannot start a
  // second save during the awaits before _isSaving is set.
  bool _saveStarted = false;
  // The id of the sale this form will record, made when the form opens and
  // again after each saved sale, never reused for a new one. A Retry after
  // a failure keeps it, so a save that did land is not recorded twice
  // (SaleProvider.addSale returns the saved one).
  late String _saleId;
  bool _paymentMethodMissing = false;
  final TextEditingController clientController = TextEditingController();
  bool _showClientSuggestions = false;
  Timer? _clientSearchDebounce;
  List<Client> _clientSearchResults = [];
  bool _isSearchingClients = false;
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
  String? paymentMethod;

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

  double get subtotal {
    return items.fold(0.0, (total, item) => total + (item.unitPrice * item.quantity));
  }

  double get totalAmount => subtotal - saleDiscount;

  // Adds a product from the search suggestions or the Browse Products
  // dialog. If it's already in the sale, increments its quantity
  // instead of adding a second row for the same product - tapping the
  // same product again reads naturally as "one more of these."
  void _addProductToSale(Product product) {
    if (product.sellableQty <= 0) {
      AppFeedback.info(L10n.current.sales_noShelfStock(product.name));
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
          category: product.category,
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
        TextEditingController(text: saleDiscount > 0 ? Money.decimal(saleDiscount) : '');

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(context.l10n.sales_saleDiscount),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, ThousandsSeparatorInputFormatter()],
            autofocus: true,
            decoration: InputDecoration(
              labelText: context.l10n.sales_discountAmountLabel(AppDefaults.currencySymbol),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.r10)),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(context.l10n.common_cancel)),
            ElevatedButton(
              onPressed: () {
                final value = parseThousands(controller.text);
                // A discount larger than the sale itself doesn't make
                // sense - clamped to the subtotal rather than allowing
                // a negative total.
                setState(() => saleDiscount = value.clamp(0.0, subtotal));
                Navigator.pop(dialogContext);
              },
              style: ElevatedButton.styleFrom(backgroundColor: context.colors.primary, foregroundColor: context.colors.onPrimary),
              child: Text(context.l10n.common_apply),
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
      barrierLabel: context.l10n.sales_browseProducts,
      barrierColor: context.colors.scrim.withValues(alpha: AppAlpha.a50),
      transitionDuration: AppMotion.fast,
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
                      color: context.colors.raisedSurface,
                      borderRadius: BorderRadius.circular(AppRadius.r16),
                      boxShadow: [BoxShadow(color: context.colors.shadow.withValues(alpha: AppAlpha.a30), blurRadius: 20)],
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
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
                            decoration: BoxDecoration(
                              color: context.colors.brandSurface,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.r16)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.open_with, color: context.colors.onBrandSurfaceMuted, size: AppIconSize.i16),
                                const SizedBox(width: AppSpacing.s10),
                                Expanded(
                                  child: Text(context.l10n.sales_browseProducts,
                                      style: TextStyle(color: context.colors.onBrandSurface, fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f16)),
                                ),
                                IconButton(
                                  icon: Icon(Icons.close, color: context.colors.onBrandSurface, size: AppIconSize.i20),
                                  padding: EdgeInsets.zero,
                                  constraints: AppTapTarget.iconConstraints(dialogContext),
                                  onPressed: () => Navigator.pop(dialogContext),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(AppSpacing.s16),
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
                                          hintText: context.l10n.sales_browseFilterHint,
                                          prefixIcon: const Icon(Icons.search, size: AppIconSize.i20),
                                          isDense: true,
                                          contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.s12, horizontal: AppSpacing.s12),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.r10)),
                                        ),
                                        onChanged: (val) => setDialogState(() => dialogQuery = val),
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.s8),
                                    PopupMenuButton<String?>(
                                      initialValue: selectedCategory,
                                      tooltip: context.l10n.sales_filterByCategory,
                                      onSelected: (category) => setDialogState(() => selectedCategory = category),
                                      itemBuilder: (context) => [
                                        PopupMenuItem(value: null, child: Text(context.l10n.sales_allCategories)),
                                        // Shows the label; filters on the stored category.
                                        ...categories.map((c) => PopupMenuItem(value: c, child: Text(context.l10n.productCategoryLabel(c)))),
                                      ],
                                      child: Container(
                                        padding: const EdgeInsets.all(AppSpacing.s12),
                                        decoration: BoxDecoration(
                                          color: selectedCategory != null
                                              ? context.colors.primary.withValues(alpha: AppAlpha.a10)
                                              : context.colors.surface,
                                          borderRadius: BorderRadius.circular(AppRadius.r10),
                                          border: Border.all(
                                            color: selectedCategory != null
                                                ? context.colors.primary
                                                : context.colors.textHint.withValues(alpha: AppAlpha.a40),
                                          ),
                                        ),
                                        child: Icon(Icons.filter_list, size: AppIconSize.i20,
                                            color: selectedCategory != null ? context.colors.primary : context.colors.textSecondary),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.s12),
                                Expanded(
                                  child: filtered.isEmpty
                                      ? Center(child: Text(context.l10n.sales_noProductsFound))
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
                                              padding: const EdgeInsets.symmetric(vertical: AppSpacing.s6),
                                              child: Row(
                                                children: [
                                                  ProductThumbnail.square(
                                                    imageUrl: product.imageUrl,
                                                    size: 44,
                                                    backgroundColor: context.colors.primary.withValues(alpha: AppAlpha.a10),
                                                    iconColor: context.colors.primary,
                                                  ),
                                                  const SizedBox(width: AppSpacing.s12),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(product.name,
                                                            style: const TextStyle(fontWeight: AppFontWeight.semibold),
                                                            overflow: TextOverflow.ellipsis),
                                                        const SizedBox(height: AppSpacing.s2),
                                                        Text(
                                                          outOfStock
                                                              ? context.l10n.sales_outOfStock
                                                              : context.l10n.sales_availablePrice(remainingAvailable, context.l10n.productUnitLabel(product.unit), Money.unitPrice(product.sellPrice)),
                                                          style: TextStyle(
                                                            fontSize: AppFontSize.f12,
                                                            color: outOfStock ? context.colors.danger : context.colors.textMuted,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(width: AppSpacing.s8),
                                                  SizedBox(
                                                    width: 92,
                                                    child: outOfStock
                                                        ? const SizedBox.shrink()
                                                        : (qtyInSale == 0
                                                            ? Align(
                                                                alignment: Alignment.centerRight,
                                                                child: InkWell(
                                                                  borderRadius: BorderRadius.circular(AppRadius.r20),
                                                                  onTap: () => _dialogIncrement(product, setDialogState),
                                                                  child: Icon(Icons.add_circle, color: context.colors.primary, size: AppIconSize.i24),
                                                                ),
                                                              )
                                                            : Row(
                                                                mainAxisAlignment: MainAxisAlignment.end,
                                                                children: [
                                                                  InkWell(
                                                                    borderRadius: BorderRadius.circular(AppRadius.r20),
                                                                    onTap: () => _dialogDecrement(product, setDialogState),
                                                                    child: Icon(Icons.remove_circle_outline,
                                                                        color: context.colors.textSoft, size: AppIconSize.i22),
                                                                  ),
                                                                  SizedBox(
                                                                    width: 26,
                                                                    child: Text(
                                                                      '$qtyInSale',
                                                                      textAlign: TextAlign.center,
                                                                      style: const TextStyle(fontWeight: AppFontWeight.semibold),
                                                                    ),
                                                                  ),
                                                                  InkWell(
                                                                    borderRadius: BorderRadius.circular(AppRadius.r20),
                                                                    onTap: canAddMore
                                                                        ? () => _dialogIncrement(product, setDialogState)
                                                                        : null,
                                                                    child: Icon(Icons.add_circle,
                                                                        color: canAddMore ? context.colors.primary : context.colors.border,
                                                                        size: AppIconSize.i22),
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
    _saleId = Provider.of<SaleProvider>(context, listen: false).newSaleId();
    totalPaid = 0.0;
    totalPaidController.text = Money.decimal(totalPaid);
    if (widget.prefilledProduct != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _addProductToSale(widget.prefilledProduct!);
      });
    }
  }

  // Debounced, server-side client search - waits for a brief pause in
  // typing before actually querying Firestore, and only once at least
  // 2 characters have been entered (a single character matches too
  // broadly to be useful, and would fire a query on every keystroke
  // for no benefit). Replaces filtering clientProvider.clients, which
  // held the facility's entire client list in memory regardless of
  // how large it was.
  void _onClientSearchChanged(String query) {
    _clientSearchDebounce?.cancel();
    final trimmed = query.trim();

    if (trimmed.length < 2) {
      setState(() {
        _clientSearchResults = [];
        _isSearchingClients = false;
      });
      return;
    }

    setState(() => _isSearchingClients = true);
    _clientSearchDebounce = Timer(AppTimeouts.clientPickerDebounce, () async {
      final facilityId = Provider.of<FacilityProvider>(context, listen: false).selectedFacilityId;
      if (facilityId == null) {
        if (mounted) setState(() => _isSearchingClients = false);
        return;
      }
      try {
        final results =
            await Provider.of<ClientProvider>(context, listen: false).searchClientsByName(facilityId, trimmed);
        if (!mounted) return;
        setState(() {
          _clientSearchResults = results;
          _isSearchingClients = false;
        });
      } catch (e) {
        debugPrint('Client search error: $e');
        if (mounted) setState(() => _isSearchingClients = false);
      }
    });
  }

  @override
  void dispose() {
    _clientSearchDebounce?.cancel();
    clientController.dispose();
    totalPaidController.dispose();
    notesController.dispose();
    productSearchController.dispose();
    super.dispose();
  }

  // Mirrors deductSellableFIFO's own batch-selection logic exactly
  // (same sellableQty query, same soonest-expiry-first sort, same
  // "take" math) but read-only, run once per cart item and combined
  // into one list - a sale can include several products at once, so
  // this surfaces every expired portion across the whole cart in a
  // single check rather than one warning per item.
  Future<List<(String, String, int)>> _simulateExpiredSalePortion() async {
    final facilityProvider = Provider.of<FacilityProvider>(context, listen: false);
    final facilityId = facilityProvider.selectedFacility?['id'] ?? '';
    if (facilityId.isEmpty) return [];

    final now = DateTime.now();
    final expiredPortion = <(String, String, int)>[];

    for (final item in items) {
      final batchesRef = _db
          .collection(Collections.facilities)
          .doc(facilityId)
          .collection(Collections.products)
          .doc(item.productId)
          .collection(Collections.batches);

      final snap = await batchesRef.where('sellableQty', isGreaterThan: 0).get();
      if (snap.docs.isEmpty) continue;

      final candidates = snap.docs.toList()
        ..sort((a, b) {
          final aExp = a.data()['expiry'] as Timestamp?;
          final bExp = b.data()['expiry'] as Timestamp?;
          if (aExp == null && bExp == null) return 0;
          if (aExp == null) return 1;
          if (bExp == null) return -1;
          return aExp.compareTo(bExp);
        });

      int remaining = item.quantity;
      for (final doc in candidates) {
        if (remaining <= 0) break;
        final data = doc.data();
        final available = (data['sellableQty'] ?? 0) as int;
        if (available <= 0) continue;

        final take = remaining < available ? remaining : available;
        final expiry = data['expiry'] as Timestamp?;
        if (expiry != null && expiry.toDate().isBefore(now)) {
          expiredPortion.add((item.name, item.unit, take));
        }
        remaining -= take;
      }
    }
    return expiredPortion;
  }

  Future<bool?> _showExpiredSaleWarning(List<(String, String, int)> expiredPortion) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.r16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: context.colors.danger),
            SizedBox(width: AppSpacing.s8),
            Text(context.l10n.store_expiredStockTitle),
          ],
        ),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.l10n.sales_expiredSaleBody,
                  style: TextStyle(fontSize: AppFontSize.f13_5)),
              const SizedBox(height: AppSpacing.s10),
              ...expiredPortion.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.s4),
                    child: Text(context.l10n.sales_expiredPortionLine(e.$3, context.l10n.productUnitLabel(e.$2), e.$1),
                        style: TextStyle(fontSize: AppFontSize.f12_5, color: context.colors.dangerStrong)),
                  )),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.l10n.common_cancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: context.colors.danger, foregroundColor: context.colors.onPrimary),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.l10n.sales_sellAnyway),
          ),
        ],
      ),
    );
  }

  // --- Save Sale ---
  Future<void> _saveSale() async {
    if (_saveStarted) return;
    _saveStarted = true;
    try {
      await _recordSale();
    } finally {
      _saveStarted = false;
    }
  }

  Future<void> _recordSale() async {
    if (_isSaving) return; // guards against a double-tap firing two saves at once

    if (items.isEmpty) {
      AppFeedback.warning(L10n.current.sales_addItemFirst);
      return;
    }

    if (isWalkIn && totalPaid < totalAmount) {
      AppFeedback.warning(
        L10n.current.sales_partialNeedsRegistered,
        detail: L10n.current.sales_walkInPayInFull,
      );
      return;
    }

    if (!isWalkIn && selectedClient == null && totalPaid < totalAmount) {
      AppFeedback.warning(
        L10n.current.sales_partialNeedsClient,
        detail: L10n.current.sales_orChooseWalkIn,
      );
      return;
    }

    if (totalPaid > 0 && paymentMethod == null) {
      setState(() => _paymentMethodMissing = true);
      AppFeedback.warning(L10n.current.sales_selectPaymentMethod);
      return;
    }

    // Read before the awaits below: once the person has pressed save and
    // confirmed, the sale must still be recorded.
    final facilityProvider = Provider.of<FacilityProvider>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);
    final saleProvider = Provider.of<SaleProvider>(context, listen: false);

    final expiredPortion = await _simulateExpiredSalePortion();
    if (expiredPortion.isNotEmpty) {
      if (!mounted) return;
      final proceedAnyway = await _showExpiredSaleWarning(expiredPortion);
      if (proceedAnyway != true) return;
    }

    if (!mounted) return;
    setState(() => _isSaving = true);

    try {
      // Caps the recorded amount at the actual total whenever the sale
      // isn't on credit - covers both an exact cash payment and an
      // overpayment expecting change (e.g. Tsh 50,000 tendered on a
      // Tsh 45,000 sale): the excess is change handed back, not extra
      // sale revenue, so only the total itself should be recorded.
      if (!saleOnCredit) totalPaid = totalAmount;

      final facility = facilityProvider.selectedFacility;
      if (facility == null) {
        AppFeedback.info(L10n.current.common_noFacility);
        return;
      }

      final facilityId = facility['id'] ?? '';
      final user = authService.getCurrentUser();
      final soldById = user?.uid ?? '';
      String soldByName = 'Unknown';
      if (user != null) {
        try {
          final userDoc =
              await _db.collection(Collections.users).doc(user.uid).get();
          if (userDoc.exists) {
            soldByName = userDoc.data()?['fullName'] ?? 'Unknown';
          }
        } catch (_) {}
      }

      // Distributes the sale-wide discount proportionally across items
      // by each one's share of the subtotal, before anything below
      // computes off item.discount - profit does, and so do the Sales
      // screen, receipts, and the daily report's revenue-by-product
      // figure. Leaving every item's discount at its default of 0 (as
      // it stayed before this fix) meant all of those silently ignored
      // a discount that was genuinely applied to the sale's total.
      final itemsWithDiscount = subtotal > 0 && saleDiscount > 0
          ? items.map((item) {
              final itemSubtotal = item.unitPrice * item.quantity;
              final itemDiscount = saleDiscount * (itemSubtotal / subtotal);
              return item.copyWith(discount: itemDiscount);
            }).toList()
          : items;

      // --- Compute per-item realized/unrealized profit ---
      final List<SaleItem> updatedItems = itemsWithDiscount.map((item) {
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
          updatedItems.fold(0.0, (total, item) => total + item.profit);
      final realizedProfit =
          updatedItems.fold(0.0, (total, item) => total + item.realizedProfit);
      final unrealizedProfit =
          updatedItems.fold(0.0, (total, item) => total + item.unrealizedProfit);

      final sale = Sale(
        id: _saleId,
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

      // One transaction saves the sale with its stock, debt, payment, the
      // client's balance and both activity entries (SaleProvider.addSale).
      String? expiredStockNote;
      if (expiredPortion.isNotEmpty) {
        final unitsSummary = expiredPortion.map((e) => '${e.$3} ${e.$2} of ${e.$1}').join(', ');
        expiredStockNote = "Sale included expired stock ($unitsSummary), confirmed by $soldByName";
      }
      try {
        await saleProvider.addSale(sale, facilityId, expiredStockNote: expiredStockNote);
      } on InsufficientStockException catch (_, st) {
        // Same message as before the transaction, and no Retry: trying
        // again cannot make the stock appear. Nothing was saved.
        AppFeedback.error(L10n.current.sales_saveFailed,
            error: Exception('Sale could not be saved.'), stackTrace: st);
        return;
      }

      if (!mounted) return;

      // Message for sale type
      if (saleOnCredit) {
        AppFeedback.success(L10n.current.sales_savedWithDebt);
      } else {
        AppFeedback.success(L10n.current.sales_saved);
      }

      // Reset form
      setState(() {
        selectedClient = null;
        isWalkIn = true;
        items.clear();
        totalPaid = 0.0;
        saleDiscount = 0.0;
        paymentMethod = null;
        totalPaidController.text = Money.decimal(totalPaid);
        clientController.clear();
        // The next sale from this form is a new sale.
        _saleId = saleProvider.newSaleId();
      });

      Navigator.pop(context, true);
    } catch (e, st) {
      // Nothing was saved (one transaction), so Retry is safe: it reuses
      // the same sale id, and if the first try did land it is not repeated.
      AppFeedback.error(L10n.current.sales_saveFailed, error: e, stackTrace: st, onRetry: () {
        if (mounted) _saveSale();
      });
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final productProvider = Provider.of<ProductProvider>(context);

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Container(
          color: context.colors.brandSurface,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s20),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                Icon(Icons.shopping_cart_outlined, color: context.colors.onBrandSurface, size: AppIconSize.i22),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Text(context.l10n.sales_recordSale,
                      style: TextStyle(color: context.colors.onBrandSurface, fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f18)),
                ),
                if (widget.isModal)
                  IconButton(
                    icon: Icon(Icons.close, color: context.colors.onBrandSurface),
                    tooltip: context.l10n.common_close,
                    onPressed: () => Navigator.of(context).pop(),
                  )
                else
                  BackButton(color: context.colors.onBrandSurface),
              ],
            ),
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < AppBreakpoints.phoneNarrow;
          final isTwoColumn = constraints.maxWidth >= AppBreakpoints.formTwoColumn;
          return Stack(
            key: _stackKey,
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1080),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.s16),
                    child: isTwoColumn
                        ? IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 2, child: _buildLeftColumn(isNarrow)),
                                const SizedBox(width: AppSpacing.s16),
                                Expanded(flex: 1, child: _buildSaleSummarySidebar()),
                              ],
                            ),
                          )
                        : Column(
                            children: [
                              _buildLeftColumn(isNarrow),
                              const SizedBox(height: AppSpacing.s16),
                              _buildSaleSummarySidebar(),
                            ],
                          ),
                  ),
                ),
              ),
              _buildClientSuggestionsOverlay(),
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
      padding: EdgeInsets.fromLTRB(AppSpacing.s20, AppSpacing.s14, AppSpacing.s20, AppSpacing.s14 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(top: BorderSide(color: context.colors.textHint.withValues(alpha: AppAlpha.a15))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.close, size: AppIconSize.i16),
            label: Text(context.l10n.common_cancel),
            style: OutlinedButton.styleFrom(
              foregroundColor: context.colors.textPrimary,
              side: BorderSide(color: context.colors.textHint.withValues(alpha: AppAlpha.a40)),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s20, vertical: AppSpacing.s12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.r10)),
            ),
            onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          ),
          ElevatedButton(
            onPressed: _isSaving ? null : _saveSale,
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.primary,
              foregroundColor: context.colors.onPrimary,
              disabledBackgroundColor: context.colors.primary.withValues(alpha: AppAlpha.a50),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s22, vertical: AppSpacing.s12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.r10)),
            ),
            child: _isSaving
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: context.colors.onPrimary),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.receipt_long_outlined, size: AppIconSize.i16),
                      const SizedBox(width: AppSpacing.s8),
                      Text(context.l10n.sales_recordSale),
                      const SizedBox(width: AppSpacing.s6),
                      const Icon(Icons.arrow_forward, size: AppIconSize.i16),
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
        Icon(icon, size: AppIconSize.i18, color: context.colors.primary),
        const SizedBox(width: AppSpacing.s8),
        Text(title, style: TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f15, color: context.colors.primary)),
      ],
    );
  }

  Widget _buildSaleSummarySidebar() {
    final totalItemCount = items.fold<int>(0, (total, i) => total + i.quantity);
    final change = (totalPaid - totalAmount) > 0 ? (totalPaid - totalAmount) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.s16),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.r12),
            border: Border.all(color: context.colors.textHint.withValues(alpha: AppAlpha.a20)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeader(Icons.receipt_long_outlined, context.l10n.sales_summary),
              const SizedBox(height: AppSpacing.s14),
              _summaryRow(context.l10n.sales_totalItems, '$totalItemCount'),
              const SizedBox(height: AppSpacing.s10),
              _summaryRow(context.l10n.sales_subtotal, Money.plain(subtotal)),
              const SizedBox(height: AppSpacing.s10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(context.l10n.sales_discount, style: TextStyle(fontSize: AppFontSize.f13, color: context.colors.textSoft)),
                  Row(
                    children: [
                      Text(Money.plain(saleDiscount),
                          style: const TextStyle(fontWeight: AppFontWeight.semibold, fontSize: AppFontSize.f13)),
                      const SizedBox(width: AppSpacing.s6),
                      InkWell(
                        borderRadius: BorderRadius.circular(AppRadius.r4),
                        onTap: items.isEmpty ? null : _showEditDiscountDialog,
                        child: Icon(Icons.edit_outlined, size: AppIconSize.i16, color: items.isEmpty ? context.colors.border : context.colors.textHint),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.s16),
          decoration: BoxDecoration(
            color: context.colors.primary.withValues(alpha: AppAlpha.a05),
            borderRadius: BorderRadius.circular(AppRadius.r12),
            border: Border.all(color: context.colors.primary.withValues(alpha: AppAlpha.a20)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.l10n.sales_totalAmount, style: TextStyle(fontSize: AppFontSize.f12_5, color: context.colors.textSoft)),
              const SizedBox(height: AppSpacing.s4),
              Text(Money.format(totalAmount),
                  style: TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f24, color: context.colors.primary)),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.s16),
          decoration: BoxDecoration(
            color: context.colors.primary.withValues(alpha: AppAlpha.a05),
            borderRadius: BorderRadius.circular(AppRadius.r12),
            border: Border.all(color: context.colors.primary.withValues(alpha: AppAlpha.a15)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.credit_card_outlined, size: AppIconSize.i16, color: context.colors.primary),
                  const SizedBox(width: AppSpacing.s8),
                  Text(context.l10n.payments_method,
                      style: TextStyle(fontWeight: AppFontWeight.semibold, fontSize: AppFontSize.f13, color: context.colors.primary)),
                ],
              ),
              const SizedBox(height: AppSpacing.s10),
              PopupMenuButton<String>(
                initialValue: paymentMethod,
                onSelected: (method) => setState(() {
                  paymentMethod = method;
                  _paymentMethodMissing = false;
                }),
                itemBuilder: (context) => kPaymentMethods.map((method) {
                  return PopupMenuItem(
                    value: method,
                    child: Row(
                      children: [
                        Icon(iconForPaymentMethod(method), size: AppIconSize.i18, color: context.colors.primary),
                        const SizedBox(width: AppSpacing.s10),
                        Text(context.l10n.paymentMethodLabel(method)),
                      ],
                    ),
                  );
                }).toList(),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s14, vertical: AppSpacing.s12),
                  decoration: BoxDecoration(
                    color: context.colors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.r10),
                    border: Border.all(
                      color: _paymentMethodMissing ? context.colors.danger : context.colors.textHint.withValues(alpha: AppAlpha.a30),
                      width: _paymentMethodMissing ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(paymentMethod == null ? Icons.payment_outlined : iconForPaymentMethod(paymentMethod!),
                          size: AppIconSize.i18, color: _paymentMethodMissing ? context.colors.danger : context.colors.primary),
                      const SizedBox(width: AppSpacing.s10),
                      Expanded(
                        child: Text(
                          paymentMethod == null ? context.l10n.sales_selectMethod : context.l10n.paymentMethodLabel(paymentMethod!),
                          style: TextStyle(color: _paymentMethodMissing ? context.colors.danger : (paymentMethod == null ? context.colors.textMuted : null)),
                        ),
                      ),
                      Icon(Icons.expand_more, size: AppIconSize.i18, color: context.colors.textMuted),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s16),
        Text(context.l10n.sales_amountReceivedLabel(AppDefaults.currencySymbol), style: const TextStyle(fontWeight: AppFontWeight.semibold, fontSize: AppFontSize.f13)),
        const SizedBox(height: AppSpacing.s6),
        TextFormField(
          controller: totalPaidController,
          enabled: items.isNotEmpty,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, ThousandsSeparatorInputFormatter()],
          decoration: InputDecoration(
            hintText: '0.00',
            filled: true,
            fillColor: context.colors.surface,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.s12, horizontal: AppSpacing.s12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.r10),
              borderSide: BorderSide(color: context.colors.textHint.withValues(alpha: AppAlpha.a40)),
            ),
          ),
          onChanged: (val) {
            final paid = parseThousands(val);
            setState(() => totalPaid = paid);
          },
        ),
        const SizedBox(height: AppSpacing.s14),
        Text(context.l10n.sales_changeLabel(AppDefaults.currencySymbol), style: const TextStyle(fontWeight: AppFontWeight.semibold, fontSize: AppFontSize.f13)),
        const SizedBox(height: AppSpacing.s6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s12),
          decoration: BoxDecoration(
            color: context.colors.textHint.withValues(alpha: AppAlpha.a10),
            borderRadius: BorderRadius.circular(AppRadius.r10),
            border: Border.all(color: context.colors.textHint.withValues(alpha: AppAlpha.a30)),
          ),
          child: Text(Money.plain(change), style: TextStyle(color: context.colors.textMuted)),
        ),
      ],
    );
  }

  Widget _summaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: AppFontSize.f13, color: context.colors.textSoft)),
        Text(value, style: const TextStyle(fontWeight: AppFontWeight.semibold, fontSize: AppFontSize.f13)),
      ],
    );
  }

  Widget _buildLeftColumn(bool isNarrow) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildClientInfoCard(isNarrow),
        const SizedBox(height: AppSpacing.s16),
        _buildProductsCard(isNarrow),
        const SizedBox(height: AppSpacing.s16),
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
              hintText: context.l10n.services_clientSearchHint,
              hintStyle: const TextStyle(fontSize: AppFontSize.f14),
              filled: true,
              fillColor: context.colors.surface,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.s12, horizontal: AppSpacing.s12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.r10),
                borderSide: BorderSide(color: context.colors.textHint.withValues(alpha: AppAlpha.a40)),
              ),
              prefixIcon: Icon(Icons.person_outline, color: context.colors.textSecondary),
            ),
            onTap: () => setState(() {
              _showClientSuggestions = clientController.text.trim().length >= 2;
            }),
            onChanged: (val) {
              setState(() {
                selectedClient = null; // typing clears any prior selection
                _showClientSuggestions = val.trim().length >= 2;
              });
              _onClientSearchChanged(val);
            },
          ),
        ),
        const SizedBox(width: AppSpacing.s8),
        IconButton(
          icon: Icon(Icons.add, color: context.colors.onPrimary),
          tooltip: context.l10n.services_addNewClient,
          padding: const EdgeInsets.all(AppSpacing.s10),
          style: ButtonStyle(
            shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.r10))),
            backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
              if (states.contains(WidgetState.hovered)) return context.colors.accent;
              return context.colors.primary;
            }),
          ),
          onPressed: () {
            showAddClientScreen(context);
          },
        ),
      ],
    );

    final walkInCard = InkWell(
      borderRadius: BorderRadius.circular(AppRadius.r10),
      onTap: () => setState(() {
        isWalkIn = !isWalkIn;
        selectedClient = null;
        clientController.clear();
        totalPaid = 0;
        totalPaidController.text = Money.decimal(totalPaid);
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s10),
        decoration: BoxDecoration(
          color: isWalkIn ? context.colors.primary.withValues(alpha: AppAlpha.a05) : context.colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.r10),
          border: Border.all(color: isWalkIn ? context.colors.primary : context.colors.textHint.withValues(alpha: AppAlpha.a30)),
        ),
        child: Row(
          children: [
            Icon(Icons.person_outline, size: AppIconSize.i22, color: context.colors.primary),
            const SizedBox(width: AppSpacing.s8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(context.l10n.sales_walkInCustomer,
                      style: TextStyle(fontWeight: AppFontWeight.semibold, fontSize: AppFontSize.f14, color: context.colors.primary)),
                  Text(context.l10n.sales_noClientSelected, style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textMuted)),
                ],
              ),
            ),
            // A group of one: it only fires when walk-in is off (tapping it
            // when already on does nothing), as the single Radio did.
            RadioGroup<bool>(
              groupValue: isWalkIn,
              onChanged: (_) => setState(() {
                isWalkIn = !isWalkIn;
                selectedClient = null;
                clientController.clear();
                totalPaid = 0;
                totalPaidController.text = Money.decimal(totalPaid);
              }),
              child: Radio<bool>(
                value: true,
                activeColor: context.colors.primary,
                materialTapTargetSize: AppTapTarget.size(context),
                visualDensity: AppTapTarget.density(context),
              ),
            ),
          ],
        ),
      ),
    );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.r12),
        border: Border.all(color: context.colors.textHint.withValues(alpha: AppAlpha.a20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(Icons.shopping_cart_outlined, context.l10n.clients_infoSection),
          const SizedBox(height: AppSpacing.s12),
          Text(context.l10n.services_selectClientRequired, style: const TextStyle(fontWeight: AppFontWeight.semibold, fontSize: AppFontSize.f13)),
          const SizedBox(height: AppSpacing.s6),
          isNarrow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    searchRow,
                    const SizedBox(height: AppSpacing.s10),
                    walkInCard,
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: searchRow),
                    const SizedBox(width: AppSpacing.s10),
                    Expanded(flex: 2, child: walkInCard),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildProductsCard(bool isNarrow) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.r12),
        border: Border.all(color: context.colors.textHint.withValues(alpha: AppAlpha.a20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(Icons.shopping_cart_outlined, context.l10n.reports_tabProducts),
          const SizedBox(height: AppSpacing.s12),
          Row(
            key: _productFieldRowKey,
            children: [
              Expanded(
                child: TextField(
                  controller: productSearchController,
                  decoration: InputDecoration(
                    hintText: context.l10n.sales_productSearchHint,
                    hintStyle: const TextStyle(fontSize: AppFontSize.f14),
                    filled: true,
                    fillColor: context.colors.surface,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.s12, horizontal: AppSpacing.s12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.r10),
                      borderSide: BorderSide(color: context.colors.textHint.withValues(alpha: AppAlpha.a40)),
                    ),
                    prefixIcon: Icon(Icons.search, color: context.colors.textSecondary),
                  ),
                  onTap: () => setState(() {
                    _showProductSuggestions = productSearchController.text.trim().isNotEmpty;
                  }),
                  onChanged: (val) => setState(() {
                    _showProductSuggestions = val.trim().isNotEmpty;
                  }),
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              OutlinedButton.icon(
                icon: const Icon(Icons.grid_view_outlined, size: AppIconSize.i16),
                label: Text(context.l10n.sales_browseProducts),
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.colors.primary,
                  side: BorderSide(color: context.colors.primary.withValues(alpha: AppAlpha.a40)),
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s14, vertical: AppSpacing.s12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.r10)),
                ),
                onPressed: _showBrowseProductsDialog,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s16),
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
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s32),
        child: Column(
          children: [
            Icon(Icons.playlist_add_outlined, size: AppIconSize.i40, color: context.colors.border),
            const SizedBox(height: AppSpacing.s10),
            Text(context.l10n.sales_noProductsYet,
                style: TextStyle(fontWeight: AppFontWeight.semibold, color: context.colors.textMuted)),
            const SizedBox(height: AppSpacing.s4),
            Text(context.l10n.sales_addProductsHint,
                style: TextStyle(fontSize: AppFontSize.f12_5, color: context.colors.textHint)),
          ],
        ),
      ),
    );
  }

  // The Qty column of the wide items table, header and rows alike. A size
  // (above the spacing ladder), kept exact.
  static const double _qtyColumnWidth = 96;

  TextStyle get _tableHeaderStyle =>
      TextStyle(fontSize: AppFontSize.f11_5, fontWeight: AppFontWeight.bold, color: context.colors.textSecondary);

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
    final dateFormat = AppDateFormat.date;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s10, vertical: AppSpacing.s8),
          decoration: BoxDecoration(
            color: context.colors.textHint.withValues(alpha: AppAlpha.a05),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.r8)),
          ),
          child: Row(
            children: [
              SizedBox(width: AppSpacing.s22, child: Text('#', style: _tableHeaderStyle)),
              Expanded(flex: 3, child: Text(context.l10n.reports_colProduct, style: _tableHeaderStyle)),
              Expanded(flex: 2, child: Text(context.l10n.sales_colBatchNo, style: _tableHeaderStyle)),
              Expanded(flex: 2, child: Text(context.l10n.batch_expiryDate, style: _tableHeaderStyle)),
              Expanded(flex: 2, child: Text(context.l10n.sales_colUnitPrice(AppDefaults.currencySymbol), style: _tableHeaderStyle)),
              SizedBox(width: _qtyColumnWidth, child: Text(context.l10n.sales_colQty, style: _tableHeaderStyle, textAlign: TextAlign.center)),
              Expanded(flex: 2, child: Text(context.l10n.sales_colTotal(AppDefaults.currencySymbol), style: _tableHeaderStyle)),
              SizedBox(width: AppSpacing.s32, child: SizedBox.shrink()),
            ],
          ),
        ),
        ...items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final product = _findProduct(productProvider, item.productId);
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s10, vertical: AppSpacing.s10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: context.colors.textHint.withValues(alpha: AppAlpha.a10))),
            ),
            child: Row(
              children: [
                SizedBox(width: AppSpacing.s22, child: Text('${index + 1}', style: const TextStyle(fontSize: AppFontSize.f13))),
                Expanded(
                  flex: 3,
                  child: Text(item.name,
                      style: const TextStyle(fontSize: AppFontSize.f13, fontWeight: AppFontWeight.semibold),
                      overflow: TextOverflow.ellipsis),
                ),
                Expanded(
                  flex: 2,
                  child: Text(product?.batchNo ?? '-',
                      style: TextStyle(fontSize: AppFontSize.f12_5, color: context.colors.textMuted)),
                ),
                Expanded(
                  flex: 2,
                  child: Text(product?.expiry != null ? dateFormat.format(product!.expiry!) : '-',
                      style: TextStyle(fontSize: AppFontSize.f12_5, color: context.colors.textMuted)),
                ),
                Expanded(
                  flex: 2,
                  child: Text(Money.unitPricePlain(item.unitPrice), style: const TextStyle(fontSize: AppFontSize.f13)),
                ),
                SizedBox(
                  width: _qtyColumnWidth,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(AppRadius.r12),
                        onTap: () => _changeItemQuantity(index, -1),
                        child: Icon(Icons.remove_circle_outline, size: AppIconSize.i18, color: context.colors.textMuted),
                      ),
                      SizedBox(
                        width: 26,
                        child: Text('${item.quantity}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: AppFontSize.f13, fontWeight: AppFontWeight.semibold)),
                      ),
                      InkWell(
                        borderRadius: BorderRadius.circular(AppRadius.r12),
                        onTap: () => _changeItemQuantity(index, 1),
                        child: Icon(Icons.add_circle_outline, size: AppIconSize.i18, color: context.colors.primary),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    Money.plain((item.unitPrice * item.quantity) - item.discount),
                    style: const TextStyle(fontSize: AppFontSize.f13, fontWeight: AppFontWeight.semibold),
                  ),
                ),
                SizedBox(
                  width: AppTapTarget.extent(context, 32),
                  child: IconButton(
                    icon: const Icon(Icons.delete_outline, size: AppIconSize.i18),
                    color: context.colors.danger,
                    padding: EdgeInsets.zero,
                    constraints: AppTapTarget.iconConstraints(context),
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
    final dateFormat = AppDateFormat.date;

    return Column(
      children: items.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        final product = _findProduct(productProvider, item.productId);
        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.r12)),
          color: context.colors.background,
          margin: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.s14, AppSpacing.s12, AppSpacing.s8, AppSpacing.s12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(item.name,
                          style: const TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f15),
                          overflow: TextOverflow.ellipsis),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: AppIconSize.i20),
                      color: context.colors.danger,
                      onPressed: () => _removeItemAt(index),
                    ),
                  ],
                ),
                if (product?.batchNo != null || product?.expiry != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.s6),
                    child: Text(
                      [
                        if (product?.batchNo != null) context.l10n.sales_batchShort(product!.batchNo!),
                        if (product?.expiry != null) context.l10n.sales_expShort(dateFormat.format(product!.expiry!)),
                      ].join('  •  '),
                      style: TextStyle(fontSize: AppFontSize.f11_5, color: context.colors.textMuted),
                    ),
                  ),
                Row(
                  children: [
                    Text(Money.unitPrice(item.unitPrice),
                        style: TextStyle(fontSize: AppFontSize.f13, color: context.colors.textSoft)),
                    const Spacer(),
                    InkWell(
                      onTap: () => _changeItemQuantity(index, -1),
                      child: Icon(Icons.remove_circle_outline, size: AppIconSize.i20, color: context.colors.textMuted),
                    ),
                    SizedBox(
                      width: 30,
                      child: Text('${item.quantity}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: AppFontSize.f14, fontWeight: AppFontWeight.semibold)),
                    ),
                    InkWell(
                      onTap: () => _changeItemQuantity(index, 1),
                      child: Icon(Icons.add_circle_outline, size: AppIconSize.i20, color: context.colors.primary),
                    ),
                    const SizedBox(width: AppSpacing.s10),
                    Text(Money.format((item.unitPrice * item.quantity) - item.discount),
                        style: const TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f14)),
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
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.r12),
        border: Border.all(color: context.colors.textHint.withValues(alpha: AppAlpha.a20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(Icons.description_outlined, context.l10n.common_notes),
          const SizedBox(height: AppSpacing.s12),
          TextFormField(
            controller: notesController,
            maxLines: 2,
            maxLength: 200,
            textCapitalization: TextCapitalization.sentences,
            inputFormatters: [SentenceCapitalizationFormatter()],
            decoration: InputDecoration(
              hintText: context.l10n.sales_notesHint,
              filled: true,
              fillColor: context.colors.surface,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.s10, horizontal: AppSpacing.s12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.r10),
                borderSide: BorderSide(color: context.colors.textHint.withValues(alpha: AppAlpha.a40)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClientSuggestionsOverlay() {
    final trimmedQuery = clientController.text.trim();
    if (!_showClientSuggestions || trimmedQuery.length < 2) {
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

    if (_clientSearchResults.isEmpty && !_isSearchingClients) return const SizedBox.shrink();

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
        elevation: AppElevation.e6,
        borderRadius: BorderRadius.circular(AppRadius.r8),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 260),
          decoration: BoxDecoration(
            border: Border.all(color: context.colors.border),
            borderRadius: BorderRadius.circular(AppRadius.r8),
            color: context.colors.background,
          ),
          child: _isSearchingClients && _clientSearchResults.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.s16),
                  child: Center(child: SizedBox(width: AppSpacing.s18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
                )
              : ListView(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  children: _clientSearchResults.map((client) {
                    return ListTile(
                      title: Text(client.name),
                      hoverColor: context.colors.accent.withValues(alpha: AppAlpha.a15),
                      onTap: () {
                        setState(() {
                          selectedClient = client;
                          clientController.text = client.name;
                          _showClientSuggestions = false;
                          isWalkIn = false;
                          totalPaid = 0;
                          totalPaidController.text = Money.decimal(totalPaid);
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
        elevation: AppElevation.e6,
        borderRadius: BorderRadius.circular(AppRadius.r8),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 260),
          decoration: BoxDecoration(
            border: Border.all(color: context.colors.border),
            borderRadius: BorderRadius.circular(AppRadius.r8),
            color: context.colors.background,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            children: matches.map((product) {
              return ListTile(
                leading: ProductThumbnail.square(
                  imageUrl: product.imageUrl,
                  size: 40,
                  backgroundColor: context.colors.primary.withValues(alpha: AppAlpha.a10),
                  iconColor: context.colors.primary,
                ),
                title: Text(product.name),
                subtitle: Text(context.l10n.sales_availablePrice(product.sellableQty, context.l10n.productUnitLabel(product.unit), Money.unitPrice(product.sellPrice))),
                hoverColor: context.colors.accent.withValues(alpha: AppAlpha.a15),
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
  await showAdaptiveForm(
    context,
    barrierLabel: context.l10n.sales_recordSale,
    builder: (isModal) => AddSaleScreen(isModal: isModal, prefilledProduct: product),
  );
}
