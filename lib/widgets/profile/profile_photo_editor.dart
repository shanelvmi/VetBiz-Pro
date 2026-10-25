import 'dart:typed_data';

import 'package:flutter/material.dart';

/// The photo part of Edit Profile and sign-up: the avatar (or the photo just
/// picked), Change photo, and Remove photo when there is one.
class ProfilePhotoEditor extends StatelessWidget {
  const ProfilePhotoEditor({
    super.key,
    required this.avatarUrl,
    required this.previewBytes,
    required this.name,
    required this.onChange,
    required this.onRemove,
    this.busy = false,
  });

  final String? avatarUrl;
  final Uint8List? previewBytes;
  final String name;
  final VoidCallback onChange;
  final VoidCallback onRemove;

  /// A save or remove is running: both buttons wait.
  final bool busy;

  @override
  Widget build(BuildContext context) => throw UnimplementedError('G2: ProfilePhotoEditor');
}
