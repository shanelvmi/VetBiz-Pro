import 'package:cloud_firestore/cloud_firestore.dart';

import 'cursor_paginated_list_controller.dart';

/// PAGE1: one of the queries a merged list pages over (Payments: payments
/// and other income; an assistant's Activity Log: what they did and what is
/// about them). [query] carries its filters and its newest-first order, no
/// limit and no cursor; [map] turns a document into the list's row.
class MergedSource<T> {
  const MergedSource(this.query, this.map);

  final Query<Map<String, dynamic>> query;
  final T Function(QueryDocumentSnapshot<Map<String, dynamic>> doc) map;
}

/// Where each source of a merged list stands: the last of its documents
/// shown so far (null: none yet, start from its top).
class MergedCursor {
  const MergedCursor(this.lastShown);

  final List<DocumentSnapshot<Map<String, dynamic>>?> lastShown;
}

/// One page of a merged list, for CursorPaginatedListController.after.
///
/// Firestore cursors belong to one query, so a list made of two queries
/// keeps a cursor per source: each source reads pageSize + 1 after its own
/// cursor, the rows are merged by [compare] (newest first), the first
/// pageSize are the page, and each source's cursor moves to the last of its
/// rows that made the page. Rows read but not shown are read again by the
/// next page, so a page costs at most sources x (pageSize + 1) reads (the
/// owner accepted 2 x (n + 1) for the two merged lists, PAGE1). A next page
/// exists when any row was left over.
///
/// [key] removes a row two sources both return (an activity entry the
/// assistant did about themselves): both copies sort together, both cursors
/// pass it, it is shown once.
Future<CursorPage<T>> fetchMergedPage<T>({
  required List<MergedSource<T>> sources,
  required int pageSize,
  required Object? after,
  required int Function(T a, T b) compare,
  String Function(T item)? key,
}) async {
  final previous = (after as MergedCursor?)?.lastShown ?? List.filled(sources.length, null);
  final snaps = await Future.wait([
    for (var i = 0; i < sources.length; i++)
      (previous[i] == null ? sources[i].query : sources[i].query.startAfterDocument(previous[i]!))
          .limit(pageSize + 1)
          .get(),
  ]);

  // Each source's rows stay in its own query's order; the merge only
  // compares the heads (ties: the earlier source), so a cursor always moves
  // past exactly the rows shown, whatever [compare] says about ties.
  final lists = [
    for (var i = 0; i < sources.length; i++) [for (final doc in snaps[i].docs) (doc: doc, item: sources[i].map(doc))],
  ];
  final heads = List.filled(sources.length, 0);
  final rows = <({int source, QueryDocumentSnapshot<Map<String, dynamic>> doc, T item})>[];
  while (true) {
    var next = -1;
    for (var i = 0; i < lists.length; i++) {
      if (heads[i] >= lists[i].length) continue;
      if (next < 0 || compare(lists[i][heads[i]].item, lists[next][heads[next]].item) < 0) next = i;
    }
    if (next < 0) break;
    final row = lists[next][heads[next]++];
    rows.add((source: next, doc: row.doc, item: row.item));
  }

  final lastShown = List.of(previous);
  final items = <T>[];
  final shownKeys = <String>{};
  var used = 0;
  for (final row in rows) {
    final k = key?.call(row.item);
    final duplicate = k != null && shownKeys.contains(k);
    // The page is full: stop at the next new row (a duplicate of a row
    // already shown is passed over, so it never opens the next page).
    if (items.length == pageSize && !duplicate) break;
    used++;
    lastShown[row.source] = row.doc;
    if (duplicate) continue;
    if (k != null) shownKeys.add(k);
    items.add(row.item);
  }

  return CursorPage(
    items: items,
    lastDocument: null,
    // A row left over, or a source that filled its pageSize + 1 (its rows
    // can all be used when duplicates were passed over; it may hold more).
    hasMore: used < rows.length || snaps.any((s) => s.docs.length > pageSize),
    cursor: MergedCursor(lastShown),
  );
}
