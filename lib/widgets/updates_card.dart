import 'package:flutter/material.dart';

/// AN4: the login page's left card around the Updates (stub: draws [child]
/// as it is until the card is built).
class UpdatesCard extends StatelessWidget {
  const UpdatesCard({super.key, required this.wide, required this.child});

  /// For tests: the card itself, its welcome note and the note's heading row.
  static const surfaceKey = ValueKey<String>('updates-card-surface');
  static const welcomeKey = ValueKey<String>('updates-card-welcome');
  static const welcomeHeadingKey = ValueKey<String>('updates-card-welcome-heading');

  /// The login page's two-column layout (AuthCardLayout.isWide).
  final bool wide;

  /// What UpdatesCarousel hands the page: the slides or the skeleton.
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}
