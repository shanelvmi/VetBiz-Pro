import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'subscription_screen.dart' show submissionStatusColor;
import '../../config/payment_methods.dart';
import '../../data/collections.dart';
import '../../data/fields.dart';
import '../../data/payment_submission_status.dart';
import '../../constants/subscription_plans.dart';
import '../../config/money.dart';
import '../../config/app_limits.dart';
import '../../config/app_date_format.dart';
import '../../ui/feedback/friendly_error.dart';
import '../../theme/app_breakpoints.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_text.dart';
import '../../theme/theme_context.dart';
import '../../l10n/l10n.dart';

/// One payment submission, read from a payment_submissions document.
class _Submission {
  final String planId;
  final String planLabel; // English, as saved; shown only for an unknown planId
  final num amount;
  final String method;
  final String reference;
  final String status; // 'approved' | 'rejected' | 'pending'
  final DateTime? submittedAt;
  final DateTime? reviewedAt;
  final String reviewNote; // the rejection reason - empty if none was given
  final String? promotionLabel;

  const _Submission({
    required this.planId,
    required this.planLabel,
    required this.amount,
    required this.method,
    required this.reference,
    required this.status,
    required this.submittedAt,
    required this.reviewedAt,
    required this.reviewNote,
    required this.promotionLabel,
  });

  factory _Submission.fromMap(Map<String, dynamic> d) {
    DateTime? asDate(dynamic v) => v is Timestamp ? v.toDate() : null;
    final rawStatus = (d[Fields.status] as String?) ?? PaymentSubmissionStatus.pending.key;
    return _Submission(
      planId: (d['planId'] as String?) ?? '',
      planLabel: (d['planLabel'] as String?) ?? '',
      amount: (d['amount'] as num?) ?? 0,
      method: (d['method'] as String?) ?? '',
      reference: ((d['reference'] as String?) ?? '').trim(),
      // Anything that isn't a final decision is still waiting on one.
      status: (rawStatus == PaymentSubmissionStatus.approved.key || rawStatus == PaymentSubmissionStatus.rejected.key) ? rawStatus : PaymentSubmissionStatus.pending.key,
      submittedAt: asDate(d['submittedAt']),
      reviewedAt: asDate(d['reviewedAt']),
      reviewNote: ((d['reviewNote'] as String?) ?? '').trim(),
      promotionLabel: d['promotionLabel'] as String?,
    );
  }

  bool get hasReason => reviewNote.isNotEmpty;
}

/// The full subscription/payment submission history for a facility -
/// reached via "View all" on the Subscription screen's own recent-list
/// section, which only ever shows a handful at a glance.
///
/// Laid out like the Sales and Product Alerts screens: small summary
/// cards (tap one to filter), one search/filter row, a full-width table,
/// and the same pagination bar. A rejected submission shows the reason
/// the platform admin gave, right in the row.
class SubscriptionHistoryScreen extends StatefulWidget {
  final String facilityId;
  final Color primaryColor;

  /// Null: the app's own Firestore. Tests pass an in-memory one (SUBS-1).
  final FirebaseFirestore? firestore;

  const SubscriptionHistoryScreen({super.key, required this.facilityId, required this.primaryColor, this.firestore});

  @override
  State<SubscriptionHistoryScreen> createState() => _SubscriptionHistoryScreenState();
}

class _SubscriptionHistoryScreenState extends State<SubscriptionHistoryScreen> {
  // A generous cap rather than a truly unlimited query - protects
  // against an unbounded read for a facility with an unusually long
  // history, while still comfortably covering years of normal use.
  static const int _historyLimit = 200;

  // Created once - building a new stream inside build() would restart
  // the StreamBuilder (back to "waiting") on every filter tap.
  late final Stream<QuerySnapshot> _stream;

  final TextEditingController _searchController = TextEditingController();
  final DateFormat _dateFormat = AppDateFormat.date;
  final DateFormat _dateTimeFormat = AppDateFormat.dateTime24;

  String _searchQuery = '';
  String? _statusFilter; // null = all
  String _planFilter = 'All';
  String _methodFilter = 'All';
  int _page = 1;
  int _pageSize = AppLimits.tablePageSize;

  Color get _primary => widget.primaryColor;

