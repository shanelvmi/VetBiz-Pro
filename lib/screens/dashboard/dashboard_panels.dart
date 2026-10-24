import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../config/app_date_format.dart';
import '../../config/app_defaults.dart';
import '../../config/app_limits.dart';
import '../../config/app_timeouts.dart';
import '../../config/money.dart';
import '../../data/collections.dart';
import '../../data/fields.dart';
import '../../l10n/l10n.dart';
import '../../theme/activity_type_style.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_text.dart';
import '../../theme/theme_context.dart';
import '../../utils/merged_query_stream.dart';
import '../../utils/text_sanitizer.dart';
import '../activity/activity_log_screen.dart';
import 'insights_screen.dart';

/// The Recent Activity feed's live entries. An admin sees the latest
/// entries; an ASSISTANT only the latest that are theirs (what they did, or
/// what is about them, [uid]) - not the admin matters of the facility. See
/// firestore.rules: the rule only allows the scoped query.
///
/// [snapshotsOf] is for tests: cloud_firestore shares one live stream per
/// query between listeners (a broadcast that replays nothing), the fake
/// Firestore does not. The app uses Query.snapshots.
Stream<List<LogDoc>> recentActivityStream(FirebaseFirestore firestore, String facilityId,
    {required bool isAdmin,
    required String uid,
    @visibleForTesting Stream<QuerySnapshot<Map<String, dynamic>>> Function(Query<Map<String, dynamic>>)? snapshotsOf}) {
  final logs = firestore.collection(Collections.facilities).doc(facilityId).collection(Collections.activityLogs);
  if (isAdmin) {
    final query = logs.orderBy('timestamp', descending: true).limit(AppLimits.recentActivityCount);
    // Shared, so a feed rebuilt elsewhere after a resize gets the entries at
    // once (DASH-1).
    return shareLatest(() => (snapshotsOf ?? (q) => q.snapshots())(query).map((s) => s.docs));
  }
  return mergedLogStream([
    logs.where(Fields.userId, isEqualTo: uid).orderBy('timestamp', descending: true).limit(AppLimits.recentActivityCount),
    logs.where('targetUserId', isEqualTo: uid).orderBy('timestamp', descending: true).limit(AppLimits.recentActivityCount),
  ], limit: AppLimits.recentActivityCount);
}

/// What sits under the summary cards: the Today at a Glance strip, the sales
/// chart and the Recent Activity feed (side by side when [wide], one above the other
/// otherwise), then the quick actions.
class DashboardLowerPanels extends StatelessWidget {
  final Widget glance;
  final bool wide;
  final Widget chart;
  final Widget feed;
  final Widget quickActions;

  const DashboardLowerPanels(
      {super.key, required this.glance, required this.wide, required this.chart, required this.feed, required this.quickActions});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        glance,
        const SizedBox(height: AppSpacing.s16),
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 2, child: chart),
              const SizedBox(width: AppSpacing.s16),
              Expanded(child: feed),
            ],
          )
        else ...[
          chart,
          const SizedBox(height: AppSpacing.s16),
          feed,
        ],
        const SizedBox(height: AppSpacing.s16),
        quickActions,
      ],
    );
  }
}

/// The dashboard's Recent Activity card. [stream] is null while there is no
/// facility yet.
///
/// The dashboard gives it a GlobalKey, so a resize that moves it to the
/// other layout branch keeps this state and its subscription (DASH-1). It
/// never spins for ever: with no answer after
/// AppTimeouts.liveCardFirstAnswer, or on an error, it says it couldn't load
/// and offers Retry, which calls [onRetry] (the dashboard opens a new
/// stream).
class RecentActivityFeed extends StatefulWidget {
  final Stream<List<LogDoc>>? stream;
  final VoidCallback? onRetry;

  const RecentActivityFeed({super.key, required this.stream, this.onRetry});

  @override
  State<RecentActivityFeed> createState() => _RecentActivityFeedState();
}

class _RecentActivityFeedState extends State<RecentActivityFeed> {
  Timer? _firstAnswer;
  bool _answered = false;
  bool _timedOut = false;

  @override
  void initState() {
    super.initState();
    _waitForFirstAnswer();
  }

