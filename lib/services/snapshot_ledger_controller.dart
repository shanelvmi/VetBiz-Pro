import 'package:flutter/foundation.dart';

/// Reusable state for a screen that shows a merged view built from more
/// than one Firestore collection - Payments being the first case (the
/// `payments` collection plus `transactions` where type is "other
/// income"). Deliberately separate from CursorPaginatedListController,
/// not a variant of it: Firestore cursors are specific to a single
/// collection's query, so a merged, two-source ledger can't be paged
/// with an ordinary cursor at all without hand-rolling a merge across
/// two independent cursors - real complexity for a screen most people
/// browse by date range, not by "page 47." Bounding by date range
/// instead sidesteps that problem entirely, since a ledger naturally
/// stays a manageable size once it's scoped to a month or a year,
/// unlike a flat, ever-growing transaction list with no such
/// boundary.
///
/// What this shares with CursorPaginatedListController is the same
/// core discipline: a fixed snapshot moment established when the
/// session opens, so a record created after that moment doesn't
/// silently enter the current view and shift what's already on
/// screen - surfaced instead as a passive "N new entries - Refresh"
/// count, never a live listener rewriting the ledger underneath
/// whoever's reviewing it. That matters even more here than for a
/// plain list, since this is reconciliation-grade financial data,
/// not a browsable catalog.
class SnapshotLedgerController<T> extends ChangeNotifier {
  SnapshotLedgerController({required this.fetchLedger, this.countNewEntries});

  /// Runs both underlying queries, converts each source's results into
  /// T, merges them, and returns one deterministically-sorted list -
  /// all of that is the caller's own responsibility (PaymentProvider,
  /// for the Payments screen), not this controller's. This controller
  /// only orchestrates when to call it and holds onto what comes back.
  final Future<List<T>> Function({
    required DateTime rangeStart,
    required DateTime rangeEnd,
    required DateTime snapshotAt,
  }) fetchLedger;

  /// Optional - a cheap, count()-only check across both sources for
  /// how many entries were created after the given moment, within the
  /// same date range. Powers the "N new entries available - Refresh"
  /// banner without a live listener. If the caller doesn't provide
  /// this, newEntriesAvailable simply stays 0 and the banner never
  /// shows.
  final Future<int> Function({
    required DateTime after,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  })? countNewEntries;

  // Identifies the current date range + search/filter combination.
  // Passed in by the caller on every open/reset call; compared by ==,
  // so callers should pass a value type - not a fresh object each
  // time, or every call would look like a change. Changing this always
  // means "start over completely."
  Object? _querySignature;
  DateTime? _rangeStart;
  DateTime? _rangeEnd;

  DateTime? _snapshotAt;
  DateTime? get snapshotAt => _snapshotAt;

  List<T> _entries = [];
  List<T> get entries => _entries;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  int _newEntriesAvailable = 0;
  int get newEntriesAvailable => _newEntriesAvailable;

  bool get hasOpenSession => _snapshotAt != null;

  /// Starts a new ledger session for this date range + query
  /// signature, or does nothing if one matching both is already open -
  /// safe to call from build() on every rebuild without accidentally
  /// restarting the session on every frame. Pass forceRefresh: true
  /// (from an explicit Refresh action, or a date range picked again
  /// unchanged) to start over deliberately.
  Future<void> openSession({
    required Object querySignature,
    required DateTime rangeStart,
    required DateTime rangeEnd,
    bool forceRefresh = false,
  }) async {
    final changed = _querySignature != querySignature || _rangeStart != rangeStart || _rangeEnd != rangeEnd;
    if (!forceRefresh && !changed && hasOpenSession) return;

    _querySignature = querySignature;
    _rangeStart = rangeStart;
    _rangeEnd = rangeEnd;
    _snapshotAt = DateTime.now();
    _newEntriesAvailable = 0;
    _error = null;
    await _load();
  }

  /// Explicit "start over from now" - what the "N new entries
  /// available - Refresh" banner's button calls. Keeps the same date
  /// range and query signature, only the snapshot boundary moves
  /// forward.
  Future<void> refreshSession() async {
    final signature = _querySignature;
    final rangeStart = _rangeStart;
    final rangeEnd = _rangeEnd;
    if (signature == null || rangeStart == null || rangeEnd == null) return;
    await openSession(querySignature: signature, rangeStart: rangeStart, rangeEnd: rangeEnd, forceRefresh: true);
  }

  Future<void> _load() async {
    final rangeStart = _rangeStart;
    final rangeEnd = _rangeEnd;
    final snapshotAt = _snapshotAt;
    if (rangeStart == null || rangeEnd == null || snapshotAt == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _entries = await fetchLedger(rangeStart: rangeStart, rangeEnd: rangeEnd, snapshotAt: snapshotAt);
    } catch (e) {
      _error = 'Could not load this ledger: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Checks (once - not a live subscription) how many entries have
  /// been created since this session's snapshot moment, within the
  /// same date range. Intended to be called from something the screen
  /// itself owns (a periodic timer, a refocus check), not from inside
  /// this controller - keeping "when to check" a UI-layer decision.
  Future<void> checkForNewEntries() async {
    final check = countNewEntries;
    final rangeStart = _rangeStart;
    final rangeEnd = _rangeEnd;
    final snapshotAt = _snapshotAt;
    if (check == null || rangeStart == null || rangeEnd == null || snapshotAt == null) return;
    try {
      _newEntriesAvailable = await check(after: snapshotAt, rangeStart: rangeStart, rangeEnd: rangeEnd);
      notifyListeners();
    } catch (e) {
      debugPrint('Error checking for new ledger entries: $e');
    }
  }

  void disposeSession() {
    _entries = [];
    _querySignature = null;
    _rangeStart = null;
    _rangeEnd = null;
    _snapshotAt = null;
    _newEntriesAvailable = 0;
  }
}
