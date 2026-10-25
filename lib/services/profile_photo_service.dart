import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../config/app_limits.dart';
import '../data/collections.dart';
import '../data/upload_content_types.dart';
import '../utils/upload_size_check.dart';

/// Where profile photos are kept: Firebase Storage in the app, a fake in
/// tests. [delete] throws a FirebaseException with code 'object-not-found'
/// when there is no such file.
abstract class PhotoStore {
  /// Stores a jpeg (the photo's one format) and returns its download URL.
  Future<String> upload(String path, Uint8List bytes);
  Future<void> delete(String path);
}

/// [PhotoStore] on Firebase Storage. Sign-up passes the Storage of its
/// temporary Firebase app, so the upload is made as the new account.
class FirebasePhotoStore implements PhotoStore {
  FirebasePhotoStore([this._storage]);

  final FirebaseStorage? _storage;

  Reference _ref(String path) => (_storage ?? FirebaseStorage.instance).ref().child(path);

  @override
  Future<String> upload(String path, Uint8List bytes) async {
    final ref = _ref(path);
    await ref.putData(bytes, UploadContentTypes.jpeg);
    return ref.getDownloadURL();
  }

  @override
  Future<void> delete(String path) => _ref(path).delete();
}

/// The one place a person's profile photo is picked, saved and removed
/// (Edit Profile and sign-up). The dashboard's own camera button and its
/// user_avatars/ upload are gone (G2).
class ProfilePhotoService {
  ProfilePhotoService({PhotoStore? store, FirebaseFirestore? firestore, Future<Uint8List?> Function()? pick})
      : _store = store ?? FirebasePhotoStore(),
        _firestore = firestore,
        _pick = pick;

  final PhotoStore _store;
  final FirebaseFirestore? _firestore;
  final Future<Uint8List?> Function()? _pick;

  DocumentReference<Map<String, dynamic>> _user(String uid) =>
      (_firestore ?? FirebaseFirestore.instance).collection(Collections.users).doc(uid);

  /// The photo's one location.
  static String photoPath(String uid) => 'avatars/$uid.jpg';

  /// Written by the dashboard's old avatar editor; removed with the photo.
  static String legacyPhotoPath(String uid) => 'user_avatars/$uid.png';

  /// Opens the gallery. The photo is scaled down and must pass the upload
  /// size check (P1, E4a-fix); null when cancelled or refused (the check
  /// has already told the person why).
  Future<Uint8List?> pickPhoto() async {
    if (_pick != null) return _pick();
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: AppLimits.avatarImageMaxSide,
      maxHeight: AppLimits.avatarImageMaxSide,
      imageQuality: AppLimits.pickedImageQuality,
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    if (!UploadSizeCheck.allow(bytes)) return null;
    return bytes;
  }

  /// Stores the photo (a jpeg, so storage.rules sees an image) and returns
  /// its download URL. Does not touch the profile: sign-up saves the URL
  /// with the rest of the account.
  Future<String> uploadPhoto(String uid, Uint8List bytes) => _store.upload(photoPath(uid), bytes);

  /// Change photo: stores it and points avatarUrl at it. The top bar and the
  /// drawer follow the profile document, so they update at once.
  Future<String> savePhoto(String uid, Uint8List bytes) async {
    final url = await uploadPhoto(uid, bytes);
    // A new photo at the same path can come back with the same URL, which
    // the image cache would keep showing; the extra parameter is ignored
    // by Storage and makes the URL new.
    final shown = '$url${url.contains('?') ? '&' : '?'}v=${DateTime.now().millisecondsSinceEpoch}';
    await _user(uid).update({'avatarUrl': shown});
    return shown;
  }

  /// Remove photo: deletes both files (a file that is not there counts as
  /// deleted), then clears avatarUrl, so the initials show. Any other
  /// Storage error stops here with avatarUrl kept, so nothing points at a
  /// half-removed photo.
  Future<void> removePhoto(String uid) async {
    for (final path in [photoPath(uid), legacyPhotoPath(uid)]) {
      try {
        await _store.delete(path);
      } on FirebaseException catch (e) {
        if (e.code != 'object-not-found') rethrow;
      }
    }
    await _user(uid).update({'avatarUrl': FieldValue.delete()});
  }
}
