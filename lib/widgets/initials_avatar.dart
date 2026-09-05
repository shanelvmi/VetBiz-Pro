import 'package:flutter/material.dart';

/// A circular avatar showing the uploaded photo when one exists,
/// falling back to the person's initials (e.g. "SH" for "Shanel
/// Hassan") rather than a generic person icon when it doesn't -
/// identifies whose card/row this is at a glance, the way most modern
/// team-management tools handle a missing photo. Also covers a broken
/// or expired photo URL, since the same initials fallback renders if
/// the image fails to load, not just when there's no URL at all.
class InitialsAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String name;
  final double size;
  final Color backgroundColor;
  final Color foregroundColor;

  const InitialsAvatar({
    super.key,
    required this.avatarUrl,
    required this.name,
    required this.size,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  static String initialsFor(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  Widget _fallback() {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      color: backgroundColor,
      child: Text(
        initialsFor(name),
        style: TextStyle(
          color: foregroundColor,
          fontWeight: FontWeight.bold,
          fontSize: size * 0.38,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = avatarUrl != null && avatarUrl!.isNotEmpty;
    return ClipOval(
      child: hasPhoto
          ? Image.network(
              avatarUrl!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => _fallback(),
            )
          : _fallback(),
    );
  }
}
