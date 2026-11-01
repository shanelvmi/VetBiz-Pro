// ignore_for_file: subtype_of_sealed_class
// PH4: the fake Firestore with counters, to measure what a screen costs.
// Every get() and snapshots() through it is counted: [listeners] is how many
// live listeners are open now, [reads] the documents billed (each document a
// get returns, every document of a listener's first answer, then each
// changed document).
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

class CountingFirestore implements FirebaseFirestore {
  CountingFirestore([FakeFirebaseFirestore? inner]) : inner = inner ?? FakeFirebaseFirestore();

  final FakeFirebaseFirestore inner;
  int listeners = 0;
  int reads = 0;
  int gets = 0;
  int listens = 0;

  void resetCounts() {
    reads = 0;
    gets = 0;
    listens = 0;
  }

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) => _Collection(this, inner.collection(path));

  @override
  DocumentReference<Map<String, dynamic>> doc(String path) => _Doc(this, inner.doc(path));

  Future<QuerySnapshot<Map<String, dynamic>>> _get(Query<Map<String, dynamic>> q) async {
    gets++;
    final snap = await q.get();
    reads += snap.docs.length;
    return snap;
  }

  Stream<S> _listen<S>(Stream<S> Function() open, int Function(S snap, bool first) billed) {
    late StreamSubscription<S> sub;
    late StreamController<S> controller;
    var first = true;
    controller = StreamController<S>(
      onListen: () {
        listens++;
        listeners++;
        sub = open().listen((s) {
          reads += billed(s, first);
          first = false;
          controller.add(s);
        }, onError: controller.addError);
      },
      onCancel: () async {
        listeners--;
        await sub.cancel();
      },
    );
    return controller.stream;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Query implements Query<Map<String, dynamic>> {
  _Query(this.db, this.q);

  final CountingFirestore db;
  final Query<Map<String, dynamic>> q;

  @override
  Query<Map<String, dynamic>> where(Object field,
          {Object? isEqualTo,
          Object? isNotEqualTo,
          Object? isLessThan,
          Object? isLessThanOrEqualTo,
          Object? isGreaterThan,
          Object? isGreaterThanOrEqualTo,
          Object? arrayContains,
          Iterable<Object?>? arrayContainsAny,
          Iterable<Object?>? whereIn,
          Iterable<Object?>? whereNotIn,
          bool? isNull}) =>
      _Query(
          db,
          q.where(field,
              isEqualTo: isEqualTo,
              isNotEqualTo: isNotEqualTo,
              isLessThan: isLessThan,
              isLessThanOrEqualTo: isLessThanOrEqualTo,
              isGreaterThan: isGreaterThan,
              isGreaterThanOrEqualTo: isGreaterThanOrEqualTo,
              arrayContains: arrayContains,
              arrayContainsAny: arrayContainsAny,
              whereIn: whereIn,
              whereNotIn: whereNotIn,
              isNull: isNull));

  @override
  Query<Map<String, dynamic>> orderBy(Object field, {bool descending = false}) =>
      _Query(db, q.orderBy(field, descending: descending));

  @override
  Query<Map<String, dynamic>> limit(int limit) => _Query(db, q.limit(limit));

  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([GetOptions? options]) => db._get(q);

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> snapshots(
          {bool includeMetadataChanges = false, ListenSource source = ListenSource.defaultSource}) =>
      db._listen(() => q.snapshots(), (s, first) => first ? s.docs.length : s.docChanges.length);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Collection extends _Query implements CollectionReference<Map<String, dynamic>> {
  _Collection(CountingFirestore db, this.c) : super(db, c);

  final CollectionReference<Map<String, dynamic>> c;

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) => _Doc(db, c.doc(path));

  @override
  Future<DocumentReference<Map<String, dynamic>>> add(Map<String, dynamic> data) => c.add(data);

  @override
  String get id => c.id;

  @override
  String get path => c.path;
}

class _Doc implements DocumentReference<Map<String, dynamic>> {
  _Doc(this.db, this.d);

  final CountingFirestore db;
  final DocumentReference<Map<String, dynamic>> d;

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) => _Collection(db, d.collection(path));

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    db.gets++;
    final snap = await d.get();
    db.reads++;
    return snap;
  }

  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> snapshots(
          {bool includeMetadataChanges = false, ListenSource source = ListenSource.defaultSource}) =>
      db._listen(() => d.snapshots(), (_, __) => 1);

  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) => d.set(data, options);

  @override
  String get id => d.id;

  @override
  String get path => d.path;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
