import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../config/app_assets.dart';
import '../theme/app_dimens.dart';
import '../theme/app_motion.dart';
import '../theme/app_palette.dart';
import '../theme/app_theme.dart';
import '../theme/app_text.dart';
import '../theme/theme_context.dart';

/// UI1: the one brand loading look. It replaced two weights (a full one with
/// an illustration that was never in the assets, and a compact 40 px logo
/// over a 26 px spinner that the owner found far too small after signing in):
/// the brand mark ([AppAssets.logo]) at 96 px, 88 on a screen under 360 high,
/// inside a soft ring spinner, with the caption under it when there is one.
/// Centred at every size, and scaled down rather than overflowing when the
/// room is short (a phone held sideways). Reduced motion: a still ring.
class VetBizLoadingIndicator extends StatefulWidget {
  final String? title;
  final String? subtitle;
  // Slot for a caller-provided "stuck" recovery action (e.g. a "Try
  // Again" button after a timeout) - deliberately not built into this
  // widget itself, since the timing/logic for when something counts as
  // "stuck" is specific to whatever's actually being waited for, not a
  // generic concern of the loading indicator itself.
  final Widget? recoveryAction;

  const VetBizLoadingIndicator({
    super.key,
    this.title,
    this.subtitle,
    this.recoveryAction,
  });

  // The page colour for a Scaffold placed around this indicator
  // (main.dart). The indicator itself reads the brand roles from the theme.
  static const Color backgroundColor = AppPalette.background;

  /// UI1: the brand mark and the ring around it.
  static const markKey = ValueKey<String>('vetbiz-loading-mark');
  static const ringKey = ValueKey<String>('vetbiz-loading-ring');

  @override
  State<VetBizLoadingIndicator> createState() => _VetBizLoadingIndicatorState();
}

/// Keeps the startup loading screen (main.dart) Pasture light in every mode
/// (T1; dark_mode.md section 4): it shows before the saved settings are read,
/// on the light [VetBizLoadingIndicator.backgroundColor] page, so the roles
/// read under it must be the light ones even when the app theme is dark.
class VetBizLoadingTheme extends StatelessWidget {
  final WidgetBuilder builder;

  const VetBizLoadingTheme({super.key, required this.builder});

  static final ThemeData data = AppTheme.build(AppColorTheme.pasture, Brightness.light);

  @override
  Widget build(BuildContext context) => Theme(data: data, child: Builder(builder: builder));
}

/// UI1: a page that is only the brand loading look, on the theme's background
/// (Dark mode shows a dark page). Every wait after signing in uses it; only
/// the startup screen (main.dart) keeps its light page.
class VetBizLoadingPage extends StatelessWidget {
  final String? title;

  const VetBizLoadingPage({super.key, this.title});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: context.colors.background,
        body: SafeArea(child: VetBizLoadingIndicator(title: title)),
      );
}

class _VetBizLoadingIndicatorState extends State<VetBizLoadingIndicator> with TickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final Animation<double> _markOpacity;
  late final Animation<double> _textOpacity;

  // A slow, gentle opacity pulse on the subtitle only - a tasteful way
  // to suggest "still working" without an aggressive or distracting
  // animation, matching the "subtle" requirement rather than anything
  // flashy.
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      vsync: this,
      duration: AppMotion.emphasis,
    );

    // Staggered within the same controller via Interval, rather than
    // several separate controllers - the mark first, the caption last,
    // each easing in softly.
    _markOpacity = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    );
    _textOpacity = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
    );

    _entranceController.forward();

    _pulseController = AnimationController(
      vsync: this,
      duration: AppMotion.float,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduced motion: everything in place at once, nothing pulsing.
    if (MediaQuery.disableAnimationsOf(context)) {
      _entranceController.value = 1;
      _pulseController
        ..stop()
        ..value = 1;
    } else if (!_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    final mark = MediaQuery.sizeOf(context).height < LoadingMetrics.shortScreen ? LoadingMetrics.markShort : LoadingMetrics.mark;
    final ring = mark + 2 * LoadingMetrics.ringGap;
    final title = widget.title;
    final subtitle = widget.subtitle;

    return LayoutBuilder(
      builder: (context, constraints) {
        // As wide as the room (a dialog's width at most), so a caption wraps
        // instead of shrinking; only a page too short scales the whole down.
        final width = constraints.hasBoundedWidth ? math.min(constraints.maxWidth, AppSizes.dialogLg) : AppSizes.dialogLg;
        return Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(
              width: width,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FadeTransition(
                      opacity: _markOpacity,
                      child: SizedBox(
                        key: VetBizLoadingIndicator.ringKey,
                        width: ring,
                        height: ring,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox.expand(
                              child: CircularProgressIndicator(
                                value: still ? 1 : null,
                                strokeWidth: LoadingMetrics.ringStroke,
                                strokeCap: StrokeCap.round,
                                // A soft track under the turning arc.
                                backgroundColor: context.colors.primary.withValues(alpha: AppAlpha.a10),
                                valueColor: AlwaysStoppedAnimation<Color>(context.colors.primary),
                              ),
                            ),
                            Image.asset(
                              AppAssets.logo,
                              key: VetBizLoadingIndicator.markKey,
                              width: mark,
                              height: mark,
                              fit: BoxFit.contain,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (title != null || subtitle != null) ...[
                      const SizedBox(height: LoadingMetrics.captionGap),
                      FadeTransition(
                        opacity: _textOpacity,
                        child: Column(
                          children: [
                            if (title != null)
                              Text(
                                title,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: AppFontWeight.bold,
                                  fontSize: AppFontSize.f16,
                                  color: context.colors.primary,
                                ),
                              ),
                            if (subtitle != null) ...[
                              const SizedBox(height: LoadingMetrics.subtitleGap),
                              AnimatedBuilder(
                                animation: _pulseController,
                                builder: (context, child) {
                                  return Opacity(
                                    opacity: 0.6 + (_pulseController.value * 0.4),
                                    child: child,
                                  );
                                },
                                child: Text(
                                  subtitle,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: AppFontSize.f12_5, color: context.colors.textMuted),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                    if (widget.recoveryAction != null) ...[
                      const SizedBox(height: LoadingMetrics.recoveryGap),
                      FadeTransition(opacity: _textOpacity, child: widget.recoveryAction!),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
