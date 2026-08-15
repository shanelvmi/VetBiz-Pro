import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../../providers/product_provider.dart';
import '../../providers/facility_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/user_role_provider.dart';
import '../../providers/debt_provider.dart';
import '../../models/product.dart';
import '../../models/debt.dart';
import '../subscription/subscription_screen.dart';
import '../admin/manage_assistants_screen.dart';
import '../debtors/debtors_screen.dart';
import '../../utils/notification_seen_tracker.dart';

/// One alert row - either a whole product (legacy, no batches recorded
/// yet) or one specific batch of a product. Kept generic so both cases
/// render through the same list/section logic.
class _AlertRow {
  final String productName;
  final String? batchNo;
  final int sellableQty;
  final int stockQty;
  final DateTime? expiry;

  const _AlertRow({
    required this.productName,
    this.batchNo,
    required this.sellableQty,
    required this.stockQty,
    this.expiry,
  });

  String get label => batchNo != null && batchNo!.isNotEmpty
      ? '$productName - Batch $batchNo'
      : productName;
}

/// Everything that needs your attention in one place - subscription
/// status, urgent announcements, and low-stock/expiry alerts, precise to
/// the individual batch. Products with no batch records yet (created
/// before batch tracking existed) fall back to a single whole-product
/// row using their own aggregate fields.
class StockAlertsScreen extends StatefulWidget {
  const StockAlertsScreen({super.key});

  static const Color primaryColor = Color(0xFF2F5D62);
  static const int lowStockThreshold = 5;
  static const int expiryWarningDays = 30;
  static const int overdueDebtDays = 30;

  /// Cheap, aggregate-only check for the Dashboard bell's red dot - a
  /// quick yes/no signal doesn't need per-batch precision, just "is
  /// there anything to look at". The detail screen below is what shows
  /// the real per-batch breakdown.
  static bool hasAnyAlert(List<Product> products) {
    final now = DateTime.now();
    return products.any((p) =>
        p.sellableQty <= lowStockThreshold ||
        p.stockQty <= lowStockThreshold ||
        (p.expiry != null && p.expiry!.difference(now).inDays <= expiryWarningDays));
  }

  @override
  State<StockAlertsScreen> createState() => _StockAlertsScreenState();
}

class _StockAlertsScreenState extends State<StockAlertsScreen> {
  bool _isLoading = true;
  String? _error;
  List<_AlertRow> _critical = [];
  List<_AlertRow> _lowShelf = [];
  List<_AlertRow> _lowWarehouse = [];
  List<_AlertRow> _expiring = [];

  // Tracked separately (not via _load, which only covers stock) purely
  // so the "all caught up" empty state can never contradict a genuinely
  // active urgent announcement, pending approval, or overdue debtor -
  // the sections themselves still render via their own StreamBuilder
  // below; these just feed the one combined "is there really nothing"
  // check.
  int _urgentCount = 0;
  int _pendingAssistantCount = 0;
  int _overdueDebtorCount = 0;
  bool _isEmailVerified = true; // starts true so it never flashes in before the real check completes
  StreamSubscription<QuerySnapshot>? _urgentSub;
  StreamSubscription<QuerySnapshot>? _pendingSub;
  StreamSubscription<QuerySnapshot>? _debtsSub;

  @override
  void initState() {
    super.initState();
    _load();
    _watchLiveCounts();
    _checkEmailVerified();
    NotificationSeenTracker.markViewedNow();
  }

