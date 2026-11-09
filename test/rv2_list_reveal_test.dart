// RV2 (docs/design/screen_reveal.md section 8.1): every phone list arrives as
// Home does: the list's skeleton (the PH5a rows, the chips and the summary
// line at their real sizes) at once, then ONE fade and rise when the first
// page and the summary figures have answered, or at 1200 ms. Load more, pull
// to refresh, a filter change and a search never play it again.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/widgets/reveal/reveal.dart';

import 'helpers/rv2_list_host.dart';

const _skip = false;

void main() {
  testWidgets('the first page answers late: the skeleton at once, the reveal at 1200 ms, then the summary fills its slot',
      (tester) async {
    final data = ListData()..summaryPending = true;
    await pumpList(tester, data);
    expect(revealSkeletonShown(), isTrue);
    expect(find.byKey(inListSkeletonKey), findsOneWidget);
    final frame = listFrame(tester);
    final chips = chipsRect(tester);
    await tester.pump(const Duration(milliseconds: 1100));
    expect(revealSkeletonShown(), isTrue, reason: 'still waiting before 1200 ms');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    expect(find.byType(RevealedContent), findsWidgets);
    await tester.pump(const Duration(milliseconds: 400));
    expect(revealSkeletonShown(), isFalse);
    // Timed out: the rows keep the in-list skeleton, the summary its slot.
    expect(find.byKey(summarySlotKey), findsOneWidget);
    final slot = tester.getRect(find.byKey(summarySlotKey));
    setList((d) {
      d.loading = false;
      d.items = const ['a', 'b'];
    });
    await tester.pump();
    final firstRow = tester.getRect(find.text('row a'));
    setList((d) {
      d.summaryPending = false;
      d.summaryLine = '2 sales · Tsh 10,000';
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(summaryLineKey), findsOneWidget);
    expect(tester.getRect(find.byKey(summaryLineKey).first).top, greaterThanOrEqualTo(slot.top));
    expect(tester.getRect(find.text('row a')), firstRow, reason: 'the summary filled its slot: nothing moved');
    expect(listFrame(tester), frame);
    expect(chipsRect(tester), chips);
  }, skip: _skip);

  testWidgets('data already held: the list at once, no skeleton and no rise', (tester) async {
    final data = ListData()
      ..loading = false
      ..items = const ['a']
      ..summaryLine = '1 sale';
    await pumpList(tester, data);
    expect(revealSkeletonShown(), isFalse);
    expect(find.text('row a'), findsOneWidget);
    expect(revealRise(tester), 0);
  }, skip: _skip);

  testWidgets('a provider that already knows (firstPageAnswered) and holds an empty list: the empty state at once',
      (tester) async {
    final data = ListData()
      ..loading = false
      ..firstPageAnswered = true;
    await pumpList(tester, data);
    expect(revealSkeletonShown(), isFalse);
    expect(find.text('No sales yet'), findsOneWidget);
  }, skip: _skip);

  for (final outcome in ['empty', 'error']) {
    testWidgets('an $outcome result answers: it shows inside the revealed list, before 1200 ms', (tester) async {
      await pumpList(tester, ListData());
      await tester.pump(const Duration(milliseconds: 200));
      setList((d) {
        d.loading = false;
        if (outcome == 'error') d.error = 'boom';
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(revealSkeletonShown(), isFalse);
      expect(find.byKey(ValueKey('phoneList-$outcome')), findsOneWidget);
    }, skip: _skip);
  }

  testWidgets('Load more, pull to refresh, a filter change and a search never play the reveal again', (tester) async {
    var refreshed = 0;
    await pumpList(tester, ListData(), onRefresh: () async => refreshed++);
    setList((d) {
      d.loading = false;
      d.items = [for (var i = 0; i < 20; i++) '$i'];
      d.hasMore = true;
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(revealSkeletonShown(), isFalse);

    setList((d) => d.loadingMore = true);
    await tester.pump();
    setList((d) {
      d.loadingMore = false;
      d.items = [for (var i = 0; i < 30; i++) '$i'];
    });
    await tester.pump();
    expect(revealSkeletonShown(), isFalse, reason: 'Load more');

    await tester.fling(find.byKey(const ValueKey('phoneList-scroll')), const Offset(0, 600), 1000);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(revealSkeletonShown(), isFalse, reason: 'pull to refresh');

    await tester.tap(find.text('Unpaid').hitTestable());
    await tester.pump();
    expect(revealSkeletonShown(), isFalse, reason: 'a filter change');
    expect(find.byKey(inListSkeletonKey), findsOneWidget, reason: 'the in-list loading state, as before');
    expect(revealRise(tester), 0);

    await tester.tap(find.byTooltip('Search'));
    await tester.pump();
    await tester.enterText(find.byKey(const ValueKey('phoneList-searchField')), 'amina');
    setList((d) {
      d.loading = false;
      d.items = const ['amina'];
    });
    await tester.pump();
    expect(revealSkeletonShown(), isFalse, reason: 'a search');
    expect(revealRise(tester), 0);
    await tester.pump(const Duration(seconds: 2));
  }, skip: _skip);

  testWidgets('the reveal plays once: not again on a rebuild, a resize, a theme or a language change', (tester) async {
    final data = ListData();
    await pumpList(tester, data);
    setList((d) {
      d.loading = false;
      d.items = const ['a'];
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(revealSkeletonShown(), isFalse);
    await pumpList(tester, data, size: const Size(360, 740));
    expect(revealSkeletonShown(), isFalse, reason: 'resize');
    await pumpList(tester, data, size: const Size(360, 740), brightness: Brightness.dark);
    await tester.pump();
    expect(revealSkeletonShown(), isFalse, reason: 'theme');
    await pumpList(tester, data, size: const Size(360, 740), brightness: Brightness.dark, locale: const Locale('sw'));
    await tester.pump();
    expect(revealSkeletonShown(), isFalse, reason: 'language');
    expect(revealRise(tester), 0);
  }, skip: _skip);

  testWidgets('reduced motion: the list replaces the skeleton instantly, no rise', (tester) async {
    await pumpList(tester, ListData(), still: true);
    expect(revealSkeletonShown(), isTrue);
    setList((d) {
      d.loading = false;
      d.items = const ['a'];
    });
    await tester.pump();
    expect(revealSkeletonShown(), isFalse);
    expect(revealRise(tester), 0);
  }, skip: _skip);
}
