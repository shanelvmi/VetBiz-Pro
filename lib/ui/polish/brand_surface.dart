import 'package:flutter/material.dart';

import '../../theme/polish_metrics.dart';
import '../../theme/theme_context.dart';

/// POL3, the owner's rule for a hero or brand surface (decided for the
/// Today card, POL2b): ONE SOLID deep tone of the theme, brandGradientEnd,
/// never a gradient, with the on-brand inks on it (onBrandSurface and
/// onBrandSurfaceMuted reach 4.5:1 or more in every theme, Light and Dark).
/// The sign-in and register header bars, the register welcome panel and
/// strip, and the Promotions "% OFF" badge use it.
class BrandSurface {
  BrandSurface._();

  /// The one fill.
  static Color fill(BuildContext context) => context.colors.brandGradientEnd;

  /// In Dark the deep tone nearly meets the card or page around it (1.03:1
  /// in Ledger), so a hairline in the border role marks its edge, as on the
  /// Today card; none in Light, where the tone stands out by itself. For a
  /// Container's foregroundDecoration, so the hairline insets nothing. With
  /// [bottomOnly] (a header bar at the top of its card) only the lower edge.
  static BoxDecoration? darkEdge(BuildContext context, {BorderRadius? radius, bool bottomOnly = false}) {
    if (Theme.of(context).brightness != Brightness.dark) return null;
    final side = BorderSide(color: context.colors.border, width: PolishMetrics.hairline);
    return BoxDecoration(
      borderRadius: radius,
      border: bottomOnly ? Border(bottom: side) : Border.fromBorderSide(side),
    );
  }
}
