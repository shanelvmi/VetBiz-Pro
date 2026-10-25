import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../providers/facility_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/user_role_provider.dart';
import '../../utils/notification_seen_tracker.dart';
import '../../models/notification_model.dart';
import '../../widgets/announcement_message.dart';
import '../../widgets/notification_row.dart';
import '../../services/notification_feed.dart';
import '../../ui/feedback/app_feedback.dart';
import '../../data/collections.dart';
import '../../config/app_limits.dart';
import '../../config/app_timeouts.dart';
import '../../config/app_ranges.dart';
import '../../config/app_date_format.dart';
import '../../theme/app_text.dart';
import '../../theme/app_dimens.dart';
import '../../theme/theme_context.dart';
import '../../theme/app_breakpoints.dart';
import '../../l10n/l10n.dart';

/// Everything that needs your attention, facility-wide - subscription
/// status, urgent announcements, payments, debts, and system messages.
/// Stock/product alerts have their own dedicated screen now (see
/// StockAlertsScreen in screens/products/) - this one is deliberately
/// general-purpose, so it no longer needs to know about a "locked
/// category" at all.
class NotificationsScreen extends StatefulWidget {
  final bool isDropdown;

  /// The data behind the screen; built from the providers when null (tests
  /// pass one on a fake Firestore). NOTIF-2c.
  final NotificationFeedController? controller;

  const NotificationsScreen({super.key, this.isDropdown = false, this.controller});


  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  // My notifications and my own state (NOTIF-2c): the controller builds the
  // rows through NotificationPolicy; this screen only shows them and passes
  // on what the person does. Null when no facility or nobody is signed in.
  NotificationFeedController? _feed;
  bool _ownsFeed = false;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _urgentStream;

  // Full screen only: the search/date/category filters and pagination.
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  DateTimeRange? _dateRange;
  NotificationCategory? _selectedCategory; // null = "All"
  String _statusFilter = 'All'; // 'All' | 'Unread' | 'Read'

  // Re-checks every minute which notifications have expired or outlived
  // their lifetime, so they leave by themselves while this screen is open.
  Timer? _expiryTicker;
  int _currentPage = 1;
  int _pageSize = AppLimits.tablePageSize;

  bool get _isLoading => _feed?.isLoading ?? false;
  Object? get _error => _feed?.error;
  List<NotificationItem> get _items => _feed?.items ?? const [];

  @override
  void initState() {
    super.initState();
    _feed = widget.controller ?? _feedFromProviders();
    _ownsFeed = widget.controller == null && _feed != null;
    final feed = _feed;
    if (feed != null) {
      feed.addListener(_onFeedChanged);
      feed.start();
      // Created once: a new stream on every build would reset the builder.
      _urgentStream = feed.firestore
          .collection(Collections.publicAnnouncements)
          .where('urgent', isEqualTo: true)
          .snapshots();
    }
    _expiryTicker = Timer.periodic(AppTimeouts.noticeExpiryTick, (_) => _feed?.refresh());
    // The device's "last viewed" time, for the bell's blink on urgent
    // announcements and pending assistants (dashboard_screen.dart).
    NotificationSeenTracker.markViewedNow();
  }

  NotificationFeedController? _feedFromProviders() {
    final facilityId = Provider.of<FacilityProvider>(context, listen: false).selectedFacilityId;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (facilityId == null || uid == null) return null;
    final subscription = Provider.of<SubscriptionProvider>(context, listen: false);
    final role = Provider.of<UserRoleProvider>(context, listen: false);
    return NotificationFeedController(
      firestore: FirebaseFirestore.instance,
      facilityId: facilityId,
      uid: uid,
      // Re-read on every rebuild, so the list follows a change of role.
      isAdmin: () => role.isAdmin,
      subscription: () => SubscriptionFacts.of(subscription),
      subscriptionChanges: Listenable.merge([subscription, role]),
      window: widget.isDropdown ? AppLimits.dashboardNotifications : AppLimits.notificationsWindow,
    );
  }

