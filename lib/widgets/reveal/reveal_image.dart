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

  /// A slot the size of its parent (a padded logo box): decoded at twice the
  /// size the parent gives it.
  const RevealImage.fill({super.key, required this.url, this.placeholder, this.fit = BoxFit.contain})
    : width = double.infinity,
      height = double.infinity;

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

  /// The provider decoded at twice the slot's size, keeping its aspect; an
  /// unbounded side decodes at the image's own size.
  static ImageProvider decodedAt(ImageProvider image, double width, double height) =>
      !width.isFinite || !height.isFinite
          ? image
          : ResizeImage(image, width: (width * 2).round(), height: (height * 2).round(), policy: ResizeImagePolicy.fit);

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
  // The first frame is decoded: the image fades in and the placeholder fades
  // out under it (a logo with transparent parts never shows the initials
  // through); at once when it was already decoded.
  bool _decoded = false;
  bool _decodedAtOnce = false;

  // The slot listens to its image itself (the same cached stream the Image
  // draws, so no second load): the decode or the failure answers the gate
  // when it happens, not a frame later from a builder.
  ImageProvider? _provider;
  ImageStream? _stream;
  late final ImageStreamListener _listener = ImageStreamListener(_onImage, onError: _onError);
  bool _resolving = false;

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

  /// Listens to [provider] (from the slot's layout), once per image.
  void _watch(ImageProvider provider) {
    if (provider == _provider) return;
    _provider = provider;
    _stream?.removeListener(_listener);
    final stream = provider.resolve(createLocalImageConfiguration(context));
    _stream = stream;
    // An image already decoded answers inside addListener, during layout.
    _resolving = true;
    stream.addListener(_listener);
    _resolving = false;
  }

  void _onImage(ImageInfo info, bool synchronousCall) {
    info.dispose();
    if (_decoded) return;
    final atOnce = _resolving || synchronousCall;
    _settle(() {
      _decoded = true;
      _decodedAtOnce = atOnce;
    });
  }

  void _onError(Object error, StackTrace? stackTrace) {
    // The placeholder stays; the skeleton stops pulsing.
    if (!_failed) _settle(() => _failed = true);
  }

  // Updates the slot and answers the gate; during layout, after the frame.
  void _settle(VoidCallback change) {
    void run() {
      if (!mounted) return;
      setState(change);
      final source = _source;
      if (source != null && !source.answered) source.answer();
    }

    if (_resolving) {
      WidgetsBinding.instance.addPostFrameCallback((_) => run());
    } else {
      run();
    }
  }

  @override
  void didUpdateWidget(RevealImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _failed = false;
      _decoded = false;
      _decodedAtOnce = false;
    }
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    _release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    final placeholder =
        widget.placeholder ??
        (_failed || !_hasUrl ? const SkeletonBox(radius: 0) : const SkeletonPulse(child: SkeletonBox(radius: 0)));
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedOpacity(
            opacity: _decoded ? 0 : 1,
            duration: still || _decodedAtOnce ? Duration.zero : AppMotion.revealDuration,
            curve: AppMotion.revealCurve,
            child: Center(child: placeholder),
          ),
          if (_hasUrl && !_failed)
            // The slot's laid-out size (a .fill slot's comes from its parent).
            LayoutBuilder(
              builder: (context, slot) {
                final image = RevealImage.decodedAt(RevealImage.providerFor(widget.url!), slot.maxWidth, slot.maxHeight);
                _watch(image);
                return Image(
                  key: const ValueKey('revealImage-image'),
                  image: image,
                  width: slot.maxWidth,
                  height: slot.maxHeight,
                  fit: widget.fit,
                  gaplessPlayback: true,
                  frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                    if (wasSynchronouslyLoaded || still) return frame == null ? const SizedBox.shrink() : child;
                    return AnimatedOpacity(
                      opacity: frame == null ? 0 : 1,
                      duration: AppMotion.revealDuration,
                      curve: AppMotion.revealCurve,
                      child: child,
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                );
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

  static RevealGate? gateOf(BuildContext context) => context.getInheritedWidgetOfExactType<RevealImageScope>()?.gate;

  @override
  bool updateShouldNotify(RevealImageScope oldWidget) => oldWidget.gate != gate;
}
