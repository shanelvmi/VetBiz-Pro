import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../config/app_limits.dart';
import '../utils/app_clock.dart';

/// One page's worth of results from a single Firestore fetch, plus the
/// cursor needed to fetch whatever comes after it. Kept separate from
/// the controller's own state so a single fetch call has one honest
/// return shape, rather than mutating fields as a side effect.
class CursorPage<T> {
  final List<T> items;
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;
  // True only when a full pageSize batch came back - a partial batch
  // means this was the last page, even if lastDocument is non-null.
  final bool hasMore;

  // PAGE1: where the next page starts when a page is not one query's
  // documents (a merged list keeps one cursor per source, MergedCursor);
  // null for the ordinary one-query pages, which use lastDocument.
  final Object? cursor;

  const CursorPage({required this.items, required this.lastDocument, required this.hasMore, this.cursor});

  /// PAGE1: one page from a query run with limit(pageSize + 1): the extra
  /// document only says a next page exists (no empty fetch at the end, no
  /// count query), and is not shown or used as the cursor.
  static CursorPage<T> fromDocs<T>(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    int pageSize,
    T Function(QueryDocumentSnapshot<Map<String, dynamic>> doc) map,
  ) {
    final kept = docs.length > pageSize ? docs.sublist(0, pageSize) : docs;
    return CursorPage(
      items: kept.map(map).toList(),
      lastDocument: kept.isEmpty ? null : kept.last,
      hasMore: docs.length > pageSize,
    );
  }
}

/// Reusable pagination for any Firestore-backed list that keeps growing
/// forever (sales, services, clients, expenses, payments, debt
/// repayments, ...) - built specifically to avoid the two failure modes
/// a naive "just paginate it" implementation runs into on a live,
/// continuously-written collection:
///
/// 1. A record silently appearing, disappearing, or shifting to a
///    different page while someone is in the middle of browsing it,
///    because the list kept updating live underneath them.
/// 2. A search or filter finding nothing for a term that genuinely
///    exists, because it only ever looked at whatever page(s) had
///    already been fetched into memory - not a real query against the
///    whole collection.
///
/// Both are solved the same way: every fetch this controller makes -
/// first page, next page, going back to a page already visited - is a
/// one-time read, never a live listener, and every fetch is bounded by
/// a fixed snapshot moment established when the browsing session
/// started (openSession/refreshSession), so nothing written after that
/// moment can enter the session until the person explicitly refreshes.
/// Search is expected to be a real, indexed Firestore query the caller
/// builds into fetchPage - not a client-side filter over whatever this
/// controller happens to already hold.
///
/// Does not attempt real "jump to page 1249" navigation - Firestore has
/// no offset operation, only cursors, so page N can only be reached by
/// walking forward from page 1 (or backward from wherever you already
/// are). Once a page has been visited this session, it's cached, so
/// revisiting it (Previous, or Next back to where you were) is free -
/// only advancing past the furthest point reached so far triggers a
/// real fetch.
class CursorPaginatedListController<T> extends ChangeNotifier {
  CursorPaginatedListController({
    required this.fetchPage,
    this.countCreatedAfter,
    int pageSize = AppLimits.pageSize,
  })  : fetchPageAfter = null,
        _pageSize = pageSize;

  /// PAGE1: pages whose cursor is not one document (a merged list,
  /// fetchMergedPage): each fetch gets the previous page's [CursorPage.cursor].
  CursorPaginatedListController.after({
    required Future<CursorPage<T>> Function({required DateTime snapshotAt, required int pageSize, Object? after})
        this.fetchPageAfter,
    this.countCreatedAfter,
    int pageSize = AppLimits.pageSize,
  })  : fetchPage = null,
        _pageSize = pageSize;

