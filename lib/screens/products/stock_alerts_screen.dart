import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/product_provider.dart';
import '../../providers/user_role_provider.dart';
import '../../models/product.dart';
import '../../models/product_batch.dart';
import '../../models/notification_model.dart';
import '../../widgets/product_thumbnail.dart';
import '../store/release_to_shop_flow.dart';
import 'add_batch_screen.dart';
import 'view_batches_screen.dart';
import 'move_expired_to_stock_dialog.dart';
import '../../config/app_limits.dart';
import '../../config/app_date_format.dart';
import '../../theme/app_text.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_context.dart';
import '../../theme/app_breakpoints.dart';

/// What kind of thing needs attention. Declared in the order they're
/// shown - most urgent first.
enum StockAlertKind { depleted, expired, lowStock, expiringSoon, restockShelf }

/// One thing that needs attention right now, for one product.
class StockAlert {
  final StockAlertKind kind;
  final Product product;
  const StockAlert(this.kind, this.product);
}

/// What needs attention with stock RIGHT NOW - out of stock, low stock,
/// expired or nearly-expired stock that's actually on hand, and a shelf
/// that needs topping up from the store.
///
/// This is worked out from the live product list the app already holds
/// in memory, not from stored notification documents. Those are
/// written once, at the moment a product's status *changes*, and
/// disappear when read - so a product that was already low or out of
/// stock never showed up here at all, while the bell's dot (which looks
/// at current stock) stayed lit: red with nothing to see. Both now
/// share [currentAlerts], so the dot is red exactly when this list has
/// something in it. It also means opening the list needs no network
/// round-trip and no spinner, and it updates live as stock moves.
///
/// How this differs from the Products / Stock Store screens: those are
/// the catalogue - every product, one row each, for browsing and
/// managing. This is a to-do list - only products with a problem, one
/// row per *problem* (a product can appear twice), most urgent first,
/// each with the one action that fixes it.
///
/// Deliberately not included: "Reorder Soon" (a planning hint, already
/// shown as a status on each product row, not something to report) and
/// the expiry of a product with nothing left on hand (an old date left
/// over from a previous batch isn't actionable).
///
/// General facility-wide notifications (subscriptions, payments, debts,
/// system messages) live in their own separate screen - see
/// NotificationsScreen in screens/dashboard/.
class StockAlertsScreen extends StatelessWidget {
  final bool isDropdown;
  const StockAlertsScreen({super.key, this.isDropdown = false});

  static const int expiryWarningDays = 30;

  /// How many alerts the compact dropdown shows before pointing to the
  /// full screen.
  static const int dropdownLimit = 8;

  /// Which alerts apply to a single product right now.
  static List<StockAlertKind> _kindsFor(Product p, DateTime now) {
    final status = p.primaryStatus;

    // A brand-new product that has never carried any stock isn't an
    // alert - there's nothing that ran out.
    if (status == ProductStockStatus.neverStocked) return const [];

    if (status == ProductStockStatus.depleted) return const [StockAlertKind.depleted];

    // From here down the product has stock on hand.
    final kinds = <StockAlertKind>[];

    final expiry = p.expiry;
    if (expiry != null) {
      if (expiry.isBefore(now)) {
        kinds.add(StockAlertKind.expired);
      } else if (expiry.difference(now).inDays <= expiryWarningDays) {
        kinds.add(StockAlertKind.expiringSoon);
      }
    }
    if (status == ProductStockStatus.lowStock) kinds.add(StockAlertKind.lowStock);
    if (p.hasRestockShelfAlert) kinds.add(StockAlertKind.restockShelf);
    return kinds;
  }

  /// Cheap yes/no for the bell's red dot - same rule as [currentAlerts],
  /// without building or sorting the list.
  static bool hasAnyAlert(List<Product> products) {
    final now = DateTime.now();
    return products.any((p) => _kindsFor(p, now).isNotEmpty);
  }

