import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_breakpoints.dart';
import '../theme/app_dimens.dart';
import '../theme/theme_context.dart';

/// What the card tells its body: the width the page gives the card (after
/// its margins) and whether the card uses its wide layout.
class AuthCardLayout {
  const AuthCardLayout({required this.availableWidth, required this.isWide});

  final double availableWidth;
  final bool isWide;
}

/// The one card of the signed-out screens (Login and Register): centred on
/// the page, the same maximum width, padding and radius on both (from
/// [AuthCardMetrics]), the full width minus the page margins on phones.
/// The page scrolls when the card is taller than the screen.
class AuthCard extends StatelessWidget {
  const AuthCard({super.key, required this.header, required this.bodyBuilder, this.footer, this.below});

  /// Finds the card itself (not the page around it), for tests.
  static const surfaceKey = ValueKey<String>('auth-card-surface');

  final Widget header;
  final Widget Function(BuildContext context, AuthCardLayout layout) bodyBuilder;
  final Widget? footer;

  /// Under the card, the full width of the page (the sign-in footer, G3).
  /// It sits at the bottom of the screen when everything fits, and after
  /// the card when the page scrolls.
  final Widget? below;

  @override
  Widget build(BuildContext context) {
    final card = Padding(
      padding: const EdgeInsets.all(AuthCardMetrics.pageMargin),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // The actual space available to the card, after the page
          // margins - not the raw screen width, which doesn't account for
          // them and was the real cause of the login's two-column layout
          // overflowing at widths just above the old cutoff.
          final available = constraints.maxWidth;
          final isWide = available > AppBreakpoints.twoPane;
          final target = isWide ? AuthCardMetrics.maxWidthWide : AuthCardMetrics.maxWidthNarrow;
          // The card is forced to be exactly this wide (not just "up to"
          // it) - otherwise its width follows whatever its content
          // demands, which can end up narrower than the target and is why
          // the header's right-aligned items once missed the card edge.
          // Capped by the available space, so it never asks for more.
          final width = math.min(available, target);
          final padding = isWide ? AuthCardMetrics.paddingWide : AuthCardMetrics.paddingNarrow;

          return Container(
            key: surfaceKey,
            width: width,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(AuthCardMetrics.radius),
              boxShadow: [
                BoxShadow(
                  color: context.colors.shadow.withValues(alpha: AuthCardMetrics.shadowAlpha),
                  blurRadius: AuthCardMetrics.shadowBlur,
                  offset: const Offset(0, AuthCardMetrics.shadowOffsetY),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header,
                Padding(
                  padding: EdgeInsets.all(padding),
                  child: bodyBuilder(context, AuthCardLayout(availableWidth: available, isWide: isWide)),
                ),
                if (footer != null) footer!,
              ],
            ),
          );
        },
      ),
    );
    if (below == null) return Center(child: SingleChildScrollView(child: card));
    return LayoutBuilder(
      builder: (context, viewport) => SingleChildScrollView(
        child: ConstrainedBox(
          // At least the screen's height, so the card stays centred in the
          // space above the footer and the footer reaches the bottom.
          constraints: BoxConstraints(minHeight: viewport.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [const SizedBox.shrink(), card, below!],
          ),
        ),
      ),
    );
  }
}