  Future<void> _checkEmailVerified() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await user.reload();
      if (mounted) {
        setState(() => _isEmailVerified = FirebaseAuth.instance.currentUser?.emailVerified ?? true);
      }
    } catch (e) {
      debugPrint('Could not refresh email verification status: $e');
    }
  }

  void _watchLiveCounts() {
    final facilityId = Provider.of<FacilityProvider>(context, listen: false).selectedFacilityId;
    final isAdmin = Provider.of<UserRoleProvider>(context, listen: false).isAdmin;

    _urgentSub = FirebaseFirestore.instance
        .collection('public_announcements')
        .where('urgent', isEqualTo: true)
        .snapshots()
        .listen((snapshot) {
      final count = snapshot.docs.where((doc) => (doc.data())['hidden'] != true).length;
      if (mounted) setState(() => _urgentCount = count);
    });

    if (facilityId != null && isAdmin) {
      // Only admins can even read other users' documents (Firestore
      // rules only allow reading your own, or reading anyone's if
      // you're an admin) - a non-admin's version of this query would
      // just fail with a permission error, so it's never attempted.
      _pendingSub = FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'assistant')
          .where('status', isEqualTo: 'pending')
          .where('facilityIds', arrayContains: facilityId)
          .snapshots()
          .listen((snapshot) {
        if (mounted) setState(() => _pendingAssistantCount = snapshot.docs.length);
      });
    }

    if (facilityId != null) {
      _debtsSub = FirebaseFirestore.instance
          .collection('facilities')
          .doc(facilityId)
          .collection('debts')
          .snapshots()
          .listen((snapshot) {
        final cutoff = DateTime.now().subtract(const Duration(days: StockAlertsScreen.overdueDebtDays));
        final count = snapshot.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final ts = data['timestamp'];
          if (ts is! Timestamp) return false;
          return ts.toDate().isBefore(cutoff);
        }).length;
        if (mounted) setState(() => _overdueDebtorCount = count);
      });
    }
  }

  @override
  void dispose() {
    _urgentSub?.cancel();
    _pendingSub?.cancel();
    _debtsSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final facilityId =
        Provider.of<FacilityProvider>(context, listen: false).selectedFacilityId;
    final products = Provider.of<ProductProvider>(context, listen: false).products;

    if (facilityId == null) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final now = DateTime.now();
      final critical = <_AlertRow>[];
      final lowShelf = <_AlertRow>[];
      final lowWarehouse = <_AlertRow>[];
      final expiring = <_AlertRow>[];

      // One query per product (batches are a small subcollection, and
      // shop-scale product counts make this perfectly fine) - run in
      // parallel rather than one at a time.
      final batchLists = await Future.wait(products.map((p) async {
        final snap = await FirebaseFirestore.instance
            .collection('facilities')
            .doc(facilityId)
            .collection('products')
            .doc(p.id)
            .collection('batches')
            .get();
        return MapEntry(p, snap.docs);
      }));

      for (final entry in batchLists) {
        final product = entry.key;
        final batchDocs = entry.value;

        if (batchDocs.isEmpty) {
          // Legacy product, no batch records - fall back to its own
          // aggregate fields, same as before Phase 3.
          final shelfLow = product.sellableQty <= StockAlertsScreen.lowStockThreshold;
          final warehouseLow = product.stockQty <= StockAlertsScreen.lowStockThreshold;
          final row = _AlertRow(
            productName: product.name,
            sellableQty: product.sellableQty,
            stockQty: product.stockQty,
            expiry: product.expiry,
          );

          if (shelfLow && warehouseLow) {
            critical.add(row);
          } else if (shelfLow) {
            lowShelf.add(row);
          } else if (warehouseLow) {
            lowWarehouse.add(row);
          }

          if (product.expiry != null &&
              product.expiry!.difference(now).inDays <= StockAlertsScreen.expiryWarningDays) {
            expiring.add(row);
          }
          continue;
        }

        for (final doc in batchDocs) {
          final data = doc.data();
          final sellableQty = (data['sellableQty'] ?? 0) as int;
          final stockQty = (data['stockQty'] ?? 0) as int;
          final expiry = data['expiry'] is Timestamp ? (data['expiry'] as Timestamp).toDate() : null;

          // A fully-used-up batch (both zero) is just spent stock, not
          // an alert - skip it rather than flagging every empty batch
          // forever.
          if (sellableQty == 0 && stockQty == 0) continue;

          final shelfLow = sellableQty <= StockAlertsScreen.lowStockThreshold;
          final warehouseLow = stockQty <= StockAlertsScreen.lowStockThreshold;
          final row = _AlertRow(
            productName: product.name,
            batchNo: data['batchNo'] as String?,
            sellableQty: sellableQty,
            stockQty: stockQty,
            expiry: expiry,
          );

          if (shelfLow && warehouseLow) {
            critical.add(row);
          } else if (shelfLow) {
            lowShelf.add(row);
          } else if (warehouseLow) {
            lowWarehouse.add(row);
          }

          if (expiry != null && expiry.difference(now).inDays <= StockAlertsScreen.expiryWarningDays) {
            expiring.add(row);
          }
        }
      }

      expiring.sort((a, b) => a.expiry!.compareTo(b.expiry!));

      if (mounted) {
        setState(() {
          _critical = critical;
          _lowShelf = lowShelf;
          _lowWarehouse = lowWarehouse;
          _expiring = expiring;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = '$e'; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sub = Provider.of<SubscriptionProvider>(context);
    final isAdmin = Provider.of<UserRoleProvider>(context).isAdmin;

    // Same thresholds as the Dashboard banner, so the two can never
    // disagree about whether the subscription needs attention.
    final subNeedsAttention = sub.status != SubscriptionStatus.trial &&
        !(sub.status == SubscriptionStatus.active && (sub.daysRemaining == null || sub.daysRemaining! > 7));

    final nothingToShow = !_isLoading &&
        _error == null &&
        !subNeedsAttention &&
        _isEmailVerified &&
        _urgentCount == 0 &&
        _pendingAssistantCount == 0 &&
        _overdueDebtorCount == 0 &&
        _critical.isEmpty &&
        _lowShelf.isEmpty &&
        _lowWarehouse.isEmpty &&
        _expiring.isEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F4),
      appBar: AppBar(
        title: const Text('Notifications'),
        centerTitle: true,
        backgroundColor: StockAlertsScreen.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _load,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Could not load alerts: $_error')))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: nothingToShow
                          ? _buildAllCaughtUp()
                          : ListView(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                              children: [
                                if (subNeedsAttention) ...[
                                  _buildSubscriptionCard(context, sub, isAdmin),
                                  const SizedBox(height: 20),
                                ],
                                if (!_isEmailVerified) ...[
                                  _buildEmailVerificationCard(context),
                                  const SizedBox(height: 20),
                                ],
                                if (isAdmin) _buildPendingAssistants(),
                                _buildOverdueDebtors(),
                                _buildUrgentAnnouncements(),
                                _buildSection(
                                  icon: Icons.error_outline,
                                  title: 'Critical - Out of Stock Everywhere',
                                  color: Colors.redAccent,
                                  rows: _critical,
                                  emptyText: null,
                                  subtitleBuilder: (r) => 'Shelf: ${r.sellableQty} · Warehouse: ${r.stockQty}',
                                  rowIcon: Icons.error_outline,
                                ),
                                _buildSection(
                                  icon: Icons.inventory_2_outlined,
                                  title: 'Low on Shelf',
                                  color: Colors.orange,
                                  rows: _lowShelf,
                                  emptyText: null,
                                  subtitleBuilder: (r) =>
                                      '${r.sellableQty} on shelf · ${r.stockQty} in warehouse - move some to sellable',
                                  rowIcon: Icons.inventory_2_outlined,
                                ),
                                _buildSection(
                                  icon: Icons.warehouse_outlined,
                                  title: 'Low in Warehouse',
                                  color: Colors.orange,
                                  rows: _lowWarehouse,
                                  emptyText: null,
                                  subtitleBuilder: (r) => '${r.stockQty} left in warehouse - reorder soon',
                                  rowIcon: Icons.warehouse_outlined,
                                ),
                                _buildExpiringSection(),
                              ],
                            ),
                    ),
                  ),
                ),
    );
  }

  Widget _buildAllCaughtUp() {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
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
                    'No urgent announcements, subscription issues, or stock alerts right now.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubscriptionCard(BuildContext context, SubscriptionProvider sub, bool isAdmin) {
    final isLocked = sub.status == SubscriptionStatus.locked;
    final isGrace = sub.status == SubscriptionStatus.grace;
    final color = isLocked ? Colors.redAccent : Colors.orange;

    String message;
    if (isLocked) {
      message = 'Your subscription has expired. The app is in read-only mode - submit a payment to restore full access.';
    } else if (isGrace) {
      message = 'Your subscription expired - you have a few days of grace before read-only mode begins.';
    } else {
      message = 'Your subscription expires in ${sub.daysRemaining} day${sub.daysRemaining == 1 ? '' : 's'}.';
    }

    return _AccentCard(
      color: color,
      icon: isLocked ? Icons.lock_outline : Icons.workspace_premium_outlined,
      title: 'Subscription',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(message, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          if (isAdmin)
            TextButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionScreen()));
              },
              style: TextButton.styleFrom(foregroundColor: color, padding: EdgeInsets.zero),
              child: const Text('Renew'),
            )
          else
            Text('Ask your admin', style: TextStyle(color: color, fontSize: 11.5, fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }

  Widget _buildEmailVerificationCard(BuildContext context) {
    return _AccentCard(
      color: Colors.orange,
      icon: Icons.mark_email_unread_outlined,
      title: 'Verify Your Email',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Expanded(
            child: Text(
              'Check your inbox for the verification link (and your Spam folder - it '
              'often ends up there) - this protects your ability to reset your '
              'password later.',
              style: TextStyle(color: Colors.orange, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () async {
              try {
                await FirebaseAuth.instance.currentUser?.sendEmailVerification();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Verification email sent'), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Could not send email: $e'), backgroundColor: Colors.redAccent),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.orange, padding: EdgeInsets.zero),
            child: const Text('Resend'),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingAssistants() {
    final facilityId = Provider.of<FacilityProvider>(context, listen: false).selectedFacilityId;
    if (facilityId == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'assistant')
          .where('status', isEqualTo: 'pending')
          .where('facilityIds', arrayContains: facilityId)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeader(Icons.person_add_alt_1_outlined, 'Waiting for Approval', docs.length, Colors.blue),
              const SizedBox(height: 8),
              ...docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return _AccentCard(
                  color: Colors.blue,
                  icon: Icons.person_outline,
                  title: data['fullName'] ?? 'New assistant',
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '${data['email'] ?? ''} - registered, waiting for you to approve their account',
                    style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w600, fontSize: 12.5),
                  ),
                );
              }),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ManageAssistantsScreen()));
                  },
                  child: const Text('Review in Manage Assistants'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOverdueDebtors() {
    final facilityId = Provider.of<FacilityProvider>(context, listen: false).selectedFacilityId;
    if (facilityId == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('facilities')
          .doc(facilityId)
          .collection('debts')
          .snapshots(),
      builder: (context, snapshot) {
        final now = DateTime.now();
        final cutoff = now.subtract(const Duration(days: StockAlertsScreen.overdueDebtDays));

        final overdueDocs = (snapshot.data?.docs ?? []).where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final ts = data['timestamp'];
          if (ts is! Timestamp) return false;
          return ts.toDate().isBefore(cutoff);
        }).toList()
          ..sort((a, b) {
            final tsA = ((a.data() as Map<String, dynamic>)['timestamp'] as Timestamp).toDate();
            final tsB = ((b.data() as Map<String, dynamic>)['timestamp'] as Timestamp).toDate();
            return tsA.compareTo(tsB); // oldest first - most overdue at the top
          });

        if (overdueDocs.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeader(Icons.hourglass_bottom, 'Overdue Debtors (${StockAlertsScreen.overdueDebtDays}+ days)', overdueDocs.length, Colors.deepOrange),
              const SizedBox(height: 8),
              ...overdueDocs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final ts = (data['timestamp'] as Timestamp).toDate();
                final daysOwed = now.difference(ts).inDays;
                final amount = (data['amountOwed'] ?? 0).toDouble();
                return _AccentCard(
                  color: Colors.deepOrange,
                  icon: Icons.hourglass_bottom,
                  title: data['clientName'] ?? 'Unknown client',
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Owes Tsh ${amount.toStringAsFixed(0)} - $daysOwed days overdue',
                    style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.w600, fontSize: 12.5),
                  ),
                );
              }),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const DebtorsScreen()));
                  },
                  child: const Text('Open Debtors'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUrgentAnnouncements() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('public_announcements')
          .where('urgent', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        final urgentDocs = (snapshot.data?.docs ?? []).where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['hidden'] != true;
        }).toList();

        if (urgentDocs.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeader(Icons.campaign_outlined, 'Urgent Announcements', urgentDocs.length, Colors.red),
              const SizedBox(height: 8),
              ...urgentDocs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final colorValue = data['color'] as int?;
                return _AccentCard(
                  color: Colors.red,
                  icon: Icons.priority_high,
                  title: data['title'] ?? '',
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    (data['message'] ?? '').toString(),
                    style: TextStyle(color: colorValue != null ? Color(colorValue) : Colors.black87, fontSize: 13),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required Color color,
    required List<_AlertRow> rows,
    required String? emptyText,
    required String Function(_AlertRow) subtitleBuilder,
    required IconData rowIcon,
  }) {
    // Sections with nothing in them are omitted entirely, not shown
    // with a "nothing here" placeholder - a real notification center
    // doesn't list every category it checked and came up empty on.
    if (rows.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(icon, title, rows.length, color),
          const SizedBox(height: 8),
          ...rows.map((r) => _AccentCard(
                color: color,
                icon: rowIcon,
                title: r.label,
                margin: const EdgeInsets.only(bottom: 8),
                child: Text(subtitleBuilder(r), style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12.5)),
              )),
        ],
      ),
    );
  }

  Widget _buildExpiringSection() {
    if (_expiring.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(Icons.event_busy, 'Expiring Within ${StockAlertsScreen.expiryWarningDays} Days', _expiring.length, Colors.redAccent),
          const SizedBox(height: 8),
          ..._expiring.map((r) {
            final daysLeft = r.expiry!.difference(DateTime.now()).inDays;
            final label = daysLeft < 0
                ? 'Expired ${DateFormat('dd MMM yyyy').format(r.expiry!)}'
                : daysLeft == 0
                    ? 'Expires today'
                    : 'Expires in $daysLeft days (${DateFormat('dd MMM yyyy').format(r.expiry!)})';
            final color = daysLeft < 0 ? Colors.redAccent : Colors.orange;
            return _AccentCard(
              color: color,
              icon: Icons.event_busy,
              title: r.label,
              margin: const EdgeInsets.only(bottom: 8),
              child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12.5)),
            );
          }),
        ],
      ),
    );
  }

  Widget _sectionHeader(IconData icon, String title, int count, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: StockAlertsScreen.primaryColor),
        const SizedBox(width: 6),
        Expanded(
          child: Text(title,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: StockAlertsScreen.primaryColor)),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
          child: Text('$count', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
        ),
      ],
    );
  }
}

/// Shared "notification card" look - a colored left accent bar, a
/// leading icon, a title, and freeform content below. Used for every
/// kind of notification (subscription, urgent announcement, stock
/// alert) so the whole screen reads as one consistent system instead of
/// several different card styles bolted together.
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: color, width: 4)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
