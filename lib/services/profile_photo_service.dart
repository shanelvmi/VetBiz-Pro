import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Where profile photos are kept: Firebase Storage in the app, a fake in
/// tests. [delete] throws a FirebaseException with code 'object-not-found'
/// when there is no such file.
abstract class PhotoStore {
  Future<String> upload(String path, Uint8List bytes, SettableMetadata metadata);
  Future<void> delete(String path);
}

/// The one place a person's profile photo is picked, saved and removed
/// (Edit Profile and sign-up).
class ProfilePhotoService {
  ProfilePhotoService({PhotoStore? store, FirebaseFirestore? firestore, Future<Uint8List?> Function()? pick});

  /// The photo's one location.
  static String photoPath(String uid) => 'avatars/$uid.jpg';

  /// Written by the dashboard's old avatar editor; removed with the photo.
  static String legacyPhotoPath(String uid) => 'user_avatars/$uid.png';

  Future<Uint8List?> pickPhoto() => throw UnimplementedError('G2: pickPhoto');
  Future<String> uploadPhoto(String uid, Uint8List bytes) => throw UnimplementedError('G2: uploadPhoto');
  Future<String> savePhoto(String uid, Uint8List bytes) => throw UnimplementedError('G2: savePhoto');
  Future<void> removePhoto(String uid) => throw UnimplementedError('G2: removePhoto');
}
