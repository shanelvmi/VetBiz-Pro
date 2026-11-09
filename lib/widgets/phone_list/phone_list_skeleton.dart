import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_motion.dart';
import '../../theme/theme_context.dart';

// PH5a R9: while a phone list's first page loads, six rows shaped like the
// real ones, with a soft pulse; still when the platform asks for reduced
// motion.

class PhoneListSkeleton extends StatefulWidget {
  const PhoneListSkeleton({super.key, this.pulse = true});

  /// RV2: false inside a reveal's skeleton, which pulses as a whole.
  final bool pulse;

  @override
  State<PhoneListSkeleton> createState() => _PhoneListSkeletonState();
}

class _PhoneListSkeletonState extends State<PhoneListSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: AppMotion.loop);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context) || !widget.pulse;
    if (still) {
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
    final rows = Column(
      children: [for (var i = 0; i < PhoneListMetrics.skeletonRows; i++) _SkeletonRow(key: ValueKey('phoneList-skeletonRow-$i'))],
    );
    return Semantics(
      label: context.l10n.common_loading,
      child: still
          ? rows
          : FadeTransition(
              opacity: Tween<double>(begin: 1, end: PhoneListMetrics.skeletonLow).animate(_pulse),
              child: rows,
            ),
    );
  }
}

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow({super.key});

  @override
  Widget build(BuildContext context) {
    final fill = context.colors.surfaceMuted;
    Widget bar(double width) => Container(
          width: width,
          height: PhoneListMetrics.skeletonBar,
          decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(PhoneListMetrics.chipRadius)),
        );
    return SizedBox(
      height: PhoneListMetrics.rowMinHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: PhoneListMetrics.pagePadding),
        child: Row(
          children: [
            Container(
              width: PhoneListMetrics.leading,
              height: PhoneListMetrics.leading,
              decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
            ),
            const SizedBox(width: PhoneListMetrics.leadingGap),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                bar(PhoneListMetrics.skeletonBarWide),
                const SizedBox(height: PhoneListMetrics.headerGap),
                bar(PhoneListMetrics.skeletonBarNarrow),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