  /// Everything that needs attention, most urgent first.
  static List<StockAlert> currentAlerts(List<Product> products) {
    final now = DateTime.now();
    final alerts = <StockAlert>[];
    for (final p in products) {
      for (final kind in _kindsFor(p, now)) {
        alerts.add(StockAlert(kind, p));
      }
    }
    alerts.sort((a, b) {
      final byKind = a.kind.index.compareTo(b.kind.index);
      if (byKind != 0) return byKind;
      if (a.kind == StockAlertKind.lowStock) {
        // Closest to running out first.
        final byStock = a.product.totalStock.compareTo(b.product.totalStock);
        if (byStock != 0) return byStock;
      }
      return a.product.name.toLowerCase().compareTo(b.product.name.toLowerCase());
    });
    return alerts;
  }

  // ----- presentation per kind -----

  static String _title(StockAlertKind k) {
    switch (k) {
      case StockAlertKind.depleted:
        return 'Out of Stock';
      case StockAlertKind.expired:
        return 'Expired';
      case StockAlertKind.lowStock:
        return 'Low Stock';
      case StockAlertKind.expiringSoon:
        return 'Expiring Soon';
      case StockAlertKind.restockShelf:
        return 'Restock Shelf';
    }
  }

  // Same colors and icons the notification system uses for these same
  // situations, so an alert looks the same wherever it appears.
  static Color _color(StockAlertKind k, AppColors colors) {
    switch (k) {
      case StockAlertKind.depleted:
        return NotificationType.criticalStock.color;
      case StockAlertKind.expired:
        return NotificationType.productExpiry.color;
      case StockAlertKind.lowStock:
        return NotificationType.lowStock.color;
      case StockAlertKind.expiringSoon:
        return colors.warning;
      case StockAlertKind.restockShelf:
        return NotificationType.restockShelf.color;
    }
  }

  static IconData _icon(StockAlertKind k) {
    switch (k) {
      case StockAlertKind.depleted:
        return NotificationType.criticalStock.icon;
      case StockAlertKind.expired:
      case StockAlertKind.expiringSoon:
        return NotificationType.productExpiry.icon;
      case StockAlertKind.lowStock:
        return NotificationType.lowStock.icon;
      case StockAlertKind.restockShelf:
        return NotificationType.restockShelf.icon;
    }
  }