  @override
  void initState() {
    super.initState();
    _stream = (widget.firestore ?? FirebaseFirestore.instance)
        .collection(Collections.facilities)
        .doc(widget.facilityId)
        .collection(Collections.paymentSubmissions)
        .orderBy('submittedAt', descending: true)
        .limit(_historyLimit)
        .snapshots();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _statusName(String status) => context.l10n.submissionStatusLabel(status);

  // A plan's name in the current language, from its id. The English
  // planLabel saved with the payment is shown only for a plan the app
  // doesn't know.
  String _planName(_Submission s) =>
      planById(s.planId) != null ? context.l10n.subscriptionPlanLabel(s.planId) : s.planLabel;

  // The plan filter holds saved planLabels; this shows one in the current
  // language when it is a known plan's English name.
  String _planNameForLabel(String saved) {
    for (final p in kSubscriptionPlans) {
      if (p.label == saved) return context.l10n.subscriptionPlanLabel(p.id);
    }
    return saved;
  }

  void _resetFilters() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _statusFilter = null;
      _planFilter = 'All';
      _methodFilter = 'All';
      _page = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
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
            Text(context.l10n.subscription_historyTitle,
                style: TextStyle(
                    fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f19, color: context.colors.textPrimary)),
            Text(context.l10n.subscription_historySubtitle, style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textSecondary)),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.s24),
                child: Text(context.l10n.subscription_historyLoadError(FriendlyError.messageFor(snapshot.error!))),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final all = (snapshot.data?.docs ?? [])
              .map((d) => _Submission.fromMap(d.data() as Map<String, dynamic>))
              .toList();
          return _buildBody(all);
        },
      ),
    );
  }

  Widget _buildBody(List<_Submission> all) {
    if (all.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: AppIconSize.i64, color: context.colors.textDisabled),
            const SizedBox(height: AppSpacing.s16),
            Text(context.l10n.subscription_noSubmissionsYet, style: TextStyle(fontSize: AppFontSize.f18, color: context.colors.textMuted)),
            const SizedBox(height: AppSpacing.s4),
            Text(context.l10n.subscription_noSubmissionsHint, style: TextStyle(fontSize: AppFontSize.f13, color: context.colors.textHint)),
          ],
        ),
      );
    }

    final counts = <String, int>{PaymentSubmissionStatus.approved.key: 0, PaymentSubmissionStatus.pending.key: 0, PaymentSubmissionStatus.rejected.key: 0};
    num approvedTotal = 0;
    for (final s in all) {
      counts[s.status] = (counts[s.status] ?? 0) + 1;
      if (s.status == PaymentSubmissionStatus.approved.key) approvedTotal += s.amount;
    }

    final plans = <String>{for (final s in all) if (s.planLabel.isNotEmpty) s.planLabel}.toList()..sort();
    // One choice per shown name: Tigo Pesa records are under Mixx by Yas (R3, D5).
    final methods = PaymentMethod.shownChoices([for (final s in all) if (s.method.isNotEmpty) s.method]);
    // A chosen plan/method can vanish if the data changes underneath it.
    final plan = (_planFilter == 'All' || plans.contains(_planFilter)) ? _planFilter : 'All';
    final method = (_methodFilter == 'All' || methods.contains(_methodFilter)) ? _methodFilter : 'All';

    final q = _searchQuery.trim().toLowerCase();
    final filtered = all.where((s) {
      if (_statusFilter != null && s.status != _statusFilter) return false;
      if (plan != 'All' && s.planLabel != plan) return false;
      if (method != 'All' && PaymentMethod.shownKey(s.method) != method) return false;
      if (q.isNotEmpty) {
        final hay = '${s.planLabel} ${PaymentMethod.shownKey(s.method)} ${s.reference} ${s.reviewNote} ${s.status} ${s.promotionLabel ?? ''}'
            .toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList();

    final hasActiveFilters = _searchQuery.trim().isNotEmpty || _statusFilter != null || plan != 'All' || method != 'All';

    final total = filtered.length;
    final totalPages = total == 0 ? 1 : ((total + _pageSize - 1) ~/ _pageSize);
    final page = _page > totalPages ? totalPages : _page;
    final pageItems = filtered.skip((page - 1) * _pageSize).take(_pageSize).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s16, AppSpacing.s16, 0),
          child: _buildCards(all.length, counts, approvedTotal),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s12, AppSpacing.s16, 0),
          child: _buildFilters(plans, plan, methods, method, hasActiveFilters),
        ),
        Expanded(
          child: filtered.isEmpty ? _buildNoMatches() : _buildResults(pageItems),
        ),
        _buildPaginationBar(total: total, page: page, totalPages: totalPages),
      ],
    );
  }

  // ==================== CARDS ====================

  Widget _buildCards(int totalCount, Map<String, int> counts, num approvedTotal) {
    final cards = <Widget>[
      _card(
        label: context.l10n.subscription_totalSubmissions,
        value: '$totalCount',
        hint: context.l10n.subscription_allPayments,
        icon: Icons.receipt_long_outlined,
        color: _primary,
        filter: null,
      ),
      _card(
        label: _statusName(PaymentSubmissionStatus.approved.key),
        value: '${counts[PaymentSubmissionStatus.approved.key] ?? 0}',
        hint: Money.format(approvedTotal),
        icon: Icons.check_circle_outline,
        color: submissionStatusColor(PaymentSubmissionStatus.approved.key, context.colors),
        filter: PaymentSubmissionStatus.approved.key,
      ),
      _card(
        label: _statusName(PaymentSubmissionStatus.pending.key),
        value: '${counts[PaymentSubmissionStatus.pending.key] ?? 0}',
        hint: context.l10n.subscription_awaitingReviewLower,
        icon: Icons.hourglass_empty,
        color: submissionStatusColor(PaymentSubmissionStatus.pending.key, context.colors),
        filter: PaymentSubmissionStatus.pending.key,
      ),
      _card(
        label: _statusName(PaymentSubmissionStatus.rejected.key),
        value: '${counts[PaymentSubmissionStatus.rejected.key] ?? 0}',
        hint: context.l10n.subscription_notAccepted,
        icon: Icons.cancel_outlined,
        color: submissionStatusColor(PaymentSubmissionStatus.rejected.key, context.colors),
        filter: PaymentSubmissionStatus.rejected.key,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        return GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: constraints.maxWidth >= AppBreakpoints.compact ? 4 : 2,
            mainAxisExtent: 90,
            crossAxisSpacing: AppSpacing.s12,
            mainAxisSpacing: AppSpacing.s12,
          ),
          children: cards,
        );
      },
    );
  }

  // Same small card as Sales / Product Alerts. Tapping a status card
  // filters the table to it (tap again to clear); the Total card clears
  // the status filter.
  Widget _card({
    required String label,
    required String value,
    required String hint,
    required IconData icon,
    required Color color,
    required String? filter,
  }) {
    final selected = filter != null && _statusFilter == filter;
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
          _statusFilter = (filter == null || selected) ? null : filter;
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
                      child: Icon(icon, color: color, size: AppIconSize.i14),
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    Text(value, style: const TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f16)),
                  ],
                ),
                const SizedBox(height: AppSpacing.s4),
                Text(label, style: TextStyle(fontSize: AppFontSize.f11_5, color: context.colors.textMuted)),
                Text(hint, style: TextStyle(fontSize: AppFontSize.f10_5, color: context.colors.textDisabled)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==================== FILTERS ====================

  Widget _buildFilters(List<String> plans, String plan, List<String> methods, String method, bool hasActiveFilters) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.r10),
      borderSide: BorderSide(color: context.colors.textHint.withValues(alpha: AppAlpha.a30)),
    );

    final search = TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: context.l10n.subscription_searchHint,
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
      onChanged: (v) => setState(() {
        _searchQuery = v;
        _page = 1;
      }),
    );

    final reset = hasActiveFilters ? TextButton(onPressed: _resetFilters, child: Text(context.l10n.common_reset)) : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < AppBreakpoints.stackSections) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              search,
              const SizedBox(height: AppSpacing.s10),
              Row(
                children: [
                  Expanded(child: _dropdown(context.l10n.subscription_plan, plan, plans, (v) => _planFilter = v, expand: true, display: _planNameForLabel)),
                  const SizedBox(width: AppSpacing.s10),
                  Expanded(child: _dropdown(context.l10n.common_method, method, methods, (v) => _methodFilter = v, expand: true, display: context.l10n.paymentMethodLabel)),
                  if (reset != null) ...[const SizedBox(width: AppSpacing.s6), reset],
                ],
              ),
            ],
          );
        }
        return Row(
          children: [
            Expanded(flex: 3, child: search),
            const SizedBox(width: AppSpacing.s10),
            _dropdown(context.l10n.subscription_plan, plan, plans, (v) => _planFilter = v, display: _planNameForLabel),
            const SizedBox(width: AppSpacing.s10),
            _dropdown(context.l10n.common_method, method, methods, (v) => _methodFilter = v, display: context.l10n.paymentMethodLabel),
            if (reset != null) ...[const SizedBox(width: AppSpacing.s10), reset],
          ],
        );
      },
    );
  }

  // [display]: what an option shows; the dropdown still holds the saved value.
  Widget _dropdown(String label, String value, List<String> options, void Function(String) assign,
      {bool expand = false, String Function(String saved)? display}) {
    final items = ['All', ...options];
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
          icon: Icon(Icons.arrow_drop_down, size: AppIconSize.i18, color: _primary),
          style: TextStyle(color: context.colors.textPrimary, fontSize: AppFontSize.f13),
          items: items
              .map((v) => DropdownMenuItem(
                  value: v,
                  child: Text(context.l10n.common_filterValue(label, v == 'All' ? context.l10n.common_all : (display?.call(v) ?? v)),
                      overflow: TextOverflow.ellipsis)))
              .toList(),
          onChanged: (v) {
            if (v != null) {
              setState(() {
                assign(v);
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
          Text(context.l10n.subscription_noMatches, style: TextStyle(fontSize: AppFontSize.f17, color: context.colors.textMuted)),
          const SizedBox(height: AppSpacing.s8),
          TextButton(onPressed: _resetFilters, child: Text(context.l10n.common_resetFilters)),
        ],
      ),
    );
  }

  Widget _buildResults(List<_Submission> items) {
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
                  _headerCell(context.l10n.subscription_colSubmitted, flex: 3),
                  _headerCell(context.l10n.subscription_plan, flex: 3),
                  _headerCell(context.l10n.common_amount, flex: 2),
                  _headerCell(context.l10n.common_method, flex: 3),
                  _headerCell(context.l10n.common_status, flex: 2),
                  _headerCell(context.l10n.common_details, flex: 5),
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
      child: Text(label, style: TextStyle(
          fontSize: AppFontSize.f12, fontWeight: AppFontWeight.semibold, color: context.colors.textMuted)),
    );
  }

  Widget _statusChip(String status) {
    final color = submissionStatusColor(status, context.colors);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: AppSpacing.s4),
      decoration: BoxDecoration(color: color.withValues(alpha: AppAlpha.a10), borderRadius: BorderRadius.circular(AppRadius.r10)),
      child: Text(_statusName(status), style: TextStyle(
          color: color, fontSize: AppFontSize.f11_5, fontWeight: AppFontWeight.semibold)),
    );
  }

  // What this row says about the review: for a rejection, the reason
  // (or an honest "none given"), for an approval when, for a pending
  // one that it's still waiting.
  Widget _detailsFor(_Submission s) {
    switch (PaymentSubmissionStatus.fromKey(s.status)) {
      case PaymentSubmissionStatus.rejected:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.hasReason ? context.l10n.subscription_rejectReason(s.reviewNote) : context.l10n.subscription_noReason,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: AppFontSize.f12_5,
                color: s.hasReason ? context.colors.dangerStrong : context.colors.textMuted,
                fontStyle: s.hasReason ? FontStyle.normal : FontStyle.italic,
              ),
            ),
            if (s.reviewedAt != null) ...[
              const SizedBox(height: AppSpacing.s2),
              Text(context.l10n.subscription_rejectedOn(_dateTimeFormat.format(s.reviewedAt!)),
                  style: TextStyle(fontSize: AppFontSize.f11_5, color: context.colors.textHint)),
            ],
          ],
        );
      case PaymentSubmissionStatus.approved:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_statusName(PaymentSubmissionStatus.approved.key), style: TextStyle(
                    fontSize: AppFontSize.f12_5, color: context.colors.successStrong, fontWeight: AppFontWeight.medium)),
            if (s.reviewedAt != null) ...[
              const SizedBox(height: AppSpacing.s2),
              Text(_dateTimeFormat.format(s.reviewedAt!), style: TextStyle(fontSize: AppFontSize.f11_5, color: context.colors.textHint)),
            ],
          ],
        );
      default:
        return Text(context.l10n.subscription_awaitingReviewLower, style: TextStyle(fontSize: AppFontSize.f12_5, color: context.colors.textMuted));
    }
  }

  // Wide layout: one table row.
  Widget _buildRow(_Submission s) {
    final submitted = s.submittedAt;
    return Container(
      // Coloured bar down the left edge - the outcome at a glance.
      decoration: BoxDecoration(border: Border(left: BorderSide(color: submissionStatusColor(s.status, context.colors), width: 4))),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 3,
            child: submitted == null
                ? const Text('-', style: TextStyle(fontSize: AppFontSize.f13))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_dateFormat.format(submitted), style: const TextStyle(fontSize: AppFontSize.f13)),
                      Text(AppDateFormat.time24.format(submitted),
                          style: TextStyle(fontSize: AppFontSize.f11_5, color: context.colors.textHint)),
                    ],
                  ),
          ),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_planName(s).isEmpty ? '-' : _planName(s),
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: AppFontSize.f13)),
                if (s.promotionLabel != null && s.promotionLabel!.isNotEmpty)
                  Text(s.promotionLabel!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: AppFontSize.f11_5, color: context.colors.textHint)),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(Money.format(s.amount), style: const TextStyle(fontSize: AppFontSize.f13, fontWeight: AppFontWeight.semibold)),
          ),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.method.isEmpty ? '-' : context.l10n.paymentMethodLabel(s.method),
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: AppFontSize.f13)),
                if (s.reference.isNotEmpty)
                  Text(s.reference,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: AppFontSize.f11_5, color: context.colors.textHint)),
              ],
            ),
          ),
          Expanded(flex: 2, child: Align(alignment: Alignment.centerLeft, child: _statusChip(s.status))),
          Expanded(flex: 5, child: _detailsFor(s)),
        ],
      ),
    );
  }

  // Narrow layout (phones): the same information as a card per submission.
  Widget _buildNarrowCard(_Submission s) {
    final submitted = s.submittedAt;
    final color = submissionStatusColor(s.status, context.colors);
    final methodLine = [if (s.method.isNotEmpty) context.l10n.paymentMethodLabel(s.method), if (s.reference.isNotEmpty) s.reference].join(' · ');

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.r12),
        border: Border.all(color: context.colors.textHint.withValues(alpha: AppAlpha.a15)),
      ),
      // Clipped so the bar down the left follows the card's rounded corners.
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(_planName(s).isEmpty ? '-' : _planName(s),
                        style: const TextStyle(fontSize: AppFontSize.f14, fontWeight: AppFontWeight.bold)),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Text(Money.format(s.amount), style: const TextStyle(fontSize: AppFontSize.f14, fontWeight: AppFontWeight.semibold)),
                ],
              ),
              if (s.promotionLabel != null && s.promotionLabel!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.s2),
                Text(s.promotionLabel!, style: TextStyle(fontSize: AppFontSize.f11_5, color: context.colors.textHint)),
              ],
              const SizedBox(height: AppSpacing.s6),
              Row(
                children: [
                  _statusChip(s.status),
                  const SizedBox(width: AppSpacing.s8),
                  if (submitted != null)
                    Expanded(
                      child: Text(_dateTimeFormat.format(submitted),
                          style: TextStyle(fontSize: AppFontSize.f11_5, color: context.colors.textHint)),
                    ),
                ],
              ),
              if (methodLine.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.s6),
                Text(methodLine, style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textSoft)),
              ],
              if (s.status != PaymentSubmissionStatus.pending.key) ...[
                const SizedBox(height: AppSpacing.s8),
                _detailsFor(s),
              ],
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
        runSpacing: AppSpacing.s4,
        children: [
          Text(
            total == 0
                ? context.l10n.subscription_noSubmissions
                : context.l10n.subscription_showingRange(total, start, end),
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
                  onChanged: (v) {
                    if (v != null) {
                      setState(() {
                        _pageSize = v;
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
              Text(context.l10n.common_page(page), style: const TextStyle(fontSize: AppFontSize.f13)),
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
