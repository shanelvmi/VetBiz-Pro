import 'package:flutter/material.dart';

import '../../theme/app_motion.dart';
import 'reveal_gate.dart';
import 'skeleton_box.dart';

/// RV2b (docs/design/screen_reveal.md 8.4): every list and card image in one
/// place. A fixed [width] x [height] slot shows [placeholder] (the initials)
/// or, with none, a soft skeleton; the image fades in over it once its
/// first frame is decoded (at once when it was already decoded, instantly
/// under reduced motion), decoded at twice the slot's size. A failed image
/// keeps the placeholder. Nothing around the slot moves when it arrives.
///
/// Inside a reveal whose gate has an image grace, the first screenful of
/// images may hold the reveal briefly (RevealGate.holdForImage): an image
/// offscreen once laid out, failing or gone never does.
class RevealImage extends StatefulWidget {
  const RevealImage({
    super.key,
    required this.url,
    required this.width,
    required this.height,
    this.placeholder,
    this.fit = BoxFit.cover,
  });

  final String? url;
  final double width;
  final double height;

  /// What the slot shows under the image and when it fails; null: a soft
  /// skeleton while it loads.
  final Widget? placeholder;
  final BoxFit fit;

  /// The image behind a URL: NetworkImage in the app, a fake in tests.
  @visibleForTesting
  static ImageProvider Function(String url) providerFor = NetworkImage.new;

  /// The provider decoded at twice the slot's size, keeping its aspect.
  static ImageProvider decodedAt(ImageProvider image, double width, double height) => ResizeImage(
        image,
        width: (width * 2).round(),
        height: (height * 2).round(),
        policy: ResizeImagePolicy.fit,
      );

  @override
  State<RevealImage> createState() => _RevealImageState();
}

class _ImageSource extends RevealSource {
  void answer() => markAnswered();
}

class _RevealImageState extends State<RevealImage> {
  RevealGate? _gate;
  _ImageSource? _source;
  bool _failed = false;

  bool get _hasUrl => (widget.url ?? '').isNotEmpty;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_source != null || !_hasUrl) return;
    final gate = RevealImageScope.gateOf(context);
    final source = _ImageSource();
    if (gate == null || !gate.holdForImage(source)) return;
    _gate = gate;
    _source = source;
    // Only the first screenful counts: once laid out, an image below (or
    // above) the screen lets go.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return _release();
      final box = context.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) return _release();
      final top = box.localToGlobal(Offset.zero).dy;
      final screen = MediaQuery.sizeOf(context).height;
      if (top >= screen || top + box.size.height <= 0) _release();
    });
  }

  void _release() {
    final gate = _gate, source = _source;
    if (gate != null && source != null && !source.answered) gate.releaseImage(source);
  }

  // Answered after the frame: the gate's reveal rebuilds an ancestor.
  void _answer() {
    final source = _source;
    if (source == null || source.answered) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => source.answer());
  }

  @override
  void didUpdateWidget(RevealImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) _failed = false;
  }

  @override
  void dispose() {
    _release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    final placeholder = widget.placeholder ??
        (_failed || !_hasUrl ? const SkeletonBox(radius: 0) : const SkeletonPulse(child: SkeletonBox(radius: 0)));
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          placeholder,
          if (_hasUrl && !_failed)
            Image(
              key: const ValueKey('revealImage-image'),
              image: RevealImage.decodedAt(RevealImage.providerFor(widget.url!), widget.width, widget.height),
              width: widget.width,
              height: widget.height,
              fit: widget.fit,
              gaplessPlayback: true,
              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                if (frame != null) _answer();
                if (wasSynchronouslyLoaded || still) return frame == null ? const SizedBox.shrink() : child;
                return AnimatedOpacity(
                  opacity: frame == null ? 0 : 1,
                  duration: AppMotion.revealDuration,
                  curve: AppMotion.revealCurve,
                  child: child,
                );
              },
              errorBuilder: (context, error, stackTrace) {
                _answer();
                // The placeholder stays; the skeleton stops pulsing.
                if (!_failed) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() => _failed = true);
                  });
                }
                return const SizedBox.shrink();
              },
            ),
        ],
      ),
    );
  }
}

/// RV2b: the gate a reveal's content images may hold (ScreenReveal puts it
/// around its content).
class RevealImageScope extends InheritedWidget {
  const RevealImageScope({super.key, required this.gate, required super.child});

  final RevealGate gate;

  static RevealGate? gateOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<RevealImageScope>()?.gate;

  @override
  bool updateShouldNotify(RevealImageScope oldWidget) => oldWidget.gate != gate;
}
