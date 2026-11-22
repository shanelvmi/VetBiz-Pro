import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/polish_metrics.dart';
import '../../theme/theme_context.dart';
import '../../ui/polish/filter_row.dart';
import '../../widgets/shell/page_header.dart';
import '../activity/activity_log_screen.dart';
import 'business_hours_screen.dart';
import 'business_profile_screen.dart';

/// UX5 (owner 2026-11-22): Business Profile on PC and tablet is one page with
/// tabs. Each tab is the existing screen, embedded (no app bar of its own),
/// so its logic is unchanged and each still opens alone where something
/// else links to it (the phone's Business Hours row and profile page, the
/// Dashboard's Activity Log). The tab row is the left-aligned FilterRow (one
/// accent). A tab is built the first time it is chosen, then kept
/// (IndexedStack), so switching back keeps its state and the Activity Log's
/// streams start only when it is opened.
/// UX7 (owner 2026-11-22): the Profile tab is gone. Its content (logo, name,
/// facility type, Upload Logo) is a permanent identity card above the tabs
/// (BusinessProfileScreen embedded, its pending-logo save unchanged); the
/// tabs are Business Hours, the default, then Activity Log.
class BusinessProfileTabs extends StatefulWidget {
  final FirebaseFirestore? firestore;
  final FirebaseAuth? auth;
  final String initialTab;

  const BusinessProfileTabs({super.key, this.firestore, this.auth, this.initialTab = hours});

  /// The tabs (keys for tests and for [initialTab]).
  static const hours = 'hours';
  static const activityLog = 'activity_log';
  static const tabs = [hours, activityLog];

  @override
  State<BusinessProfileTabs> createState() => _BusinessProfileTabsState();
}

class _BusinessProfileTabsState extends State<BusinessProfileTabs> {
  late String _tab = BusinessProfileTabs.tabs.contains(widget.initialTab) ? widget.initialTab : BusinessProfileTabs.hours;
  late final Set<String> _built = {_tab};

  String _label(String tab) => switch (tab) {
        BusinessProfileTabs.activityLog => context.l10n.export_activityLog,
        _ => context.l10n.hours_title,
      };

  Widget _body(String tab) => switch (tab) {
        BusinessProfileTabs.activityLog => ActivityLogScreen(firestore: widget.firestore, auth: widget.auth, embedded: true),
        _ => BusinessHoursScreen(firestore: widget.firestore, embedded: true),
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: PageHeader(title: context.l10n.profile_title),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BusinessProfileScreen(firestore: widget.firestore, embedded: true),
          const SizedBox(height: PolishMetrics.gapInGroup),
          FilterRow(
            values: BusinessProfileTabs.tabs,
            selected: _tab,
            label: _label,
            keyPrefix: 'businessTab-',
            onSelected: (t) => setState(() {
              _tab = t;
              _built.add(t);
            }),
          ),
          Expanded(
            child: IndexedStack(
              index: BusinessProfileTabs.tabs.indexOf(_tab),
              children: [
                for (final t in BusinessProfileTabs.tabs)
                  _built.contains(t) ? KeyedSubtree(key: ValueKey('businessTabBody-$t'), child: _body(t)) : const SizedBox.shrink(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
