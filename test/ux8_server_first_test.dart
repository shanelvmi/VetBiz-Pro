// UX8 Fix 3: a live list's first answer, whole (holdCacheUntilServer). The
// cache's few rows, then the server's full list, used to draw a half-list
// and then jump. Now: the skeleton until the server answers, then the full
// list at once; offline, the cached rows after AppTimeouts.cacheFallback.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/config/app_timeouts.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';
import 'package:vetbiz_pro/utils/server_first.dart';
import 'package:vetbiz_pro/widgets/phone_list/phone_list_skeleton.dart';

typedef _Answer = ({List<String> rows, bool cache});

Stream<_Answer> _held(StreamController<_Answer> source) =>
    holdCacheUntilServer(source.stream, isFromCache: (a) => a.cache);

const _partial = (rows: ['a', 'b'], cache: true);
const _full = (rows: ['a', 'b', 'c', 'd', 'e'], cache: false);

void main() {
  testWidgets('cache then server: only the server answer is given first', (tester) async {
    final source = StreamController<_Answer>();
    final seen = <_Answer>[];
    _held(source).listen(seen.add);
    source.add(_partial);
    await tester.pump(const Duration(milliseconds: 500));
    expect(seen, isEmpty, reason: 'the cached half-list is held');
    source.add(_full);
    await tester.pump();
    expect(seen, [_full]);
    // After the first answer, everything passes (a later cache answer too).
    source.add(_partial);
    await tester.pump();
    expect(seen, [_full, _partial]);
    await tester.pump(AppTimeouts.cacheFallback);
    expect(seen, hasLength(2), reason: 'the timer was cancelled');
  });

  testWidgets('offline: the cached rows after the fallback, not before', (tester) async {
    final source = StreamController<_Answer>();
    final seen = <_Answer>[];
    _held(source).listen(seen.add);
    source.add(_partial);
    await tester.pump(AppTimeouts.cacheFallback - const Duration(milliseconds: 1));
    expect(seen, isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    expect(seen, [_partial]);
  });

  testWidgets('a cache answer that only comes after the fallback passes at once', (tester) async {
    final source = StreamController<_Answer>();
    final seen = <_Answer>[];
    _held(source).listen(seen.add);
    await tester.pump(AppTimeouts.cacheFallback * 2);
    source.add(_partial);
    await tester.pump();
    expect(seen, [_partial]);
  });

  testWidgets('errors pass at once', (tester) async {
    final source = StreamController<_Answer>();
    final errors = [];
    _held(source).listen((_) {}, onError: errors.add);
    source.addError('denied');
    await tester.pump();
    expect(errors, ['denied']);
    await tester.pump(AppTimeouts.cacheFallback); // the offline timer runs out
  });

  testWidgets('a list drawn from it: the skeleton, then the full list, never a partial one', (tester) async {
    final source = StreamController<_Answer>();
    final stream = _held(source);
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.build(AppColorTheme.pasture, Brightness.light),
      home: Scaffold(
        body: StreamBuilder<_Answer>(
          stream: stream,
          builder: (context, snapshot) => !snapshot.hasData
              ? const SingleChildScrollView(child: PhoneListSkeleton(pulse: false))
              : ListView(children: [for (final r in snapshot.data!.rows) Text('row $r')]),
        ),
      ),
    ));
    final drawn = <int>{};
    void look() {
      final rows = find.textContaining('row ').evaluate().length;
      drawn.add(rows);
      if (rows == 0) expect(find.byType(PhoneListSkeleton), findsOneWidget);
    }

    look();
    source.add(_partial);
    await tester.pump(const Duration(milliseconds: 500));
    look();
    source.add(_full);
    await tester.pump();
    await tester.pump();
    look();
    expect(drawn, {0, 5}, reason: 'skeleton, then all five rows; never two');

    // Offline: a fresh list with only the cache shows its rows after the wait.
    final offline = StreamController<_Answer>();
    final offlineStream = _held(offline);
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.build(AppColorTheme.pasture, Brightness.light),
      key: UniqueKey(),
      home: Scaffold(
        body: StreamBuilder<_Answer>(
          stream: offlineStream,
          builder: (context, snapshot) => !snapshot.hasData
              ? const SingleChildScrollView(child: PhoneListSkeleton(pulse: false))
              : ListView(children: [for (final r in snapshot.data!.rows) Text('row $r')]),
        ),
      ),
    ));
    offline.add(_partial);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(PhoneListSkeleton), findsOneWidget);
    await tester.pump(AppTimeouts.cacheFallback);
    expect(find.textContaining('row '), findsNWidgets(2));
    unawaited(source.close());
    unawaited(offline.close());
  });
}
