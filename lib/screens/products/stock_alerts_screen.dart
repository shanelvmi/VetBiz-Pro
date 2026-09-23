import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../providers/facility_provider.dart';
import '../../models/product.dart';
import '../../models/notification_model.dart';
import '../../widgets/notification_row.dart';

/// A focused list of what needs attention with stock right now - low
/// stock, reorder-soon, a batch that needs moving to the shelf, or a
/// product nearing expiry. Deliberately simple: no search, no date
/// range, no pagination, no category picker, since it only ever shows
/// one category to begin with. General facility-wide notifications
/// (subscriptions, payments, debts, system messages) live in their own
/// separate screen now - see NotificationsScreen in screens/dashboard/.
class StockAlertsScreen extends StatefulWidget {
  final bool isDropdown;
  const StockAlertsScreen({super.key, this.isDropdown = false});

  static const Color primaryColor = Color(0xFF2F5D62);
  static const int expiryWarningDays = 30;

  /// Cheap, aggregate-only check for the Products screen's bell red
  /// dot - a quick yes/no signal doesn't need per-batch precision,
  /// just "is there anything to look at". This screen's own list is
  /// what shows the real per-batch breakdown.
  static bool hasAnyAlert(List<Product> products) {
    final now = DateTime.now();
    return products.any((p) =>
        p.isLowStock ||
        p.hasRestockShelfAlert ||
        (p.expiry != null && p.expiry!.difference(now).inDays <= expiryWarningDays));
  }

  @override
  State<StockAlertsScreen> createState() => _StockAlertsScreenState();
}

class _StockAlertsScreenState extends State<StockAlertsScreen> {
  bool _isLoading = true;
  String? _error;
  List<FacilityNotification> _alerts = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _notificationsSub;

  @override
  void initState() {
    super.initState();
    _watchAlerts();
  }

  @override
  void dispose() {
    _notificationsSub?.cancel();
    super.dispose();
  }

  // Same simple, single-field ordering as the general Notifications
  // screen (no where() clause, so no composite index needed) -
  // filtered down to the stock category client-side, same as
  // ephemeral-vs-persistent visibility is decided client-side too.
  void _watchAlerts() {
    final facilityId = Provider.of<FacilityProvider>(context, listen: false).selectedFacilityId;
    if (facilityId == null) {
      setState(() => _isLoading = false);
      return;
    }

    _notificationsSub = FirebaseFirestore.instance
        .collection('facilities')
        .doc(facilityId)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(widget.isDropdown ? 50 : 200)
        .snapshots()
        .listen((snapshot) {
      final all = snapshot.docs.map(FacilityNotification.fromFirestore).toList();
      final stockAlerts = all
          .where((n) => n.category == NotificationCategory.stock && n.isCurrentlyVisible)
          .toList();

      if (mounted) {
        setState(() {
          _alerts = stockAlerts;
          _isLoading = false;
        });
      }
    }, onError: (e) {
      if (mounted) setState(() { _error = '$e'; _isLoading = false; });
    });
  }

  Future<void> _markAllAsRead() async {
    final facilityId = Provider.of<FacilityProvider>(context, listen: false).selectedFacilityId;
    if (facilityId == null) return;

    final unread = _alerts.where((n) => !n.isRead);
    if (unread.isEmpty) return;

    final batch = FirebaseFirestore.instance.batch();
    final notificationsRef =
        FirebaseFirestore.instance.collection('facilities').doc(facilityId).collection('notifications');
    for (final n in unread) {
      batch.update(notificationsRef.doc(n.id), {'readAt': FieldValue.serverTimestamp()});
    }
    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    final nothingToShow = !_isLoading && _error == null && _alerts.isEmpty;

    if (widget.isDropdown) {
      return _buildDropdownChrome(nothingToShow);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F4),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        centerTitle: true,
        toolbarHeight: 72,
        title: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Product Alerts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19, color: Colors.black87)),
            Text('Stock and expiry alerts for your products', style: TextStyle(fontSize: 12, color: Colors.black54)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Could not load alerts: $_error')))
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 700),
                    child: _buildAlertsList(nothingToShow),
                  ),
                ),
    );
  }

  // Compact desktop dropdown, anchored near the bell rather than a
  // full screen - no Scaffold/AppBar of its own (the dropdown
  // container the caller wraps this in provides the surface and
  // shadow), just a small header row and the same content beneath it.
  Widget _buildDropdownChrome(bool nothingToShow) {
    final unreadCount = _alerts.where((n) => !n.isRead).length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          decoration: BoxDecoration(
            color: StockAlertsScreen.primaryColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Row(
            children: [
              const Text(
                'Product Alerts',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
              ),
              if (unreadCount > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(10)),
                  child: Text('$unreadCount',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                ),
              ],
              const Spacer(),
              TextButton(
                onPressed: unreadCount > 0 ? _markAllAsRead : null,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.white.withValues(alpha: 0.4),
                ),
                child: const Text('Mark all as read', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 20),
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        Flexible(
          child: _isLoading
              ? const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              : _error != null
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('Could not load alerts: $_error'),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(12),
                      child: _buildAlertsList(nothingToShow),
                    ),
        ),
      ],
    );
  }

  // Shared between the full-screen and dropdown chrome - same content
  // either way, only how much space it's given differs.
  Widget _buildAlertsList(bool nothingToShow) {
    if (nothingToShow) return _buildAllCaughtUp();

    return ListView(
      shrinkWrap: true,
      physics: widget.isDropdown ? const NeverScrollableScrollPhysics() : null,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        ..._alerts.map((n) => NotificationRow(notification: n)),
        if (widget.isDropdown)
          Center(
            child: TextButton(
              onPressed: () {
                final navigator = Navigator.of(context);
                navigator.pop();
                navigator.push(MaterialPageRoute(builder: (_) => const StockAlertsScreen()));
              },
              style: TextButton.styleFrom(foregroundColor: StockAlertsScreen.primaryColor),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('View all alerts', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward, size: 15),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAllCaughtUp() {
    final content = Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_outline, color: Colors.green, size: 48),
          ),
          const SizedBox(height: 16),
          const Text("You're all caught up!", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          const SizedBox(height: 6),
          Text(
            'No stock alerts right now.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
        ],
      ),
    );

    // The dropdown already sits inside its own SingleChildScrollView
    // (see _buildDropdownChrome), which offers unbounded height to its
    // child - the LayoutBuilder/minHeight-centering trick below needs
    // a *bounded* parent to make sense, so nesting it inside that
    // unbounded scroll view turned constraints.maxHeight into
    // infinity, and minHeight: infinity into a genuine layout error.
    // In dropdown mode this just needs to size itself naturally, no
    // viewport-filling/centering required.
    if (widget.isDropdown) return Center(child: content);

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(child: content),
        ),
      ),
    );
  }
}
