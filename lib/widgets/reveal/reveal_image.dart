import 'package:flutter/material.dart';

import 'reveal_gate.dart';
import 'skeleton_box.dart';

/// RV2b (docs/design/screen_reveal.md 8.4): every list and card image in one
/// place: a fixed slot with the initials (or a soft skeleton), the image
/// fading in over it. Declared for the tests; not wired yet.
class RevealImage extends StatelessWidget {
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
  final Widget? placeholder;
  final BoxFit fit;

  /// The image behind a URL: NetworkImage in the app, a fake in tests.
  @visibleForTesting
  static ImageProvider Function(String url) providerFor = NetworkImage.new;

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: width, height: height, child: placeholder ?? const SkeletonBox(radius: 0));
}

/// RV2b: the gate a reveal's content images may hold (not wired yet).
class RevealImageScope extends InheritedWidget {
  const RevealImageScope({super.key, required this.gate, required super.child});

  final RevealGate gate;

  @override
  bool updateShouldNotify(RevealImageScope oldWidget) => oldWidget.gate != gate;
}
