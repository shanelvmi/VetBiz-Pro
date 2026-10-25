import 'package:flutter/material.dart';

/// The person's button in the top bar; a tap opens the profile drawer.
/// Below AppBreakpoints.compact: the avatar only, in its highlighted
/// circle. Wider: the avatar, the name and the role in a plain row with a
/// small chevron, at least 48 px high.
class ProfileMenuButton extends StatelessWidget {
  const ProfileMenuButton({super.key, required this.avatarUrl, required this.name, required this.roleLabel, required this.onTap});

  final String? avatarUrl;
  final String name;
  final String roleLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => throw UnimplementedError('G2: ProfileMenuButton');
}
