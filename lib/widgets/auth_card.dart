import 'package:flutter/material.dart';

/// What the card tells its body: the width the page gives the card (after
/// its margins) and whether the card uses its wide layout.
class AuthCardLayout {
  const AuthCardLayout({required this.availableWidth, required this.isWide});

  final double availableWidth;
  final bool isWide;
}

/// The one card of the signed-out screens (Login and Register): centred on
/// the page, the same maximum width, padding and radius on both.
class AuthCard extends StatelessWidget {
  const AuthCard({super.key, required this.header, required this.bodyBuilder, this.footer});

  /// Finds the card itself (not the page around it), for tests.
  static const surfaceKey = ValueKey<String>('auth-card-surface');

  final Widget header;
  final Widget Function(BuildContext context, AuthCardLayout layout) bodyBuilder;
  final Widget? footer;

  @override
  Widget build(BuildContext context) => throw UnimplementedError('G1: AuthCard');
}
