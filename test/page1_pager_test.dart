// PAGE1: the shared server-side pager. One page reads pageSize + 1 (the
// extra row only says Next exists); Previous reads nothing; a merged list
// keeps a cursor per source and reads at most 2 x (pageSize + 1) per page.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/services/cursor_paginated_list_controller.dart';
import 'package:vetbiz_pro/services/merged_cursor.dart';

import 'helpers/counting_firestore.dart';

Future<void> _seed(CountingFirestore db, String collection, int count, {int offset = 0, int step = 1}) async {
  for (var i = 0; i < count; i++) {
    final n = offset + i * step;
    await db.inner.collection(collection).doc('$collection-${n.toString().padLeft(4, '0')}').set({
      'at': Timestamp.fromMillisecondsSinceEpoch(1700000000000 + n * 1000),
    });
  }
}

CursorPaginatedListController<String> _single(CountingFirestore db, {int pageSize = 10}) =>
    CursorPaginatedListController<String>(
      pageSize: pageSize,
      fetchPage: ({required snapshotAt, required pageSize, startAfterDocument}) async {
        Query<Map<String, dynamic>> q = db.collection('rows').orderBy('at', descending: true);
        if (startAfterDocument != null) q = q.startAfterDocument(startAfterDocument);
        final snap = await q.limit(pageSize + 1).get();
        return CursorPage.fromDocs(snap.docs, pageSize, (d) => d.id);
      },
    );

void main() {
  test('page 1 reads pageSize + 1; Next reads pageSize + 1; Previous reads nothing; the last page has no Next', () async {
    final db = CountingFirestore();
    await _seed(db, 'rows', 23);
    final c = _single(db);

    await c.openSession('q');
    expect(c.items.length, 10);
    expect(db.reads, 11);
    expect(c.hasNextPage, isTrue);

    db.resetCounts();
    await c.goToNextPage();
    expect(db.reads, 11);
    expect(c.currentPage, 2);

    db.resetCounts();
    c.goToPreviousPage();
    expect(db.reads, 0);
    expect(c.currentPage, 1);
    await c.goToNextPage();
    expect(db.reads, 0, reason: 'a page already visited is cached');

    await c.goToNextPage();
    expect(c.items.length, 3);
    expect(c.hasNextPage, isFalse, reason: 'the extra row did not come back');
  });

  test('exactly one full page: no Next, no empty fetch', () async {
    final db = CountingFirestore();
    await _seed(db, 'rows', 10);
    final c = _single(db);
    await c.openSession('q');
    expect(c.items.length, 10);
    expect(c.hasNextPage, isFalse);
  });

  test('page size change and a new signature go back to page 1', () async {
    final db = CountingFirestore();
    await _seed(db, 'rows', 60);
    final c = _single(db);
    await c.openSession('q');
    await c.goToNextPage();
    await c.setPageSize(25);
    expect(c.currentPage, 1);
    expect(c.items.length, 25);
    await c.goToNextPage();
    await c.openSession('filter');
    expect(c.currentPage, 1);
  });

  test('retry: the first page again after a failed open, the next page after a failed Next', () async {
    final db = CountingFirestore();
    await _seed(db, 'rows', 15);
    final c = _single(db);
    db.failGets = true;
    await c.openSession('q');
    expect(c.error, isNotNull);
    db.failGets = false;
    await c.retry();
    expect(c.error, isNull);
    expect(c.items.length, 10);

    db.failGets = true;
    await c.goToNextPage();
    expect(c.error, isNotNull);
    expect(c.currentPage, 1, reason: 'the page shown stays');
    db.failGets = false;
    await c.retry();
    expect(c.currentPage, 2);
    expect(c.items.length, 5);
  });

  group('merged pages', () {
    int newestFirst(DocumentSnapshot<Map<String, dynamic>> a, DocumentSnapshot<Map<String, dynamic>> b) {
      final byTime = (b.data()!['at'] as Timestamp).compareTo(a.data()!['at'] as Timestamp);
      return byTime != 0 ? byTime : b.id.compareTo(a.id);
    }

    CursorPaginatedListController<DocumentSnapshot<Map<String, dynamic>>> merged(
      CountingFirestore db,
      List<String> collections, {
      int pageSize = 10,
      String Function(DocumentSnapshot<Map<String, dynamic>>)? key,
    }) =>
        CursorPaginatedListController.after(
          pageSize: pageSize,
          fetchPageAfter: ({required snapshotAt, required pageSize, after}) => fetchMergedPage(
            sources: [
              for (final c in collections) MergedSource(db.collection(c).orderBy('at', descending: true), (d) => d),
            ],
            pageSize: pageSize,
            after: after,
            compare: newestFirst,
            key: key,
          ),
        );

    test('two sources interleave newest first; every row once; at most 2 x (n + 1) reads a page', () async {
      final db = CountingFirestore();
      await _seed(db, 'a', 17, step: 2); // even seconds
      await _seed(db, 'b', 9, offset: 1, step: 3); // odd-ish seconds
      final c = merged(db, ['a', 'b']);

      final seen = <String>[];
      await c.openSession('q');
      expect(db.reads, lessThanOrEqualTo(22));
      seen.addAll(c.items.map((d) => d.id));
      while (c.hasNextPage) {
        db.resetCounts();
        await c.goToNextPage();
        expect(db.reads, lessThanOrEqualTo(22));
        seen.addAll(c.items.map((d) => d.id));
      }
      expect(seen.length, 26);
      expect(seen.toSet().length, 26);
      final times = [
        for (final id in seen) int.parse(id.split('-').last),
      ];
      expect(times, [...times]..sort((x, y) => y.compareTo(x)));

      db.resetCounts();
      c.goToPreviousPage();
      expect(db.reads, 0);
    });

    test('a row both sources return is shown once, also across a page edge', () async {
      final db = CountingFirestore();
      await _seed(db, 'a', 12);
      await _seed(db, 'b', 12);
      final c = merged(db, ['a', 'b'], pageSize: 5, key: (d) => d.id.split('-').last);
      final seen = <String>[];
      await c.openSession('q');
      seen.addAll(c.items.map((d) => d.id.split('-').last));
      while (c.hasNextPage) {
        await c.goToNextPage();
        seen.addAll(c.items.map((d) => d.id.split('-').last));
      }
      expect(seen.length, 12);
      expect(seen.toSet().length, 12);
    });

    test('one source empty: pages like a single query', () async {
      final db = CountingFirestore();
      await _seed(db, 'a', 11);
      final c = merged(db, ['a', 'b']);
      await c.openSession('q');
      expect(c.items.length, 10);
      expect(c.hasNextPage, isTrue);
      await c.goToNextPage();
      expect(c.items.length, 1);
      expect(c.hasNextPage, isFalse);
    });
  });
}