  /// Runs one Firestore query for a page: applies the caller's own
  /// filter/search/sort conditions, the given snapshotAt boundary
  /// (never return anything created after this moment), starts after
  /// startAfterDocument when given one (null means the very first
  /// page), and limits to pageSize. The caller owns the actual
  /// query shape - this controller only orchestrates when to call it
  /// and what to do with what comes back.
  final Future<CursorPage<T>> Function({
    required DateTime snapshotAt,
    required int pageSize,
    DocumentSnapshot<Map<String, dynamic>>? startAfterDocument,
  })? fetchPage;

  final Future<CursorPage<T>> Function({required DateTime snapshotAt, required int pageSize, Object? after})?
      fetchPageAfter;

  /// Optional - a cheap, count()-only query (no documents downloaded)
  /// for how many matching records were created after the given
  /// moment. Powers the "N new records available - Refresh" banner
  /// without ever live-updating the list itself. If the caller doesn't
  /// provide this, newRecordsAvailable simply stays 0 and the banner
  /// never shows - a missing "what's new" count is never a reason to
  /// fall back to a live listener.
  final Future<int> Function({required DateTime after})? countCreatedAfter;

  int _pageSize;
  int get pageSize => _pageSize;

  // Identifies the current filter/search/sort combination. Passed in
  // by the caller on every open/reset call; compared by ==, so callers
  // should pass a value type (a record, or a class with proper ==) -
  // not a fresh object each time, or every call would look like a
  // change. Changing this always means "start over completely" - a
  // cursor from one query is never valid against a different one.
  Object? _querySignature;

  DateTime? _snapshotAt;
  DateTime? get snapshotAt => _snapshotAt;

  // Every page fetched so far this session, in order - index 0 is
  // page 1. Revisiting a cached page (Previous, or Next back to
  // somewhere already reached) costs nothing further.
  final List<CursorPage<T>> _pages = [];
  int _currentPageIndex = -1; // -1 = no session open yet

  // PAGE2: which session a fetch belongs to. A new session (a new search
  // text, a filter, the page size) moves it on; a fetch that answers after
  // that is from an older session and is dropped, so a slow old search can
  // never overwrite the results for newer text.
  int _session = 0;

  // PAGE2: the page shown when the current session started, kept until the
  // new session's first page arrives (or fails), so a PC/tablet list can show
  // it dimmed instead of flashing to a skeleton for every search keystroke.
  // [items] stays empty meanwhile, as before (the phone list is unchanged).
  List<T> _previousItems = const [];
  List<T> get previousItems => _previousItems;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  int _newRecordsAvailable = 0;
  int get newRecordsAvailable => _newRecordsAvailable;

  List<T> get items => _currentPageIndex >= 0 && _currentPageIndex < _pages.length
      ? _pages[_currentPageIndex].items
      : const [];

  /// PH5a: every page up to the current one, in order. A phone list shows
  /// them one after another and asks for the next with [goToNextPage]; the
  /// pages, the cursors and the snapshot moment are the same as above.
  List<T> get loadedItems => [
        for (var i = 0; i <= _currentPageIndex && i < _pages.length; i++) ..._pages[i].items,
      ];

  // 1-based for display ("Page 3 of ..."), matching how every other
  // page indicator in this app already counts.
  int get currentPage => _currentPageIndex + 1;

  bool get hasPreviousPage => _currentPageIndex > 0;

  bool get hasNextPage {
    if (_currentPageIndex < 0 || _currentPageIndex >= _pages.length) return false;
    // Already-fetched next page cached, or the current page came back
    // full (there may be more to fetch).
    return _currentPageIndex + 1 < _pages.length || _pages[_currentPageIndex].hasMore;
  }

  bool get hasOpenSession => _currentPageIndex >= 0;

  /// Starts a new browsing session, or does nothing if one is already
  /// open for this exact querySignature - safe to call from build()
  /// on every rebuild the way a screen's own didChangeDependencies
  /// often does, without accidentally restarting the session on every
  /// frame. Pass forceRefresh: true (from an explicit Refresh action)
  /// to start over deliberately even when the signature hasn't
  /// changed - that's the only other way a session resets, alongside
  /// the signature itself changing.
  Future<void> openSession(Object querySignature, {bool forceRefresh = false}) async {
    final signatureChanged = _querySignature != querySignature;
    if (!forceRefresh && !signatureChanged && hasOpenSession) return;

    _querySignature = querySignature;
    _snapshotAt = AppClock.now();
    _session++;
    if (items.isNotEmpty) _previousItems = items;
    _pages.clear();
    _currentPageIndex = -1;
    _newRecordsAvailable = 0;
    _error = null;
    await _fetchAndAppendPage(previous: null);
  }

