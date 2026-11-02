// PH5a R10: a phone list shows every page reached so far
// (CursorPaginatedListController.loadedItems), with the same page size and
// cursors as the page bar's pages.
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/services/cursor_paginated_list_controller.dart';

void main() {
  test('loadedItems: the pages up to the current one, in order; a new session starts over', () async {
    final data = List.generate(7, (i) => i);
    var fetches = 0;
    late CursorPaginatedListController<int> c;
    c = CursorPaginatedListController<int>(
      pageSize: 3,
      fetchPage: ({required snapshotAt, required pageSize, startAfterDocument}) async {
        final start = fetches++ * pageSize;
        final items = data.skip(start).take(pageSize).toList();
        return CursorPage(items: items, lastDocument: null, hasMore: items.length == pageSize);
      },
    );
    expect(c.loadedItems, isEmpty);
    await c.openSession('q');
    expect(c.loadedItems, [0, 1, 2]);
    await c.goToNextPage();
    await c.goToNextPage();
    expect(c.loadedItems, data);
    expect(c.items, [6], reason: 'the page bar still sees one page');
    expect(c.hasNextPage, isFalse);
    expect(fetches, 3);
    fetches = 0;
    await c.openSession('other');
    expect(c.loadedItems, [0, 1, 2]);
  });
}
