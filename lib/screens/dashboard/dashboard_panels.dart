import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../config/app_date_format.dart';
import '../../config/app_limits.dart';
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
    return (snapshotsOf ?? (q) => q.snapshots())(query).map((s) => s.docs);
  }
  return mergedLogStream([
    logs.where(Fields.userId, isEqualTo: uid).orderBy('timestamp', descending: true).limit(AppLimits.recentActivityCount),
    logs.where('targetUserId', isEqualTo: uid).orderBy('timestamp', descending: true).limit(AppLimits.recentActivityCount),
  ], limit: AppLimits.recentActivityCount);
}

/// What sits under the Today at a Glance strip: the sales chart and the
/// Recent Activity feed (side by side when [wide], one above the other
/// otherwise), then the quick actions.
class DashboardLowerPanels extends StatelessWidget {
  final bool wide;
  final Widget chart;
  final Widget feed;
  final Widget quickActions;

  const DashboardLowerPanels(
      {super.key, required this.wide, required this.chart, required this.feed, required this.quickActions});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
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
class RecentActivityFeed extends StatelessWidget {
  final Stream<List<LogDoc>>? stream;

  const RecentActivityFeed({super.key, required this.stream});

  @override
  Widget build(BuildContext context) {
    final stream = this.stream;
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
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.s20),
              child: Center(child: Text(context.l10n.dashboard_noActivityYet, style: TextStyle(color: context.colors.textMuted))),
            )
          else
            StreamBuilder<List<LogDoc>>(
              stream: stream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.s20),
                    child: Center(
                      child: Text(context.l10n.dashboard_recentActivityLoadFailed, style: TextStyle(color: context.colors.textMuted)),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.s20),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  );
                }
                final docs = snapshot.data!;
                if (docs.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.s20),
                    child: Center(child: Text(context.l10n.dashboard_noActivityYet, style: TextStyle(color: context.colors.textMuted))),
                  );
                }
                return Column(
                  children: [
                    for (int i = 0; i < docs.length; i++) ...[
                      if (i > 0) Divider(height: 1, color: context.colors.textHint.withValues(alpha: AppAlpha.a15)),
                      _activityTile(context, docs[i].data()),
                    ],
                  ],
                );
              },
            ),
        ],
      ),
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
