import 'package:flutter/material.dart';
import '../theme/theme_context.dart';

/// The page behind the signed-out screens' card (Login and Register): a flat
/// colour from the chosen theme's `background` role, readable in Light and
/// Dark. No image, no scrim and no network read (G1: the platform poster
/// and the bundled photo were removed). One place to restyle both pages.
class AuthBackground extends StatelessWidget {
  const AuthBackground({super.key});

  @override
  Widget build(BuildContext context) => ColoredBox(color: context.colors.background);
}
