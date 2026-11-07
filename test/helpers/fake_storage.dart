// ignore_for_file: subtype_of_sealed_class
// PH8a: a Firebase Storage fake for the seams (storage:): it keeps what was
// uploaded (path, bytes, content type) and answers a download URL from the
// path. Only what the screens call is implemented.
import 'dart:async';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeUpload {
  final String path;
  final int bytes;
  final String? contentType;
  const FakeUpload(this.path, this.bytes, this.contentType);

  Map<String, Object?> toJson() => {'path': path, 'bytes': bytes, 'contentType': contentType};
}

class FakeStorage extends Fake implements FirebaseStorage {
  final uploads = <FakeUpload>[];
  // PH8b-2: the paths deleted, in order.
  final deletes = <String>[];

  @override
  Reference ref([String? path]) => _FakeRef(this, path ?? '');
}

class _FakeRef extends Fake implements Reference {
  final FakeStorage owner;
  final String path;
  _FakeRef(this.owner, this.path);

  @override
  String get fullPath => path;

  @override
  Reference child(String path) => _FakeRef(owner, this.path.isEmpty ? path : '${this.path}/$path');

  @override
  UploadTask putData(Uint8List data, [SettableMetadata? metadata]) {
    owner.uploads.add(FakeUpload(path, data.length, metadata?.contentType));
    return _FakeTask();
  }

  @override
  Future<String> getDownloadURL() async => 'https://storage.test/o/${Uri.encodeComponent(path)}?alt=media&token=t';

  @override
  Future<void> delete() async => owner.deletes.add(path);
}

class _FakeSnapshot extends Fake implements TaskSnapshot {}

class _FakeTask extends Fake implements UploadTask {
  final Future<TaskSnapshot> _done = Future.value(_FakeSnapshot());

  @override
  Future<R> then<R>(FutureOr<R> Function(TaskSnapshot) onValue, {Function? onError}) =>
      _done.then(onValue, onError: onError);

  @override
  Future<TaskSnapshot> catchError(Function onError, {bool Function(Object error)? test}) =>
      _done.catchError(onError, test: test);

  @override
  Future<TaskSnapshot> whenComplete(FutureOr<void> Function() action) => _done.whenComplete(action);

  @override
  Future<TaskSnapshot> timeout(Duration timeLimit, {FutureOr<TaskSnapshot> Function()? onTimeout}) =>
      _done.timeout(timeLimit, onTimeout: onTimeout);

  @override
  Stream<TaskSnapshot> asStream() => _done.asStream();
}