  /// Explicit "start over from now" - what the "N new records
  /// available - Refresh" banner's button calls. Distinct from
  /// openSession's own signature-change detection since this always
  /// restarts, deliberately, even though nothing about the filters
  /// changed - only the snapshot boundary moves forward.
  Future<void> refreshSession() async {
    if (_querySignature == null) return;
    await openSession(_querySignature!, forceRefresh: true);
  }

  /// Changes how many items each page holds. Per the same reasoning as
  /// a query signature change - a page fetched at one size can't be
  /// reinterpreted at another - this always restarts the session
  /// rather than trying to reslice what's already cached.
  Future<void> setPageSize(int newSize) async {
    if (newSize == _pageSize) return;
    _pageSize = newSize;
    if (_querySignature != null) {
      await openSession(_querySignature!, forceRefresh: true);
    }
  }

  Future<void> goToNextPage() async {
    if (!hasNextPage || _isLoading) return;
    if (_currentPageIndex + 1 < _pages.length) {
      // Already fetched earlier this session - free.
      _currentPageIndex++;
      notifyListeners();
      return;
    }
    await _fetchAndAppendPage(previous: _pages[_currentPageIndex]);
  }

  /// Free - never re-fetches, since every page reached this session
  /// stays cached until the session itself resets.
  void goToPreviousPage() {
    if (!hasPreviousPage) return;
    _currentPageIndex--;
    notifyListeners();
  }

  /// PAGE1: after an error, the fetch that failed again: the first page
  /// when none came back, else the next one (Previous never fetches).
  Future<void> retry() async {
    if (_pages.isEmpty) {
      await refreshSession();
    } else {
      await goToNextPage();
    }
  }

  Future<void> _fetchAndAppendPage({required CursorPage<T>? previous}) async {
    final snapshotAt = _snapshotAt;
    if (snapshotAt == null) return;

    final session = _session;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final after = fetchPageAfter;
      final page = after != null
          ? await after(snapshotAt: snapshotAt, pageSize: _pageSize, after: previous?.cursor)
          : await fetchPage!(snapshotAt: snapshotAt, pageSize: _pageSize, startAfterDocument: previous?.lastDocument);
      // PAGE2: a newer session started while this one was waiting: its
      // answer is stale (the newer fetch owns the loading state too).
      if (session != _session) return;
      _pages.add(page);
      _currentPageIndex = _pages.length - 1;
      _previousItems = const [];
    } catch (e) {
      if (session != _session) return;
      _error = 'Could not load this page: $e';
      _previousItems = const [];
    } finally {
      if (session == _session) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Checks (once - not a live subscription) how many matching records
  /// have been created since this session's snapshot moment. Intended
  /// to be called from things like a screen refocus or a periodic
  /// timer the screen itself owns, not from inside this controller -
  /// keeping "when to check" a UI-layer decision.
  Future<void> checkForNewRecords() async {
    final check = countCreatedAfter;
    final snapshotAt = _snapshotAt;
    if (check == null || snapshotAt == null) return;
    try {
      _newRecordsAvailable = await check(after: snapshotAt);
      notifyListeners();
    } catch (e) {
      debugPrint('Error checking for new records: $e');
    }
  }

  void disposeSession() {
    // PAGE2: a fetch still on its way belongs to the session that ends here.
    _session++;
    _isLoading = false;
    _previousItems = const [];
    _pages.clear();
    _currentPageIndex = -1;
    _querySignature = null;
    _snapshotAt = null;
    _newRecordsAvailable = 0;
  }
}