  @override
  void didUpdateWidget(RecentActivityFeed oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stream != widget.stream) _waitForFirstAnswer();
  }

  @override
  void dispose() {
    _firstAnswer?.cancel();
    super.dispose();
  }

  void _waitForFirstAnswer() {
    _firstAnswer?.cancel();
    _answered = false;
    _timedOut = false;
    if (widget.stream == null) return;
    _firstAnswer = Timer(AppTimeouts.liveCardFirstAnswer, () {
      if (mounted && !_answered) setState(() => _timedOut = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final stream = widget.stream;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.s18),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.r12),
        border: Border.all(color: context.colors.textHint.withValues(alpha: AppAlpha.a15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.history, size: AppIconSize.i18, color: context.colors.primary),
                  const SizedBox(width: AppSpacing.s8),
                  Text(context.l10n.dashboard_recentActivity, style: const TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f14_5)),
                ],
              ),
              TextButton(
                // Opens as a modal over the Dashboard (full screen on a phone).
                onPressed: () => showActivityLog(context),
                child: Text(context.l10n.dashboard_viewAll),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
          if (stream == null)
            _reserved(context, Center(child: Text(context.l10n.dashboard_noActivityYet, style: TextStyle(color: context.colors.textMuted))))
          else
            StreamBuilder<List<LogDoc>>(
              stream: stream,
              builder: (context, snapshot) {
                if (snapshot.hasData || snapshot.hasError) {
                  _answered = true;
                  _firstAnswer?.cancel();
                }
                if (snapshot.hasError || (!snapshot.hasData && _timedOut)) {
                  return _reserved(
                    context,
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(context.l10n.dashboard_recentActivityLoadFailed, style: TextStyle(color: context.colors.textMuted)),
                          if (widget.onRetry != null)
                            TextButton(onPressed: widget.onRetry, child: Text(context.l10n.common_retry)),
                        ],
                      ),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return _reserved(context, const Center(child: CircularProgressIndicator(strokeWidth: 2)));
                }
                final docs = snapshot.data!;
                if (docs.isEmpty) {
                  return _reserved(context, Center(child: Text(context.l10n.dashboard_noActivityYet, style: TextStyle(color: context.colors.textMuted))));
                }
                return _reserved(context, _tiles(context, [for (final d in docs) d.data()]), fill: false);
              },
            ),
        ],
      ),
    );
  }

  // The feed keeps the height of a full list in every state (DASH-1): an
  // invisible list of AppLimits.recentActivityCount one-line entries sits
  // under what is shown, so loading, an error, an empty feed or a short one
  // never moves what comes below. A small state ([fill]) is centred in that
  // room; the list starts at the top and may grow past it (two-line entries).
  Widget _reserved(BuildContext context, Widget child, {bool fill = true}) {
    return Stack(
      children: [
        Visibility(
          visible: false,
          maintainSize: true,
          maintainAnimation: true,
          maintainState: true,
          child: _tiles(context, List.filled(AppLimits.recentActivityCount, const <String, dynamic>{})),
        ),
        fill ? Positioned.fill(child: child) : child,
      ],
    );
  }

  Widget _tiles(BuildContext context, List<Map<String, dynamic>> entries) {
    return Column(
      children: [
        for (int i = 0; i < entries.length; i++) ...[
          if (i > 0) Divider(height: 1, color: context.colors.textHint.withValues(alpha: AppAlpha.a15)),
          _activityTile(context, entries[i]),
        ],
      ],
    );
  }

  Widget _activityTile(BuildContext context, Map<String, dynamic> data) {
    final actionType = (data['actionType'] as String?) ?? '';
    final description = sanitizeForDisplay((data['description'] as String?) ?? '');
    final timestamp = data['timestamp'];
    String timeStr = '';
    if (timestamp is Timestamp) {
      timeStr = AppDateFormat.time12.format(timestamp.toDate());
    }
    final color = ActivityTypeStyle.color(actionType, context.colors);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: color.withValues(alpha: AppAlpha.a10), borderRadius: BorderRadius.circular(AppRadius.r8)),
            child: Icon(ActivityTypeStyle.icon(actionType), size: AppIconSize.i16, color: color),
          ),
          const SizedBox(width: AppSpacing.s10),
          Expanded(
            child: Text(description, style: const TextStyle(fontSize: AppFontSize.f12_5), maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: AppSpacing.s8),
          Text(timeStr, style: TextStyle(fontSize: AppFontSize.f11, color: context.colors.textHint)),
        ],
      ),
    );
  }
}

/// The Today at a Glance strip: today's sales, services and money collected
/// (null until loaded; [isLoading] during the first load), the debtors
/// count, and the Insights button.
class TodayGlanceStrip extends StatelessWidget {
  final int? saleCount;
  final int? serviceCount;
  final double? collected;
  final bool isLoading;
  final int debtorCount;

  const TodayGlanceStrip(
      {super.key,
      required this.saleCount,
      required this.serviceCount,
      required this.collected,
      required this.isLoading,
      required this.debtorCount});

  @override
  Widget build(BuildContext context) {
    final loading = saleCount == null && isLoading;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s18, vertical: AppSpacing.s14),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.r12),
        border: Border.all(color: context.colors.textHint.withValues(alpha: AppAlpha.a15)),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 24,
        runSpacing: 10,
        children: [
          Text(context.l10n.dashboard_todayAtAGlance, style: TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f13_5, color: context.colors.textPrimary)),
          // While the first load runs the three stats keep their place with the
          // values hidden, so the strip does not grow when they come (DASH-1).
          _glanceStat(context, Icons.shopping_cart_outlined, '${saleCount ?? 0}', context.l10n.dashboard_sales, context.colors.primary, hideValue: loading),
          _glanceStat(context, Icons.build_outlined, '${serviceCount ?? 0}', context.l10n.dashboard_services, context.colors.chart1, hideValue: loading),
          _glanceStat(context, Icons.payments_outlined, Money.format(collected ?? (loading ? AppDefaults.glanceAmountPlaceholder : 0)), context.l10n.sales_collected, context.colors.primary, hideValue: loading),
          _glanceStat(context, Icons.folder_outlined, '$debtorCount', context.l10n.dashboard_outstandingDebts(debtorCount), context.colors.accent),
          OutlinedButton.icon(
            onPressed: () => showInsightsScreen(context),
            icon: Icon(Icons.insights, size: AppIconSize.i16, color: context.colors.primary),
            label: Text(context.l10n.insights_title, style: TextStyle(color: context.colors.primary)),
            style: OutlinedButton.styleFrom(side: BorderSide(color: context.colors.primary)),
          ),
        ],
      ),
    );
  }

  Widget _glanceStat(BuildContext context, IconData icon, String value, String label, Color color,
      {bool hideValue = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: AppIconSize.i16, color: color),
        const SizedBox(width: AppSpacing.s6),
        Visibility(
          visible: !hideValue,
          maintainSize: true,
          maintainAnimation: true,
          maintainState: true,
          child: Text(value, style: TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f14, color: color)),
        ),
        const SizedBox(width: AppSpacing.s4),
        Text(label, style: TextStyle(fontSize: AppFontSize.f12_5, color: context.colors.textMuted)),
      ],
    );
  }
}