  // One-line summary, used by the compact bell dropdown.
  static String _message(StockAlert a) {
    final p = a.product;
    final dateFormat = AppDateFormat.date;
    switch (a.kind) {
      case StockAlertKind.depleted:
        return '${p.name} - Shelf: ${p.sellableQty} · Store: ${p.stockQty}';
      case StockAlertKind.lowStock:
        return '${p.name} - Shelf: ${p.sellableQty} · Store: ${p.stockQty}';
      case StockAlertKind.expired:
        return '${p.name} - expired ${dateFormat.format(p.expiry!)} · ${p.totalStock} ${p.unit} on hand';
      case StockAlertKind.expiringSoon:
        final days = p.expiry!.difference(DateTime.now()).inDays;
        final when = days <= 0 ? 'today' : 'in $days day${days == 1 ? '' : 's'}';
        return '${p.name} - expires $when (${dateFormat.format(p.expiry!)}) · ${p.totalStock} ${p.unit} on hand';
      case StockAlertKind.restockShelf:
        return '${p.name} - ${p.sellableQty} on shelf · ${p.stockQty} in store';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isDropdown) {
      // Watches the live product list - the alerts update the moment
      // stock changes, with nothing to fetch.
      final alerts = currentAlerts(Provider.of<ProductProvider>(context).products);
      return _buildDropdownChrome(context, alerts);
    }

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        backgroundColor: context.colors.surface,
        foregroundColor: context.colors.textPrimary,
        elevation: AppElevation.e1,
        centerTitle: true,
        toolbarHeight: 72,
        title: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Product Alerts', style: TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f19, color: context.colors.textPrimary)),
            Text('Stock and expiry problems that need action', style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textSecondary)),
          ],
        ),
      ),
      body: const _AlertsBody(),
    );
  }

  // Compact desktop dropdown, anchored near the bell rather than a
  // full screen - no Scaffold/AppBar of its own (the dropdown
  // container the caller wraps this in provides the surface and
  // shadow), just a small header row and a short list beneath it.
  Widget _buildDropdownChrome(BuildContext context, List<StockAlert> alerts) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s14, AppSpacing.s8, AppSpacing.s14),
          decoration: BoxDecoration(
            color: context.colors.primary,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.r12)),
          ),
          child: Row(
            children: [
              Text(
                'Product Alerts',
                style: TextStyle(color: context.colors.onPrimary, fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f15),
              ),
              if (alerts.isNotEmpty) ...[
                const SizedBox(width: AppSpacing.s8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: AppSpacing.s2),
                  decoration: BoxDecoration(color: context.colors.warning, borderRadius: BorderRadius.circular(AppRadius.r10)),
                  child: Text('${alerts.length}',
                      style: TextStyle(color: context.colors.onPrimary, fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f11)),
                ),
              ],
              const Spacer(),
              IconButton(
                icon: Icon(Icons.close, color: context.colors.onPrimary, size: AppIconSize.i20),
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.s12),
            child: _buildDropdownList(context, alerts),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownList(BuildContext context, List<StockAlert> alerts) {
    // The dropdown already sits inside its own SingleChildScrollView,
    // which offers unbounded height to its child - so this must size
    // itself naturally rather than try to fill/centre in a viewport.
    if (alerts.isEmpty) return Center(child: _caughtUpContent(context));

    final shown = alerts.take(dropdownLimit).toList();

    // Section headers between kinds, so a long list stays scannable.
    final entries = <Object>[];
    StockAlertKind? currentKind;
    for (final a in shown) {
      if (a.kind != currentKind) {
        currentKind = a.kind;
        entries.add(_SectionHeader(a.kind, alerts.where((x) => x.kind == a.kind).length));
      }
      entries.add(a);
    }

    final footer = Center(
      child: TextButton(
        onPressed: () {
          final navigator = Navigator.of(context);
          navigator.pop();
          navigator.push(MaterialPageRoute(builder: (_) => const StockAlertsScreen()));
        },
        style: TextButton.styleFrom(foregroundColor: context.colors.primary),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              alerts.length > shown.length ? 'View all ${alerts.length} alerts' : 'View all alerts',
              style: const TextStyle(fontSize: AppFontSize.f13, fontWeight: AppFontWeight.semibold),
            ),
            const SizedBox(width: AppSpacing.s4),
            const Icon(Icons.arrow_forward, size: AppIconSize.i16),
          ],
        ),
      ),
    );

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(AppSpacing.s4, AppSpacing.s4, AppSpacing.s4, AppSpacing.s8),
      itemCount: entries.length + 1,
      itemBuilder: (context, index) {
        if (index == entries.length) return footer;
        final entry = entries[index];
        if (entry is _SectionHeader) return _buildSectionHeader(context, entry);
        return _buildAlertTile(context, entry as StockAlert);
      },
    );
  }

  Widget _buildSectionHeader(BuildContext context, _SectionHeader h) {
    final color = _color(h.kind, context.colors);
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.s2, AppSpacing.s6, AppSpacing.s2, AppSpacing.s8),
      child: Row(
        children: [
          Text(
            _title(h.kind).toUpperCase(),
            style: TextStyle(fontSize: AppFontSize.f11_5, fontWeight: AppFontWeight.bold, letterSpacing: 0.6, color: color),
          ),
          const SizedBox(width: AppSpacing.s6),
          Text('${h.count}', style: TextStyle(fontSize: AppFontSize.f11_5, color: context.colors.textMuted)),
        ],
      ),
    );
  }

  Widget _buildAlertTile(BuildContext context, StockAlert alert) {
    final color = _color(alert.kind, context.colors);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s8),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.r10),
        boxShadow: [
          BoxShadow(color: context.colors.shadow.withValues(alpha: AppAlpha.a05), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.s8),
              decoration: BoxDecoration(color: color.withValues(alpha: AppAlpha.a10), shape: BoxShape.circle),
              child: Icon(_icon(alert.kind), color: color, size: AppIconSize.i18),
            ),
            const SizedBox(width: AppSpacing.s10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_title(alert.kind), style: const TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f13_5)),
                  const SizedBox(height: AppSpacing.s2),
                  Text(_message(alert), style: TextStyle(color: context.colors.textSoft, fontSize: AppFontSize.f12_5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shared "nothing to report" content - used by the dropdown and by the
/// full screen when there are no alerts at all.
Widget _caughtUpContent(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(AppSpacing.s32),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.s20),
          decoration: BoxDecoration(
            color: context.colors.success.withValues(alpha: AppAlpha.a10),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.check_circle_outline, color: context.colors.success, size: AppIconSize.i48),
        ),
        const SizedBox(height: AppSpacing.s16),
        const Text("You're all caught up!", style: TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f17)),
        const SizedBox(height: AppSpacing.s6),
        Text(
          'No stock alerts right now.',
          textAlign: TextAlign.center,
          style: TextStyle(color: context.colors.textMuted, fontSize: AppFontSize.f13),
        ),
      ],
    ),
  );
}

