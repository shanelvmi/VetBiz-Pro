// RV2: a host for PhoneListScaffold whose data a test changes as a screen
// would (rv2_list_reveal_test, rv2_list_frame_test), and what they share.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';
import 'package:vetbiz_pro/widgets/phone_list/phone_list_scaffold.dart';
import 'package:vetbiz_pro/widgets/phone_list/phone_quick_chips.dart';
import 'package:vetbiz_pro/widgets/reveal/reveal.dart';

const revealSkeletonKey = ValueKey('phoneList-revealSkeleton');
const inListSkeletonKey = ValueKey('phoneList-skeleton');
const summarySlotKey = ValueKey('phoneList-summarySlot');
const summaryLineKey = ValueKey('phoneList-summaryLine');

final _themes = <Brightness, ThemeData>{};

/// What a screen passes the list; the test changes it as a screen would.
class ListData {
  List<String> items = const [];
  bool loading = true;
  Object? error;
  String? summaryLine;
  bool summaryPending = false;
  bool? firstPageAnswered;
  bool hasMore = false;
  bool loadingMore = false;
  String chip = 'All';
}

class ListHost extends StatefulWidget {
  const ListHost({super.key, required this.data, this.onLoadMore, this.onRefresh});

  final ListData data;
  final VoidCallback? onLoadMore;
  final Future<void> Function()? onRefresh;

  @override
  State<ListHost> createState() => ListHostState();
}

class ListHostState extends State<ListHost> {
  final _search = TextEditingController();

  void update(void Function(ListData d) change) => setState(() => change(widget.data));

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    return PhoneListScaffold<String>(
      title: 'Sales',
      menu: const [],
      searchController: _search,
      searchHint: 'Search',
      onSearchChanged: (_) {},
      onSearchClosed: () {},
      quickChips: PhoneQuickChips(
        values: const ['All', 'Unpaid'],
        selected: d.chip,
        label: (v) => v,
        onSelected: (v) => update((d) {
          d.chip = v;
          d.items = const [];
          d.loading = true;
        }),
      ),
      filtersActive: false,
      onFilter: () {},
      appliedFilters: const [],
      summaryLine: d.summaryLine,
      summaryPending: d.summaryPending,
      firstPageAnswered: d.firstPageAnswered,
      onSummary: () {},
      items: d.items,
      idOf: (s) => s,
      dateOf: (_) => DateTime(2026, 11, 8),
      amountOf: (_) => 0,
      grouped: false,
      tileBuilder: (context, s, {required bool grouped}) => SizedBox(height: 64, child: Text('row $s')),
      loading: d.loading,
      error: d.error,
      onRetry: () {},
      emptyIcon: Icons.inbox,
      emptyText: 'No sales yet',
      fab: PhoneListAction(label: 'Add', icon: Icons.add, onPressed: () {}),
      hasMore: d.hasMore,
      loadingMore: d.loadingMore,
      onLoadMore: widget.onLoadMore ?? () {},
      onRefresh: widget.onRefresh ?? () async {},
    );
  }
}

final listHost = GlobalKey<ListHostState>();

Future<void> pumpList(
  WidgetTester tester,
  ListData data, {
  bool still = false,
  Brightness brightness = Brightness.light,
  Locale locale = const Locale('en'),
  Size size = const Size(390, 844),
  VoidCallback? onLoadMore,
  Future<void> Function()? onRefresh,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: locale,
    theme: _themes[brightness] ??= AppTheme.build(AppColorTheme.pasture, brightness),
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: still),
        child: ListHost(key: listHost, data: data, onLoadMore: onLoadMore, onRefresh: onRefresh),
      ),
    ),
  ));
}

void setList(void Function(ListData d) change) => listHost.currentState!.update(change);

bool revealSkeletonShown() => find.byKey(revealSkeletonKey).evaluate().isNotEmpty;

/// The rise of the revealed list (0 once it has arrived, or with no reveal).
double revealRise(WidgetTester tester) {
  final t = find.ancestor(of: find.byType(RevealedContent), matching: find.byType(Transform));
  if (t.evaluate().isEmpty) return 0;
  return tester.widget<Transform>(t.first).transform.getTranslation().y;
}

/// The rects of what surrounds the list: they never move.
Map<String, Rect> listFrame(WidgetTester tester) => {
      'appBar': tester.getRect(find.byType(AppBar)),
      'fab': tester.getRect(find.byKey(const ValueKey('phoneList-fab'))),
      'body': tester.getRect(find.byKey(const ValueKey('phoneList-revealGroup'))),
    };

Rect chipsRect(WidgetTester tester) => tester.getRect(find.byType(PhoneQuickChips).first);
