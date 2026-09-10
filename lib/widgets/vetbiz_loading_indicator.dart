import 'package:flutter/material.dart';

/// Two weights of the same branded loading treatment - [full] for a
/// one-time, meaningful wait (right now, only the very first "we're
/// setting up your account" moment after login), [compact] for the
/// many small, routine loads that happen throughout ordinary use
/// (opening a screen, paginating a list). Using the full treatment
/// everywhere would make the app feel slower and more repetitive, not
/// more polished - loading UI should be proportional to what's
/// actually being waited for.
enum VetBizLoadingStyle { full, compact }

class VetBizLoadingIndicator extends StatefulWidget {
  final VetBizLoadingStyle style;
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
    this.style = VetBizLoadingStyle.compact,
    this.title,
    this.subtitle,
    this.recoveryAction,
  });

  // Shared brand colors, matching what's already used throughout the
  // app (primaryDeepGreen/warmAmber, as seen in facility_picker_screen
  // .dart and elsewhere) - kept here too so this widget doesn't depend
  // on importing a screen file just for its color constants.
  static const Color primaryColor = Color(0xFF2F5D62);
  static const Color amberColor = Color(0xFFFFB200);
  static const Color backgroundColor = Color(0xFFFDFDF9);

  @override
  State<VetBizLoadingIndicator> createState() => _VetBizLoadingIndicatorState();
}

class _VetBizLoadingIndicatorState extends State<VetBizLoadingIndicator> with TickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _illustrationOpacity;
  late final Animation<double> _illustrationScale;
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
      duration: const Duration(milliseconds: 900),
    );

    // Staggered within the same controller via Interval, rather than
    // several separate controllers - logo first, illustration close
    // behind with a gentle scale-up, text last, each easing in softly.
    _logoOpacity = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
    );
    _illustrationOpacity = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.2, 0.7, curve: Curves.easeOut),
    );
    _illustrationScale = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _entranceController, curve: const Interval(0.2, 0.7, curve: Curves.easeOutCubic)),
    );
    _textOpacity = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
    );

    _entranceController.forward();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.style == VetBizLoadingStyle.compact) {
      return _buildCompact();
    }
    return _buildFull(context);
  }

  Widget _buildCompact() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: _logoOpacity,
            child: Image.asset('assets/vetbiz_pro_logo.png', height: 40),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(
              strokeWidth: 2.6,
              strokeCap: StrokeCap.round,
              valueColor: AlwaysStoppedAnimation<Color>(VetBizLoadingIndicator.primaryColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFull(BuildContext context) {
    return Stack(
      children: [
        // Decorative teal/amber curved shapes in the corners - large,
        // soft-edged circles positioned mostly off-screen, very low
        // opacity so they read as texture rather than competing with
        // the actual content.
        Positioned(
          top: -80,
          left: -80,
          child: _decorativeBlob(220, VetBizLoadingIndicator.primaryColor.withValues(alpha: 0.06)),
        ),
        Positioned(
          bottom: -100,
          right: -100,
          child: _decorativeBlob(260, VetBizLoadingIndicator.amberColor.withValues(alpha: 0.08)),
        ),
        // Very subtle scattered paw marks - low opacity background
        // texture, not meant to be individually noticed.
        const Positioned(top: 60, right: 40, child: Icon(Icons.pets, size: 28, color: Color(0x0A2F5D62))),
        const Positioned(bottom: 140, left: 30, child: Icon(Icons.pets, size: 22, color: Color(0x0A2F5D62))),
        const Positioned(top: 220, left: 60, child: Icon(Icons.pets, size: 18, color: Color(0x0A2F5D62))),

        Center(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Reduce illustration size and spacing on smaller
              // screens rather than letting content overflow, instead
              // of just shrinking everything uniformly.
              final isCompact = constraints.maxWidth < 420;
              final illustrationHeight = isCompact ? 140.0 : 200.0;

              return ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FadeTransition(
                        opacity: _logoOpacity,
                        child: Image.asset('assets/vetbiz_pro_logo.png', height: isCompact ? 80 : 100),
                      ),
                      SizedBox(height: isCompact ? 24 : 32),
                      FadeTransition(
                        opacity: _illustrationOpacity,
                        child: ScaleTransition(
                          scale: _illustrationScale,
                          child: Image.asset(
                            'assets/vetbiz_loading_illustration.png',
                            height: illustrationHeight,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      SizedBox(height: isCompact ? 28 : 36),
                      SizedBox(
                        width: 36,
                        height: 36,
                        child: CircularProgressIndicator(
                          strokeWidth: 3.5,
                          strokeCap: StrokeCap.round,
                          valueColor: AlwaysStoppedAnimation<Color>(VetBizLoadingIndicator.primaryColor),
                        ),
                      ),
                      const SizedBox(height: 24),
                      FadeTransition(
                        opacity: _textOpacity,
                        child: Column(
                          children: [
                            Text(
                              widget.title ?? 'Loading your account...',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: VetBizLoadingIndicator.primaryColor,
                              ),
                            ),
                            const SizedBox(height: 6),
                            AnimatedBuilder(
                              animation: _pulseController,
                              builder: (context, child) {
                                return Opacity(
                                  opacity: 0.6 + (_pulseController.value * 0.4),
                                  child: child,
                                );
                              },
                              child: Text(
                                widget.subtitle ?? 'Preparing your facility data and services',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12.5, color: Colors.grey[600]),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (widget.recoveryAction != null) ...[
                        const SizedBox(height: 20),
                        FadeTransition(opacity: _textOpacity, child: widget.recoveryAction!),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _decorativeBlob(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