class _SectionHeader {
  final StockAlertKind kind;
  final int count;
  const _SectionHeader(this.kind, this.count);
}

// ======================================================================
// The full Product Alerts screen: summary cards, one filter row, and the
// table - laid out like the Sales screen so the two feel like siblings.
// ======================================================================

class _AlertsBody extends StatefulWidget {
  const _AlertsBody();

  @override
  State<_AlertsBody> createState() => _AlertsBodyState();
}

class _AlertsBodyState extends State<_AlertsBody> {

  // Card order as requested. The table itself always lists the most
  // urgent first (see StockAlertsScreen.currentAlerts).
  static const List<StockAlertKind> _cardOrder = [
    StockAlertKind.lowStock,
    StockAlertKind.depleted,
    StockAlertKind.restockShelf,
    StockAlertKind.expiringSoon,
    StockAlertKind.expired,
  ];

  static const Map<StockAlertKind, String> _cardHint = {
    StockAlertKind.lowStock: 'Below minimum level',
    StockAlertKind.depleted: 'Nothing left',
    StockAlertKind.restockShelf: 'Store has stock',
    StockAlertKind.expiringSoon: 'Within 30 days',
    StockAlertKind.expired: 'Still on hand',
  };

  final TextEditingController _searchController = TextEditingController();
  final DateFormat _dateFormat = AppDateFormat.date;

  String _searchQuery = '';
  StockAlertKind? _kindFilter; // null = all kinds
  String _categoryFilter = 'All';
  int _page = 1;
  int _pageSize = AppLimits.tablePageSize;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _categoryOf(Product p) => p.category.isNotEmpty ? p.category : 'Uncategorized';

