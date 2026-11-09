import 'package:flutter/material.dart';

import '../theme/app_motion.dart';

/// UI5: the one press feedback of Home's tiles, Today card and attention
/// strip: the child shrinks to AppMotion.pressScale over AppMotion.press
/// while a pointer is down on it, and springs back on release or cancel;
/// none under reduced motion. It only listens: the child's own InkWell (or
/// button) still gets the tap.
class PressScale extends StatefulWidget {
  final Widget child;

  const PressScale({super.key, required this.child});

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  void _set(bool down) {
    if (_down != down && mounted) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down && !still ? AppMotion.pressScale : 1,
        duration: still ? Duration.zero : AppMotion.press,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
