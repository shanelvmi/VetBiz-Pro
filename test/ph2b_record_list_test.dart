import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/config/money.dart';
import 'package:vetbiz_pro/theme/app_dimens.dart';
import 'package:vetbiz_pro/widgets/record_list.dart';

import 'helpers/screen_size_matrix.dart';

// PH2b S5: RecordList alone (no screen uses it yet; PH5 moves the lists).
const _skip = false;

class _Rec {
  final String name;
  final double amount;
  const _Rec(this.name, this.amount);
}

final _records = [
  const _Rec(matrixLongClientName, matrixBigAmount),
  for (var i = 1; i <= 20; i++) _Rec('$matrixLongProductName $i', matrixBigAmount + i),
];

final _columns = <RecordColumn<_Rec>>[
  RecordColumn(
    label: 'Jina la mteja au bidhaa iliyouzwa',
    flex: 3,
    minWidth: 160,
    cell: (context, r) => Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis),
  ),
  RecordColumn(
    label: 'Kiasi kilicholipwa',
    flex: 2,
    minWidth: 120,
    align: TextAlign.end,
    cell: (context, r) => Text(Money.format(r.amount), maxLines: 1, overflow: TextOverflow.ellipsis),
  ),
  RecordColumn(label: 'Hali', cell: (context, r) => const Text('Imelipwa', maxLines: 1, overflow: TextOverflow.ellipsis)),
];

Widget _card(BuildContext context, _Rec r) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(r.name),
        Text(Money.format(r.amount), style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );

/// A screen holding a RecordList.
Widget _screen({
  List<_Rec>? items,
  String? errorText,
  bool hasMore = false,
  bool loadingMore = false,
  void Function(_Rec)? onOpen,
  VoidCallback? onLoadMore,
  VoidCallback? onRetry,
  _Rec? selected,
  List<RecordColumn<_Rec>>? columns,
}) =>
    Scaffold(
      appBar: AppBar(title: const Text('Records')),
      body: RecordList<_Rec>(
        items: items,
        columns: columns ?? _columns,
        cardBuilder: _card,
        semanticsLabel: (r) => r.name,
        emptyText: 'Hakuna rekodi bado. Rekodi ya kwanza itaonekana hapa.',
        errorText: errorText,
        onRetry: onRetry,
        onOpen: onOpen ?? (_) {},
        isSelected: selected == null ? null : (r) => identical(r, selected),
        hasMore: hasMore,
        loadingMore: loadingMore,
        onLoadMore: onLoadMore ?? () {},
      ),
    );

void main() {
  if (!_skip) {
    screenSizeMatrix('RecordList with records', screen: () => _screen(items: _records, hasMore: true, selected: _records[1]));
    screenSizeMatrix('RecordList empty', screen: () => _screen(items: const []));
    screenSizeMatrix('RecordList loading', screen: () => _screen());
    screenSizeMatrix('RecordList error', screen: () => _screen(errorText: 'Imeshindwa kupakia rekodi.', onRetry: () {}));
  }

  testWidgets('a table with a header at 900 and wider, cards below', (tester) async {
    await pumpAtSize(tester, screen: _screen(items: _records), size: const Size(1200, 800));
    expect(find.text('Jina la mteja au bidhaa iliyouzwa'), findsOneWidget);
    expect(find.byType(Card), findsNothing);
    await pumpAtSize(tester, screen: _screen(items: _records), size: const Size(899, 800));
    expect(find.text('Jina la mteja au bidhaa iliyouzwa'), findsNothing);
  }, skip: _skip);

  testWidgets('the header stays while the rows scroll', (tester) async {
    await pumpAtSize(tester, screen: _screen(items: _records), size: const Size(1200, 800));
    final before = tester.getTopLeft(find.text('Kiasi kilicholipwa'));
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('Kiasi kilicholipwa')), before);
  }, skip: _skip);

  testWidgets('too narrow for the columns\' minimum widths: cards, never a sideways scroll', (tester) async {
    final wide = [
      for (final c in _columns) RecordColumn<_Rec>(label: c.label, cell: c.cell, flex: c.flex, minWidth: 400),
    ];
    await pumpAtSize(tester, screen: _screen(items: _records, columns: wide), size: const Size(1000, 800));
    expect(find.text('Jina la mteja au bidhaa iliyouzwa'), findsNothing);
    expect(tester.takeException(), isNull);
  }, skip: _skip);

  for (final size in const [Size(390, 844), Size(1200, 800)]) {
    testWidgets('at $size: a tap opens the record, rows are 48 high or more, the selected one says so', (tester) async {
      final opened = <_Rec>[];
      await pumpAtSize(tester, screen: _screen(items: _records, onOpen: opened.add, selected: _records[1]), size: size);
      await tester.tap(find.text(matrixLongClientName));
      expect(opened, [_records.first]);
      expect(tester.getSize(find.byType(InkWell).first).height, greaterThanOrEqualTo(AppSizes.minTapTarget));
      final semantics = tester.ensureSemantics();
      final node = tester.getSemantics(find.text(_records[1].name));
      expect(node, isSemantics(isButton: true, isSelected: true, hasTapAction: true));
      // The given label first; the card's own texts follow it.
      expect(node.label, startsWith(_records[1].name));
      semantics.dispose();
    }, skip: _skip);
  }

  testWidgets('on a phone the card text is at least 14 px', (tester) async {
    await pumpAtSize(tester, screen: _screen(items: _records), size: const Size(360, 740));
    expect(smallTexts(tester, min: 14), isEmpty);
  }, skip: _skip);

  testWidgets('load more: a button after the last record, a spinner while it loads', (tester) async {
    var asked = 0;
    await pumpAtSize(tester, screen: _screen(items: _records.take(2).toList(), hasMore: true, onLoadMore: () => asked++), size: const Size(390, 844));
    await tester.tap(find.text('Load more'));
    expect(asked, 1);
    await pumpAtSize(tester, screen: _screen(items: _records.take(2).toList(), loadingMore: true), size: const Size(390, 844));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Load more'), findsNothing);
  }, skip: _skip);

  testWidgets('loading, empty and error states; Retry calls back', (tester) async {
    await pumpAtSize(tester, screen: _screen(), size: const Size(390, 844));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await pumpAtSize(tester, screen: _screen(items: const []), size: const Size(390, 844));
    expect(find.textContaining('Hakuna rekodi bado'), findsOneWidget);
    var retried = 0;
    await pumpAtSize(tester, screen: _screen(errorText: 'Imeshindwa', onRetry: () => retried++), size: const Size(390, 844));
    expect(find.text('Imeshindwa'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(retried, 1);
  }, skip: _skip);
}
