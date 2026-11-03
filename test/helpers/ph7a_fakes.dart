// ignore_for_file: subtype_of_sealed_class
// PH7a: stand-ins for Add/Edit Product's seams (Storage and the image
// picker), so the form's photo path can be driven in a test: the picker
// hands back fixed bytes, and Storage records what was put where.
import 'dart:async';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

/// One upload: the path, the bytes and the content type.
class FakeUpload {
  final String path;
  final int bytes;
  final String? contentType;

  const FakeUpload(this.path, this.bytes, this.contentType);
}

class FakeStorage implements FirebaseStorage {
  final List<FakeUpload> uploads = [];

  @override
  Reference ref([String? path]) => FakeReference(this, path ?? '');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeReference implements Reference {
  @override
  final FakeStorage storage;
  @override
  final String fullPath;

  FakeReference(this.storage, this.fullPath);

  @override
  Reference child(String path) => FakeReference(storage, fullPath.isEmpty ? path : '$fullPath/$path');

  @override
  UploadTask putData(Uint8List data, [SettableMetadata? metadata]) {
    storage.uploads.add(FakeUpload(fullPath, data.lengthInBytes, metadata?.contentType));
    return FakeUploadTask();
  }

  @override
  Future<String> getDownloadURL() async => 'https://storage.test/$fullPath';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Snapshot implements TaskSnapshot {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A finished upload: awaiting it gives a snapshot at once.
class FakeUploadTask implements UploadTask {
  final Future<TaskSnapshot> _done = Future.value(_Snapshot());

  @override
  Future<R> then<R>(FutureOr<R> Function(TaskSnapshot value) onValue, {Function? onError}) =>
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

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Picks [bytes] (a small JPEG-sized blob by default) every time.
class FakeImagePicker extends ImagePicker {
  final Uint8List bytes;
  int picks = 0;

  FakeImagePicker([Uint8List? bytes]) : bytes = bytes ?? Uint8List(2048);

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    picks++;
    return XFile.fromData(bytes, name: 'photo.jpg', mimeType: 'image/jpeg');
  }
}
