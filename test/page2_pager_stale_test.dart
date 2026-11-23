// PAGE2: the shared pager and a search typed quickly. A fetch that answers
// after a newer session started is dropped (a slow old search never
// overwrites the newer one), and the rows shown when the new session started
// stay available (previousItems) until its first page arrives.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/services/cursor_paginated_list_controller.dart';

void main() {
  CursorPage<String> page(List<String> items) => CursorPage(items: items, lastDocument: null, hasMore: false);

  test('a slow first query does not overwrite a faster second one', () async {
    final answers = <String, Completer<CursorPage<String>>>{};
    var term = '';
    final c = CursorPaginatedListController<String>(
      pageSize: 10,
      fetchPage: ({required snapshotAt, required pageSize, startAfterDocument}) {
        final done = Completer<CursorPage<String>>();
        answers[term] = done;
        return done.future;
      },
    );

    term = 'a';
    final first = c.openSession('a');
    term = 'ab';
    final second = c.openSession('ab');

    answers['ab']!.complete(page(['Abdul']));
    await second;
    expect(c.items, ['Abdul']);
    expect(c.isLoading, isFalse);

    answers['a']!.complete(page(['Amina', 'Abdul']));
    await first;
    expect(c.items, ['Abdul'], reason: 'the stale answer for "a" is dropped');
    expect(c.isLoading, isFalse);
  });

  test('a stale error is dropped too, and does not end the newer loading', () async {
    final answers = <Completer<CursorPage<String>>>[];
    final c = CursorPaginatedListController<String>(
      pageSize: 10,
      fetchPage: ({required snapshotAt, required pageSize, startAfterDocument}) {
        final done = Completer<CursorPage<String>>();
        answers.add(done);
        return done.future;
      },
    );
    final first = c.openSession('a');
    final second = c.openSession('ab');
    answers[0].completeError(StateError('slow and failed'));
    await first;
    expect(c.error, isNull);
    expect(c.isLoading, isTrue, reason: 'the newer fetch is still on its way');
    answers[1].complete(page(['Abdul']));
    await second;
    expect(c.items, ['Abdul']);
  });

  test('the rows shown stay as previousItems while the new session loads; cleared when it answers', () async {
    Completer<CursorPage<String>>? hold;
    var result = ['Amina', 'Baraka'];
    final c = CursorPaginatedListController<String>(
      pageSize: 10,
      fetchPage: ({required snapshotAt, required pageSize, startAfterDocument}) =>
          hold?.future ?? Future.value(page(result)),
    );
    await c.openSession('');
    expect(c.previousItems, isEmpty);

    hold = Completer();
    final next = c.openSession('am');
    expect(c.items, isEmpty, reason: 'items keeps its old meaning (the phone list is unchanged)');
    expect(c.previousItems, ['Amina', 'Baraka']);

    // A third keystroke before the second answers keeps the same rows.
    final third = c.openSession('ami');
    expect(c.previousItems, ['Amina', 'Baraka']);

    result = ['Amina'];
    hold.complete(page(result));
    await next;
    await third;
    expect(c.items, ['Amina']);
    expect(c.previousItems, isEmpty);
  });
}
