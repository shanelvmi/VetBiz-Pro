import 'package:flutter/material.dart';

/// A person's round picture: their photo, or their initials on a circle in
/// the theme's primary colour when there is none (or it fails to load).
/// The one avatar of the top bar, the profile drawer and Edit Profile.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, required this.avatarUrl, required this.name, required this.size});

  final String? avatarUrl;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) => throw UnimplementedError('G2: ProfileAvatar');
}