  void _resetFilters() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _kindFilter = null;
      _categoryFilter = 'All';
      _page = 1;
    });
  }

  // ----- actions: one per kind of problem -----

  void _restock(Product p) => showAddBatchScreen(context, product: p);

  void _viewBatches(Product p) =>
      showViewBatchesScreen(context, product: p, moveToStockLabel: 'Remove from Sellable');

  // Pre-fills the release quantity with how many the shelf is short by
  // (never more than the store actually has).
  Future<void> _moveToShelf(Product p) {
    final deficit = p.effectiveShelfMinLevel - p.sellableQty;
    final upper = p.stockQty < 1 ? 1 : p.stockQty;
    final suggested = deficit < 1 ? 1 : (deficit > upper ? upper : deficit);
    return releaseProductToShop(context, p, initialQuantity: suggested);
  }

  // If exactly one batch is both expired and still on the shelf, go
  // straight to the remove-with-reason prompt for it. Anything else
  // (several, or none on the shelf - e.g. the expired stock is in the
  // store) is a judgement call, so open the batch list instead.
  Future<void> _removeExpired(Product p) async {
    List<ProductBatch> expiredOnShelf = const [];
    try {
      final batches = await Provider.of<ProductProvider>(context, listen: false)
          .streamBatchesForProduct(p.facilityId, p.id)
          .first;
      final now = DateTime.now();
      expiredOnShelf =
          batches.where((b) => b.sellableQty > 0 && b.expiry != null && b.expiry!.isBefore(now)).toList();
    } catch (_) {
      expiredOnShelf = const [];
    }
    if (!mounted) return;
    if (expiredOnShelf.length == 1) {
      await promptQuantityAndMoveToStock(context, p, expiredOnShelf.first, actionLabel: 'Remove from Sellable');
    } else {
      await showViewBatchesScreen(context, product: p, moveToStockLabel: 'Remove from Sellable');
    }
  }

  ({String label, IconData icon, VoidCallback? onPressed, String? tooltip}) _actionFor(StockAlert a, bool isAdmin) {
    final p = a.product;
    switch (a.kind) {
      case StockAlertKind.depleted:
      case StockAlertKind.lowStock:
        return (label: 'Restock', icon: Icons.add_box_outlined, onPressed: () => _restock(p), tooltip: null);
      case StockAlertKind.restockShelf:
        return (
          label: 'Move to shelf',
          icon: Icons.move_up,
          // Same rule as the Stock Store's own Release button.
          onPressed: isAdmin ? () => _moveToShelf(p) : null,
          tooltip: isAdmin ? null : 'Only an admin can move stock to the shelf',
        );
      case StockAlertKind.expiringSoon:
        return (label: 'View batches', icon: Icons.layers_outlined, onPressed: () => _viewBatches(p), tooltip: null);
      case StockAlertKind.expired:
        return (
          label: 'Remove expired',
          icon: Icons.remove_circle_outline,
          onPressed: () => _removeExpired(p),
          tooltip: null,
        );
    }
  }

  // ----- text for a row -----

  (String, String) _details(StockAlert a) {
    final p = a.product;
    switch (a.kind) {
      case StockAlertKind.depleted:
      case StockAlertKind.lowStock:
        return ('${p.totalStock} in stock', 'Min. required: ${p.effectiveLowStockThreshold}');
      case StockAlertKind.restockShelf:
        return ('${p.sellableQty} on shelf', 'Shelf minimum: ${p.effectiveShelfMinLevel}');
      case StockAlertKind.expiringSoon:
        final days = p.expiry!.difference(DateTime.now()).inDays;
        final when = days <= 0 ? 'Expires today' : 'Expires in $days day${days == 1 ? '' : 's'}';
        return (when, '${_dateFormat.format(p.expiry!)} · ${p.totalStock} ${p.unit} on hand');
      case StockAlertKind.expired:
        return ('Expired ${_dateFormat.format(p.expiry!)}', '${p.totalStock} ${p.unit} on hand');
    }
  }

  String _subtitleOf(Product p) {
    final supplier = p.supplier;
    return (supplier != null && supplier.trim().isNotEmpty) ? '${supplier.trim()} · ${p.unit}' : p.unit;
  }

  bool _matchesSearch(StockAlert a, String q) {
    final p = a.product;
    return p.name.toLowerCase().contains(q) ||
        _categoryOf(p).toLowerCase().contains(q) ||
        (p.supplier ?? '').toLowerCase().contains(q) ||
        StockAlertsScreen._title(a.kind).toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final products = Provider.of<ProductProvider>(context).products;
    final isAdmin = Provider.of<UserRoleProvider>(context).isAdmin;
    final all = StockAlertsScreen.currentAlerts(products);

    final counts = <StockAlertKind, int>{for (final k in StockAlertKind.values) k: 0};
    for (final a in all) {
      counts[a.kind] = (counts[a.kind] ?? 0) + 1;
    }

    final categories = <String>{for (final a in all) _categoryOf(a.product)}.toList()..sort();
    // The chosen category can vanish if its last alert gets resolved.
    final category = (_categoryFilter == 'All' || categories.contains(_categoryFilter)) ? _categoryFilter : 'All';

    final q = _searchQuery.toLowerCase();
    final filtered = all.where((a) {
      if (_kindFilter != null && a.kind != _kindFilter) return false;
      if (category != 'All' && _categoryOf(a.product) != category) return false;
      if (q.isNotEmpty && !_matchesSearch(a, q)) return false;
      return true;
    }).toList();

    final hasActiveFilters = _searchQuery.isNotEmpty || _kindFilter != null || category != 'All';

    final total = filtered.length;
    final totalPages = total == 0 ? 1 : ((total + _pageSize - 1) ~/ _pageSize);
    // Resolving alerts can shrink the list under the page being viewed.
    final page = _page > totalPages ? totalPages : _page;
    final pageItems = filtered.skip((page - 1) * _pageSize).take(_pageSize).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s16, AppSpacing.s16, 0),
          child: _buildCards(counts),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s12, AppSpacing.s16, 0),
          child: _buildFilters(categories, category, hasActiveFilters),
        ),
        Expanded(
          child: all.isEmpty
              ? Center(child: SingleChildScrollView(child: _caughtUpContent(context)))
              : filtered.isEmpty
                  ? _buildNoMatches()
                  : _buildResults(pageItems, isAdmin),
        ),
        if (all.isNotEmpty) _buildPaginationBar(total: total, page: page, totalPages: totalPages),
      ],
    );
  }

  // ==================== CARDS ====================

  Widget _buildCards(Map<StockAlertKind, int> counts) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= AppBreakpoints.fiveColumnCards ? 5 : 3;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: 90,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: _cardOrder.length,
          itemBuilder: (context, index) {
            final kind = _cardOrder[index];
            return _alertCard(kind, counts[kind] ?? 0);
          },
        );
      },
    );
  }

  // Same small card as the Sales screen's, but tappable: it filters the
  // table to that kind, and tapping it again clears the filter.
  Widget _alertCard(StockAlertKind kind, int count) {
    final color = StockAlertsScreen._color(kind, context.colors);
    final selected = _kindFilter == kind;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.r12),
      side: BorderSide(
        color: selected ? color.withValues(alpha: AppAlpha.a70) : context.colors.textHint.withValues(alpha: AppAlpha.a15),
        width: selected ? 1.5 : 1,
      ),
    );
    return Material(
      color: selected ? color.withValues(alpha: AppAlpha.a05) : context.colors.surface,
      shape: shape,
      elevation: AppElevation.e1,
      shadowColor: context.colors.shadow.withValues(alpha: AppAlpha.a05),
      child: InkWell(
        customBorder: shape,
        onTap: () => setState(() {
          _kindFilter = selected ? null : kind;
          _page = 1;
        }),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s10),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.topLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration:
                          BoxDecoration(color: color.withValues(alpha: AppAlpha.a10), borderRadius: BorderRadius.circular(AppRadius.r7)),
                      child: Icon(StockAlertsScreen._icon(kind), color: color, size: AppIconSize.i14),
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    Text('$count', style: const TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f16)),
                  ],
                ),
                const SizedBox(height: AppSpacing.s4),
                Text(StockAlertsScreen._title(kind), style: TextStyle(fontSize: AppFontSize.f11_5, color: context.colors.textMuted)),
                Text(_cardHint[kind] ?? '', style: TextStyle(fontSize: AppFontSize.f10_5, color: context.colors.textDisabled)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==================== FILTERS ====================

  Widget _buildFilters(List<String> categories, String category, bool hasActiveFilters) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.r10),
      borderSide: BorderSide(color: context.colors.textHint.withValues(alpha: AppAlpha.a30)),
    );

    final search = TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Search by product, category or alert...',
        hintStyle: const TextStyle(fontSize: AppFontSize.f13),
        prefixIcon: const Icon(Icons.search, size: AppIconSize.i20),
        filled: true,
        fillColor: context.colors.surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.s12, horizontal: AppSpacing.s12),
        border: border,
        enabledBorder: border,
        suffixIcon: _searchController.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.clear, size: AppIconSize.i18),
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                    _page = 1;
                  });
                },
              ),
      ),
      onChanged: (val) => setState(() {
        _searchQuery = val.trim();
        _page = 1;
      }),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < AppBreakpoints.filterRow;
        final reset = hasActiveFilters ? TextButton(onPressed: _resetFilters, child: const Text('Reset')) : null;

        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              search,
              const SizedBox(height: AppSpacing.s10),
              Row(
                children: [
                  Expanded(child: _categoryDropdown(categories, category, expand: true)),
                  if (reset != null) ...[const SizedBox(width: AppSpacing.s10), reset],
                ],
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(flex: 3, child: search),
            const SizedBox(width: AppSpacing.s10),
            _categoryDropdown(categories, category),
            if (reset != null) ...[const SizedBox(width: AppSpacing.s10), reset],
          ],
        );
      },
    );
  }

  Widget _categoryDropdown(List<String> categories, String value, {bool expand = false}) {
    final items = ['All', ...categories];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s10),
      height: 44,
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.r10),
        border: Border.all(color: context.colors.textHint.withValues(alpha: AppAlpha.a30)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: expand,
          icon: Icon(Icons.arrow_drop_down, size: AppIconSize.i18, color: context.colors.primary),
          style: TextStyle(color: context.colors.textPrimary, fontSize: AppFontSize.f13),
          items: items
              .map((v) => DropdownMenuItem(value: v, child: Text('Category: $v', overflow: TextOverflow.ellipsis)))
              .toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _categoryFilter = val;
                _page = 1;
              });
            }
          },
        ),
      ),
    );
  }

  // ==================== TABLE ====================

  Widget _buildNoMatches() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: AppIconSize.i56, color: context.colors.textDisabled),
          const SizedBox(height: AppSpacing.s12),
          Text('No alerts match your filters', style: TextStyle(fontSize: AppFontSize.f17, color: context.colors.textMuted)),
          const SizedBox(height: AppSpacing.s8),
          TextButton(onPressed: _resetFilters, child: const Text('Reset filters')),
        ],
      ),
    );
  }

  Widget _buildResults(List<StockAlert> items, bool isAdmin) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < AppBreakpoints.resultsTable) {
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s12, AppSpacing.s16, AppSpacing.s12),
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.s10),
            itemBuilder: (context, index) => _buildNarrowCard(items[index], isAdmin),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.colors.textHint.withValues(alpha: AppAlpha.a20)))),
              child: Row(
                children: [
                  _headerCell('Product', flex: 4),
                  _headerCell('Category', flex: 2),
                  _headerCell('Alert', flex: 2),
                  _headerCell('Details', flex: 3),
                  _headerCell('Store / Shelf', flex: 2),
                  _headerCell('Action', flex: 3),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: items.length,
                separatorBuilder: (context, index) => Divider(height: 1, color: context.colors.textHint.withValues(alpha: AppAlpha.a10)),
                itemBuilder: (context, index) => _buildRow(items[index], isAdmin),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _headerCell(String label, {required int flex}) {
    return Expanded(
      flex: flex,
      child: Text(label, style: TextStyle(fontSize: AppFontSize.f12, fontWeight: AppFontWeight.semibold, color: context.colors.textMuted)),
    );
  }

  Widget _thumb(Product p, double size) {
    return ProductThumbnail.square(
      imageUrl: p.imageUrl,
      size: size,
      backgroundColor: context.colors.primary.withValues(alpha: AppAlpha.a10),
      iconColor: context.colors.primary,
    );
  }

  Widget _alertChip(StockAlertKind kind) {
    final color = StockAlertsScreen._color(kind, context.colors);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: AppSpacing.s4),
      decoration: BoxDecoration(color: color.withValues(alpha: AppAlpha.a10), borderRadius: BorderRadius.circular(AppRadius.r10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(StockAlertsScreen._icon(kind), size: AppIconSize.i14, color: color),
          const SizedBox(width: AppSpacing.s4),
          Text(
            StockAlertsScreen._title(kind),
            style: TextStyle(color: color, fontSize: AppFontSize.f11_5, fontWeight: AppFontWeight.semibold),
          ),
        ],
      ),
    );
  }

  Widget _categoryChip(String category) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: AppSpacing.s4),
      decoration: BoxDecoration(color: context.colors.primary.withValues(alpha: AppAlpha.a10), borderRadius: BorderRadius.circular(AppRadius.r10)),
      child: Text(
        category,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: context.colors.primary, fontSize: AppFontSize.f11_5, fontWeight: AppFontWeight.semibold),
      ),
    );
  }

  Widget _actionButton(StockAlert a, bool isAdmin) {
    final action = _actionFor(a, isAdmin);
    final button = OutlinedButton.icon(
      onPressed: action.onPressed,
      icon: Icon(action.icon, size: AppIconSize.i16),
      label: Text(action.label, style: const TextStyle(fontSize: AppFontSize.f12_5)),
      style: OutlinedButton.styleFrom(
        foregroundColor: context.colors.primary,
        side: BorderSide(color: context.colors.primary.withValues(alpha: action.onPressed == null ? AppAlpha.a20 : AppAlpha.a40)),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s8),
        minimumSize: const Size(0, 34),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.r10)),
      ),
    );
    return action.tooltip == null ? button : Tooltip(message: action.tooltip!, child: button);
  }

  Widget _twoLine(String primary, String secondary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(primary, style: const TextStyle(fontSize: AppFontSize.f13, fontWeight: AppFontWeight.medium)),
        const SizedBox(height: AppSpacing.s2),
        Text(secondary, style: TextStyle(fontSize: AppFontSize.f11_5, color: context.colors.textHint)),
      ],
    );
  }

  // Wide layout: one table row.
  Widget _buildRow(StockAlert a, bool isAdmin) {
    final p = a.product;
    final color = StockAlertsScreen._color(a.kind, context.colors);
    final details = _details(a);

    return Container(
      key: ValueKey('${a.kind.name}-${p.id}'),
      // Coloured bar down the left edge - severity at a glance.
      decoration: BoxDecoration(border: Border(left: BorderSide(color: color, width: 4))),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 4,
            child: Row(
              children: [
                _thumb(p, 40),
                const SizedBox(width: AppSpacing.s10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: AppFontSize.f13_5, fontWeight: AppFontWeight.bold)),
                      const SizedBox(height: AppSpacing.s2),
                      Text(_subtitleOf(p),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: AppFontSize.f11_5, color: context.colors.textHint)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(alignment: Alignment.centerLeft, child: _categoryChip(_categoryOf(p))),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(fit: BoxFit.scaleDown, child: _alertChip(a.kind)),
            ),
          ),
          Expanded(flex: 3, child: _twoLine(details.$1, details.$2)),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Store: ${p.stockQty}', style: const TextStyle(fontSize: AppFontSize.f12_5)),
                const SizedBox(height: AppSpacing.s2),
                Text('Shelf: ${p.sellableQty}', style: const TextStyle(fontSize: AppFontSize.f12_5)),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(fit: BoxFit.scaleDown, child: _actionButton(a, isAdmin)),
            ),
          ),
        ],
      ),
    );
  }

  // Narrow layout (phones): the same information as a card per alert.
  Widget _buildNarrowCard(StockAlert a, bool isAdmin) {
    final p = a.product;
    final color = StockAlertsScreen._color(a.kind, context.colors);
    final details = _details(a);

    return Container(
      key: ValueKey('${a.kind.name}-${p.id}'),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.r12),
        border: Border.all(color: context.colors.textHint.withValues(alpha: AppAlpha.a15)),
      ),
      // Clipped so the severity bar down the left follows the card's
      // rounded corners.
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.r10),
        child: Container(
          decoration: BoxDecoration(
            color: context.colors.surface,
            border: Border(left: BorderSide(color: color, width: 4)),
          ),
          padding: const EdgeInsets.all(AppSpacing.s12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _thumb(p, 44),
                  const SizedBox(width: AppSpacing.s10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: AppFontSize.f14, fontWeight: AppFontWeight.bold)),
                        const SizedBox(height: AppSpacing.s2),
                        Text(_subtitleOf(p),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: AppFontSize.f11_5, color: context.colors.textHint)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [_alertChip(a.kind), _categoryChip(_categoryOf(p))],
              ),
              const SizedBox(height: AppSpacing.s10),
              _twoLine(details.$1, details.$2),
              const SizedBox(height: AppSpacing.s6),
              Text('Store: ${p.stockQty}  ·  Shelf: ${p.sellableQty}',
                  style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textSoft)),
              const SizedBox(height: AppSpacing.s10),
              Align(alignment: Alignment.centerRight, child: _actionButton(a, isAdmin)),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== PAGINATION ====================

  Widget _buildPaginationBar({required int total, required int page, required int totalPages}) {
    final start = total == 0 ? 0 : (page - 1) * _pageSize + 1;
    final end = (page * _pageSize) > total ? total : page * _pageSize;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: context.colors.textHint.withValues(alpha: AppAlpha.a20)))),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 4,
        children: [
          Text(
            total == 0 ? 'No alerts' : 'Showing $start to $end of $total alert${total == 1 ? '' : 's'}',
            style: TextStyle(fontSize: AppFontSize.f12_5, color: context.colors.textMuted),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _pageSize,
                  items: const [10, 25, 50]
                      .map((n) => DropdownMenuItem(value: n, child: Text('$n per page')))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _pageSize = val;
                        _page = 1;
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.s16),
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: page > 1 ? () => setState(() => _page = page - 1) : null,
              ),
              Text('Page $page', style: const TextStyle(fontSize: AppFontSize.f13)),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: page < totalPages ? () => setState(() => _page = page + 1) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