  void _onFeedChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    _feed?.removeListener(_onFeedChanged);
    if (_ownsFeed) _feed?.dispose();
    _expiryTicker?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // ==================== ACTIONS (all per person) ====================

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } catch (e, st) {
      AppFeedback.error(L10n.current.notifications_updateFailed, error: e, stackTrace: st);
    }
  }

  void _markAllAsRead() => _run(() => _feed!.markAllRead());

  // Search + date range + status + category card, applied together - the
  // flat, filtered result the table and its pagination both work from.
  List<NotificationItem> get _filteredHistory {
    return _items.where((i) {
      final n = i.notification;
      if (_selectedCategory != null && n.category != _selectedCategory) return false;
      if (_statusFilter == 'Unread' && i.isRead) return false;
      if (_statusFilter == 'Read' && !i.isRead) return false;

      if (_dateRange != null && n.createdAt != null) {
        final day = DateTime(n.createdAt!.year, n.createdAt!.month, n.createdAt!.day);
        final start = DateTime(_dateRange!.start.year, _dateRange!.start.month, _dateRange!.start.day);
        final end = DateTime(_dateRange!.end.year, _dateRange!.end.month, _dateRange!.end.day);
        if (day.isBefore(start) || day.isAfter(end)) return false;
      }

      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.trim().toLowerCase();
        if (!n.title.toLowerCase().contains(q) &&
            !n.message.toLowerCase().contains(q) &&
            !_categoryLabel(n.type.category).toLowerCase().contains(q)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  bool get _hasActiveFilters =>
      _searchQuery.trim().isNotEmpty || _dateRange != null || _selectedCategory != null || _statusFilter != 'All';

  void _resetFilters() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _dateRange = null;
      _selectedCategory = null;
      _statusFilter = 'All';
      _currentPage = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final nothingToShow = !_isLoading && _error == null && _items.isEmpty;

    if (widget.isDropdown) {
      return _buildDropdownChrome(nothingToShow);
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
            Text(context.l10n.common_notifications, style: TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f19, color: context.colors.textPrimary)),
            Text(context.l10n.notifications_subtitle, style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textSecondary)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(AppSpacing.s24), child: Text(context.l10n.notifications_loadFailed('$_error'))))
              : _buildFullScreenBody(),
    );
  }

  // ======================================================================
  // FULL SCREEN - summary cards, one filter row, and a full-width table,
  // laid out like the Sales and Product Alerts screens.
  // ======================================================================


  // The filter cards, in display order - the same categories the old tab
  // strip offered; "All" is simply no card selected.
  static const List<NotificationCategory> _cardCategories = [
    NotificationCategory.critical,
    NotificationCategory.stock,
    NotificationCategory.payment,
    NotificationCategory.debt,
    NotificationCategory.system,
  ];

  String _categoryName(NotificationCategory c) {
    final l = context.l10n;
    switch (c) {
      case NotificationCategory.critical:
        return l.notifications_catCritical;
      case NotificationCategory.stock:
        return l.notifications_catStock;
      case NotificationCategory.payment:
        return l.notifications_catPayments;
      case NotificationCategory.debt:
        return l.notifications_catDebts;
      case NotificationCategory.system:
        return l.notifications_catSystem;
      case NotificationCategory.other:
        return l.notifications_catUpdates;
    }
  }

  // One notification's category, in the singular (the table and the search):
  // NotificationType.categoryLabel's words, in the current language.
  String _categoryLabel(NotificationCategory c) {
    final l = context.l10n;
    switch (c) {
      case NotificationCategory.critical:
        return l.notifications_catCritical;
      case NotificationCategory.stock:
        return l.notifications_catStock;
      case NotificationCategory.payment:
        return l.notifications_catPayment;
      case NotificationCategory.debt:
        return l.notifications_catDebt;
      case NotificationCategory.system:
        return l.notifications_catSystem;
      case NotificationCategory.other:
        return l.notifications_catUpdate;
    }
  }

  IconData _categoryIcon(NotificationCategory c) {
    switch (c) {
      case NotificationCategory.critical:
        return Icons.error_outline;
      case NotificationCategory.stock:
        return Icons.inventory_2_outlined;
      case NotificationCategory.payment:
        return Icons.payments_outlined;
      case NotificationCategory.debt:
        return Icons.account_balance_wallet_outlined;
      case NotificationCategory.system:
        return Icons.campaign_outlined;
      case NotificationCategory.other:
        return Icons.notifications_none;
    }
  }

  Color _categoryColor(NotificationCategory c) {
    switch (c) {
      case NotificationCategory.critical:
        return context.colors.danger;
      case NotificationCategory.stock:
        return context.colors.warning;
      case NotificationCategory.payment:
        return context.colors.success;
      case NotificationCategory.debt:
        return const Color(0xFFE59A00);
      case NotificationCategory.system:
        return context.colors.info;
      case NotificationCategory.other:
        return context.colors.textHint;
    }
  }

  Widget _buildFullScreenBody() {
    final all = _items;

    final counts = <NotificationCategory, int>{for (final c in NotificationCategory.values) c: 0};
    final unreadCounts = <NotificationCategory, int>{for (final c in NotificationCategory.values) c: 0};
    for (final i in all) {
      final n = i.notification;
      counts[n.category] = (counts[n.category] ?? 0) + 1;
      if (!i.isRead) unreadCounts[n.category] = (unreadCounts[n.category] ?? 0) + 1;
    }

    final filtered = _filteredHistory;
    final total = filtered.length;
    final totalPages = total == 0 ? 1 : ((total + _pageSize - 1) ~/ _pageSize);
    // Notifications expiring can shrink the list under the page being viewed.
    final page = _currentPage > totalPages ? totalPages : _currentPage;
    final pageItems = filtered.skip((page - 1) * _pageSize).take(_pageSize).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s16, AppSpacing.s16, 0),
          child: _buildCategoryCards(counts, unreadCounts),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s12, AppSpacing.s16, 0),
          child: _buildFilters(),
        ),
        Expanded(
          child: all.isEmpty
              ? _buildEmptyState()
              : filtered.isEmpty
                  ? _buildNoMatches()
                  : _buildResults(pageItems),
        ),
        if (all.isNotEmpty) _buildPaginationBar(total: total, page: page, totalPages: totalPages),
      ],
    );
  }

  // ==================== CARDS ====================

  Widget _buildCategoryCards(Map<NotificationCategory, int> counts, Map<NotificationCategory, int> unread) {
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
          itemCount: _cardCategories.length,
          itemBuilder: (context, index) {
            final c = _cardCategories[index];
            return _categoryCard(c, counts[c] ?? 0, unread[c] ?? 0);
          },
        );
      },
    );
  }

  // Same small card as Sales / Product Alerts: tapping filters the table
  // to that category, tapping again clears it.
  Widget _categoryCard(NotificationCategory category, int count, int unread) {
    final color = _categoryColor(category);
    final selected = _selectedCategory == category;
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
          _selectedCategory = selected ? null : category;
          _currentPage = 1;
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
                      child: Icon(_categoryIcon(category), color: color, size: AppIconSize.i14),
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    Text('$count', style: const TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f16)),
                  ],
                ),
                const SizedBox(height: AppSpacing.s4),
                Text(_categoryName(category), style: TextStyle(fontSize: AppFontSize.f11_5, color: context.colors.textMuted)),
                Text(
                  unread > 0 ? context.l10n.notifications_unreadCount(unread) : context.l10n.notifications_allRead,
                  style: TextStyle(
                    fontSize: AppFontSize.f10_5,
                    color: unread > 0 ? color : context.colors.textDisabled,
                    fontWeight: unread > 0 ? AppFontWeight.semibold : AppFontWeight.regular,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==================== FILTERS ====================

  Widget _buildFilters() {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.r10),
      borderSide: BorderSide(color: context.colors.textHint.withValues(alpha: AppAlpha.a30)),
    );

    final search = TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: context.l10n.notifications_searchHint,
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
                    _currentPage = 1;
                  });
                },
              ),
      ),
      onChanged: (value) => setState(() {
        _searchQuery = value;
        _currentPage = 1;
      }),
    );

    final hasUnread = _feed?.hasUnread ?? false;
    final markAll = OutlinedButton.icon(
      onPressed: hasUnread ? _markAllAsRead : null,
      icon: const Icon(Icons.done_all, size: AppIconSize.i16),
      label: Text(context.l10n.notifications_markAllRead),
      style: OutlinedButton.styleFrom(
        foregroundColor: context.colors.primary,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s14, vertical: AppSpacing.s12),
        side: BorderSide(color: context.colors.textHint.withValues(alpha: AppAlpha.a30)),
      ),
    );
    final reset = _hasActiveFilters ? TextButton(onPressed: _resetFilters, child: Text(context.l10n.common_reset)) : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < AppBreakpoints.twoPane) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              search,
              const SizedBox(height: AppSpacing.s10),
              Row(
                children: [
                  Expanded(child: _dateRangeButton(expand: true)),
                  const SizedBox(width: AppSpacing.s10),
                  Expanded(child: _statusDropdown(expand: true)),
                ],
              ),
              const SizedBox(height: AppSpacing.s10),
              Row(
                children: [
                  if (reset != null) reset,
                  const Spacer(),
                  markAll,
                ],
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(flex: 3, child: search),
            const SizedBox(width: AppSpacing.s10),
            _dateRangeButton(),
            const SizedBox(width: AppSpacing.s10),
            _statusDropdown(),
            if (reset != null) ...[const SizedBox(width: AppSpacing.s10), reset],
            const SizedBox(width: AppSpacing.s10),
            markAll,
          ],
        );
      },
    );
  }


  Widget _statusDropdown({bool expand = false}) {
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
          value: _statusFilter,
          isExpanded: expand,
          icon: Icon(Icons.arrow_drop_down, size: AppIconSize.i18, color: context.colors.primary),
          style: TextStyle(color: context.colors.textPrimary, fontSize: AppFontSize.f13),
          // The values stay 'All' / 'Unread' / 'Read' (the filter compares
          // them); only what is shown is localised.
          items: const ['All', 'Unread', 'Read']
              .map((v) => DropdownMenuItem(value: v, child: Text(context.l10n.common_filterValue(context.l10n.common_status, _statusLabel(v)))))
              .toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _statusFilter = val;
                _currentPage = 1;
              });
            }
          },
        ),
      ),
    );
  }

  String _statusLabel(String value) => switch (value) {
        'Unread' => context.l10n.notifications_unread,
        'Read' => context.l10n.notifications_read,
        _ => context.l10n.common_all,
      };

  // [expand] is for the narrow layout, where this sits in a half-width slot
  // and its label must be able to shorten rather than overflow. In the wide
  // row it has no width limit, so it just sizes to its label.
  Widget _dateRangeButton({bool expand = false}) {
    final label = _dateRange == null
        ? context.l10n.common_filterValue(context.l10n.common_date, context.l10n.common_all)
        : '${AppDateFormat.dateShort.format(_dateRange!.start)} - ${AppDateFormat.dateNoPadY.format(_dateRange!.end)}';
    final labelText = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: AppFontSize.f13, color: context.colors.textPrimary),
    );
    final tappable = InkWell(
      borderRadius: BorderRadius.circular(AppRadius.r10),
      onTap: _pickDateRange,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s10, vertical: AppSpacing.s12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today_outlined, size: AppIconSize.i16, color: context.colors.primary),
            const SizedBox(width: AppSpacing.s8),
            if (expand) Flexible(child: labelText) else labelText,
          ],
        ),
      ),
    );
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.r10),
        border: Border.all(color: context.colors.textHint.withValues(alpha: AppAlpha.a30)),
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: [
          if (expand) Expanded(child: tappable) else tappable,
          if (_dateRange != null)
            IconButton(
              icon: const Icon(Icons.close, size: AppIconSize.i16),
              tooltip: context.l10n.notifications_clearDateRange,
              visualDensity: VisualDensity.compact,
              onPressed: () => setState(() {
                _dateRange = null;
                _currentPage = 1;
              }),
            ),
        ],
      ),
    );
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(AppRanges.year),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
    );
    if (picked != null) {
      setState(() {
        _dateRange = picked;
        _currentPage = 1;
      });
    }
  }

  // ==================== TABLE ====================

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none, size: AppIconSize.i64, color: context.colors.textDisabled),
          const SizedBox(height: AppSpacing.s16),
          Text(context.l10n.notifications_empty, style: TextStyle(fontSize: AppFontSize.f18, color: context.colors.textMuted)),
          const SizedBox(height: AppSpacing.s4),
          Text(context.l10n.notifications_emptyHint,
              style: TextStyle(fontSize: AppFontSize.f13, color: context.colors.textHint)),
        ],
      ),
    );
  }

  Widget _buildNoMatches() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: AppIconSize.i56, color: context.colors.textDisabled),
          const SizedBox(height: AppSpacing.s12),
          Text(context.l10n.notifications_noMatches, style: TextStyle(fontSize: AppFontSize.f17, color: context.colors.textMuted)),
          const SizedBox(height: AppSpacing.s8),
          TextButton(onPressed: _resetFilters, child: Text(context.l10n.common_resetFilters)),
        ],
      ),
    );
  }

  Widget _buildResults(List<NotificationItem> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < AppBreakpoints.resultsTable) {
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s12, AppSpacing.s16, AppSpacing.s12),
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.s10),
            itemBuilder: (context, index) => _buildNarrowCard(items[index]),
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
                  _headerCell(context.l10n.notifications_colNotification, flex: 6),
                  _headerCell(context.l10n.common_category, flex: 2),
                  _headerCell(context.l10n.common_date, flex: 2),
                  _headerCell(context.l10n.common_status, flex: 1),
                  // Over the more menu.
                  const SizedBox(width: kMinInteractiveDimension),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: items.length,
                separatorBuilder: (context, index) => Divider(height: 1, color: context.colors.textHint.withValues(alpha: AppAlpha.a10)),
                itemBuilder: (context, index) => _buildRow(items[index]),
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

  Widget _typeIcon(FacilityNotification n, double size) {
    final color = n.type.colorIn(context.colors);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color.withValues(alpha: AppAlpha.a10), shape: BoxShape.circle),
      child: Icon(n.type.icon, color: color, size: size * 0.5),
    );
  }

  Widget _categoryChip(FacilityNotification n) {
    final color = _categoryColor(n.category);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: AppSpacing.s4),
      decoration: BoxDecoration(color: color.withValues(alpha: AppAlpha.a10), borderRadius: BorderRadius.circular(AppRadius.r10)),
      child: Text(
        _categoryLabel(n.type.category),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: color, fontSize: AppFontSize.f11_5, fontWeight: AppFontWeight.semibold),
      ),
    );
  }

  Widget _statusChip(NotificationItem i) {
    final color = i.isRead ? context.colors.textHint : context.colors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: AppSpacing.s4),
      decoration: BoxDecoration(color: color.withValues(alpha: AppAlpha.a10), borderRadius: BorderRadius.circular(AppRadius.r10)),
      child: Text(
        i.isRead ? context.l10n.notifications_read : context.l10n.notifications_statusNew,
        style: TextStyle(color: color, fontSize: AppFontSize.f11_5, fontWeight: AppFontWeight.semibold),
      ),
    );
  }

  // Wide layout: one table row.
  Widget _buildRow(NotificationItem i) {
    final n = i.notification;
    final unread = !i.isRead;
    final created = n.createdAt;

    return Container(
      key: ValueKey(n.id),
      // Coloured bar down the left edge, tinted while unread.
      decoration: BoxDecoration(
        color: unread ? context.colors.primary.withValues(alpha: AppAlpha.a05) : null,
        border: Border(left: BorderSide(color: _categoryColor(n.category), width: 4)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 6,
            child: Row(
              children: [
                _typeIcon(n, 36),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        n.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: AppFontSize.f13_5, fontWeight: unread ? AppFontWeight.bold : AppFontWeight.semibold),
                      ),
                      const SizedBox(height: AppSpacing.s2),
                      Text(
                        n.message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: AppFontSize.f12_5, color: context.colors.textSoft),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(flex: 2, child: Align(alignment: Alignment.centerLeft, child: _categoryChip(n))),
          Expanded(
            flex: 2,
            child: created == null
                ? const Text('-', style: TextStyle(fontSize: AppFontSize.f13))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(AppDateFormat.date.format(created), style: const TextStyle(fontSize: AppFontSize.f13)),
                      Text(AppDateFormat.time12.format(created),
                          style: TextStyle(fontSize: AppFontSize.f11_5, color: context.colors.textHint)),
                    ],
                  ),
          ),
          Expanded(flex: 1, child: Align(alignment: Alignment.centerLeft, child: _statusChip(i))),
        ],
      ),
    );
  }

  // Narrow layout (phones): the same information as a card per notification.
  Widget _buildNarrowCard(NotificationItem i) {
    final n = i.notification;
    final unread = !i.isRead;
    final created = n.createdAt;

    return Container(
      key: ValueKey(n.id),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.r12),
        border: Border.all(color: context.colors.textHint.withValues(alpha: AppAlpha.a15)),
      ),
      // Clipped so the bar down the left follows the card's rounded corners.
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.r10),
        child: Container(
          decoration: BoxDecoration(
            color: unread ? Color.alphaBlend(context.colors.primary.withValues(alpha: AppAlpha.a05), context.colors.surface) : context.colors.surface,
            border: Border(left: BorderSide(color: _categoryColor(n.category), width: 4)),
          ),
          padding: const EdgeInsets.all(AppSpacing.s12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _typeIcon(n, 36),
                  const SizedBox(width: AppSpacing.s10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          n.title,
                          style: TextStyle(fontSize: AppFontSize.f14, fontWeight: unread ? AppFontWeight.bold : AppFontWeight.semibold),
                        ),
                        const SizedBox(height: AppSpacing.s2),
                        Text(n.message, style: TextStyle(fontSize: AppFontSize.f12_5, color: context.colors.textSoft)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s10),
              Row(
                children: [
                  _categoryChip(n),
                  const SizedBox(width: AppSpacing.s6),
                  _statusChip(i),
                  const Spacer(),
                  if (created != null)
                    Text(
                      AppDateFormat.dateTime12.format(created),
                      style: TextStyle(fontSize: AppFontSize.f11_5, color: context.colors.textHint),
                    ),
                ],
              ),
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
            total == 0
                ? context.l10n.notifications_empty
                : context.l10n.notifications_showingRange(start, end, total),
            style: TextStyle(fontSize: AppFontSize.f12_5, color: context.colors.textMuted),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _pageSize,
                  items: const [10, 25, 50]
                      .map((n) => DropdownMenuItem(value: n, child: Text(context.l10n.common_perPage(n))))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _pageSize = val;
                        _currentPage = 1;
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.s16),
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: page > 1 ? () => setState(() => _currentPage = page - 1) : null,
              ),
              Text(context.l10n.common_page(page), style: const TextStyle(fontSize: AppFontSize.f13)),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: page < totalPages ? () => setState(() => _currentPage = page + 1) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Compact desktop dropdown, anchored near the bell rather than a
  // full screen - no Scaffold/AppBar of its own (the dropdown
  // container the caller wraps this in provides the surface and
  // shadow), just a small header row and the same content beneath it.
  Widget _buildDropdownChrome(bool nothingToShow) {
    final feed = _feed;
    final totalUnread = feed == null ? 0 : [...feed.needsAttention, ...feed.earlier].where((i) => !i.isRead).length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s14, AppSpacing.s8, AppSpacing.s14),
          decoration: BoxDecoration(
            color: context.colors.brandSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.r12)),
          ),
          child: Row(
            children: [
              Text(
                context.l10n.common_notifications,
                style: TextStyle(color: context.colors.onBrandSurface, fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f15),
              ),
              if (totalUnread > 0) ...[
                const SizedBox(width: AppSpacing.s8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: AppSpacing.s2),
                  decoration: BoxDecoration(color: context.colors.warning, borderRadius: BorderRadius.circular(AppRadius.r10)),
                  child: Text('$totalUnread',
                      style: TextStyle(color: context.colors.onPrimary, fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f11)),
                ),
              ],
              const Spacer(),
              TextButton(
                onPressed: totalUnread > 0 ? _markAllAsRead : null,
                style: TextButton.styleFrom(
                  foregroundColor: context.colors.onBrandSurface,
                  disabledForegroundColor: context.colors.onBrandSurface.withValues(alpha: AppAlpha.a40),
                ),
                child: Text(context.l10n.notifications_markAllAsRead, style: const TextStyle(fontSize: AppFontSize.f12_5, fontWeight: AppFontWeight.semibold)),
              ),
              IconButton(
                icon: Icon(Icons.close, color: context.colors.onBrandSurface, size: AppIconSize.i20),
                tooltip: context.l10n.common_close,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        Flexible(
          child: _isLoading
              ? const Padding(
                  padding: EdgeInsets.all(AppSpacing.s32),
                  child: Center(child: CircularProgressIndicator()),
                )
              : _error != null
                  ? Padding(
                      padding: const EdgeInsets.all(AppSpacing.s24),
                      child: Text(context.l10n.notifications_loadFailed('$_error')),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(AppSpacing.s12),
                      child: _buildAlertsList(nothingToShow),
                    ),
        ),
      ],
    );
  }

  // Shared between the full-screen and dropdown chrome - same content
  // either way, only how much space it's given differs.
  Widget _buildAlertsList(bool nothingToShow) {
    if (nothingToShow) return _buildDropdownEmpty();
    final plan = _feed?.planNotices ?? const <NotificationItem>[];
    final attention = _feed?.needsAttention ?? const <NotificationItem>[];
    final earlier = _feed?.earlier ?? const <NotificationItem>[];

    return ListView(
      shrinkWrap: true,
      physics: widget.isDropdown ? const NeverScrollableScrollPhysics() : null,
      padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s16, AppSpacing.s16, AppSpacing.s32),
      children: [
        _buildUrgentAnnouncements(),
        if (plan.isNotEmpty) ...[
          _sectionHeader(Icons.workspace_premium_outlined, context.l10n.notifications_yourPlan, plan.length, context.colors.info),
          const SizedBox(height: AppSpacing.s8),
          ...plan.map(_dropdownRow),
          const SizedBox(height: AppSpacing.s20),
        ],
        if (attention.isNotEmpty) ...[
          _sectionHeader(Icons.priority_high, context.l10n.notifications_needsAttention, attention.length, context.colors.warning),
          const SizedBox(height: AppSpacing.s8),
          ...attention.map(_dropdownRow),
          const SizedBox(height: AppSpacing.s20),
        ],
        if (earlier.isNotEmpty) ...[
          _sectionHeader(Icons.history, context.l10n.notifications_earlier, earlier.length, context.colors.textHint),
          const SizedBox(height: AppSpacing.s8),
          ...earlier.map(_dropdownRow),
          const SizedBox(height: AppSpacing.s12),
        ],
        if (widget.isDropdown)
          Center(
            child: TextButton(
              onPressed: () {
                final navigator = Navigator.of(context);
                navigator.pop();
                navigator.push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
              },
              style: TextButton.styleFrom(foregroundColor: context.colors.primary),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(context.l10n.notifications_viewAll, style: const TextStyle(fontSize: AppFontSize.f13, fontWeight: AppFontWeight.semibold)),
                  const SizedBox(width: AppSpacing.s4),
                  const Icon(Icons.arrow_forward, size: AppIconSize.i16),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // One row of the dropdown.
  Widget _dropdownRow(NotificationItem i) => NotificationRow(
        key: ValueKey(i.id),
        notification: i.notification,
        isRead: i.isRead,
      );

  // The same plain words as the full screen's empty state, no "all caught
  // up" cheer (docs/design/notifications.md, section 3). The dropdown sits
  // in its own scroll view, so this just sizes itself.
  Widget _buildDropdownEmpty() => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.notifications_none, size: AppIconSize.i48, color: context.colors.textDisabled),
              const SizedBox(height: AppSpacing.s16),
              Text(context.l10n.notifications_empty,
                  style: TextStyle(fontSize: AppFontSize.f17, color: context.colors.textMuted)),
              const SizedBox(height: AppSpacing.s6),
              Text(
                context.l10n.notifications_emptyHint,
                textAlign: TextAlign.center,
                style: TextStyle(color: context.colors.textHint, fontSize: AppFontSize.f13),
              ),
            ],
          ),
        ),
      );

  Widget _buildUrgentAnnouncements() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _urgentStream,
      builder: (context, snapshot) {
        final urgentDocs = (snapshot.data?.docs ?? []).where((doc) {
          final data = doc.data();
          return data['hidden'] != true;
        }).toList();

        if (urgentDocs.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.s20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeader(Icons.campaign_outlined, context.l10n.notifications_urgentAnnouncements, urgentDocs.length, context.colors.danger),
              const SizedBox(height: AppSpacing.s8),
              ...urgentDocs.map((doc) {
                final data = doc.data();
                return _AccentCard(
                  color: context.colors.danger,
                  icon: Icons.priority_high,
                  title: data['title'] ?? '',
                  margin: const EdgeInsets.only(bottom: AppSpacing.s8),
                  child: AnnouncementMessage(data: data, fontSize: AppFontSize.f13),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _sectionHeader(IconData icon, String title, int count, Color color) {
    return Row(
      children: [
        Icon(icon, size: AppIconSize.i16, color: context.colors.primary),
        const SizedBox(width: AppSpacing.s6),
        Expanded(
          child: Text(title,
              style: TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f14, color: context.colors.primary)),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s10, vertical: AppSpacing.s3),
          decoration: BoxDecoration(color: color.withValues(alpha: AppAlpha.a15), borderRadius: BorderRadius.circular(AppRadius.r12)),
          child: Text('$count', style: TextStyle(color: color, fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f12)),
        ),
      ],
    );
  }
}

/// Shared "notification card" look - a colored left accent bar, a
/// leading icon, a title, and freeform content below. Used for urgent
/// announcements so they read as part of the same notification system
/// as everything else on this screen, not a visually separate bolt-on.
class _AccentCard extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final Widget child;
  final EdgeInsets margin;

  const _AccentCard({
    required this.color,
    required this.icon,
    required this.title,
    required this.child,
    this.margin = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.r10),
        border: Border(left: BorderSide(color: color, width: 4)),
        boxShadow: [
          BoxShadow(color: context.colors.shadow.withValues(alpha: AppAlpha.a05), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(AppSpacing.s14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: AppIconSize.i20),
          const SizedBox(width: AppSpacing.s10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f14)),
                const SizedBox(height: AppSpacing.s4),
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
