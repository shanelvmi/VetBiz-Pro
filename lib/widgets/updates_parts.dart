import 'package:flutter/material.dart';

import '../config/app_limits.dart';
import '../l10n/l10n.dart';
import '../theme/app_dimens.dart';
import '../theme/app_motion.dart';
import '../theme/app_text.dart';
import '../theme/theme_context.dart';

// The small parts of the login page's Updates (AN2), shared by the slide and
// the carousel: the chip, the label row, the dots, the one layout of the
// area and its loading and empty states (AN6). Roles and tokens only.

/// AN4: where the Updates sit. [wide]: in the left card beside the login
/// card (UpdatesCard), at that card's height: the label larger, the controls
/// pinned to the bottom. Otherwise (phones, and alone): natural height.
class UpdatesPlacement extends InheritedWidget {
  const UpdatesPlacement({super.key, required this.wide, required super.child});

  final bool wide;

  static bool wideOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<UpdatesPlacement>()?.wide ?? false;

  @override
  bool updateShouldNotify(UpdatesPlacement oldWidget) => wide != oldWidget.wide;
}

/// A small text chip of the login page's Updates (AN2): Important or New.
/// On a text slide it sits inside the frame; on a poster, in the label row
/// above it, never on the image.
class UpdateChip extends StatelessWidget {
  const UpdateChip.important({super.key}) : important = true;
  const UpdateChip.fresh({super.key}) : important = false;

  final bool important;

  @override
  Widget build(BuildContext context) {
    // AN4: scaled with the label (12 px beside 16, 14 beside 18).
    final size = UpdatesPlacement.wideOf(context) ? AppFontSize.f14 : AppFontSize.f12;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: AppSpacing.s2),
      decoration: BoxDecoration(
        color: important ? context.colors.danger : context.colors.primary,
        borderRadius: BorderRadius.circular(AppRadius.r4),
      ),
      child: Text(
        important ? context.l10n.updates_important : context.l10n.updates_new,
        style: TextStyle(color: context.colors.onPrimary, fontSize: size, fontWeight: AppFontWeight.bold),
      ),
    );
  }
}

/// AN6 (the owner's design): the Updates' dots, a compact centred row of
/// small 8 px dots; the active one a 28 px pill that fills over the slide's
/// time ([progress]: the carousel's timer, paused with it; full under
/// reduced motion). No arrows. Each dot is a button for taps and screen
/// readers ("Slide n of total", selected) with a tap area of at least
/// [UpdatesMetrics.dotSlot] by [UpdatesMetrics.controlsRow]. The keyboard
/// reaches the row as ONE stop ([focusNode], the carousel moves on Left and
/// Right), shown by a ring. Dots and track in textMuted, the fill in
/// primary: 3:1 or more on the card in every theme, Light and Dark (AN4's
/// check), and the active one is wider, so the state is not colour alone.
/// [onSelect] gets the dot's index.
class UpdatesDots extends StatelessWidget {
  const UpdatesDots({
    super.key,
    required this.count,
    required this.index,
    required this.progress,
    required this.reduceMotion,
    required this.onSelect,
    this.focusNode,
  });

  final int count;
  final int index;
  final Animation<double> progress;
  final bool reduceMotion;
  final ValueChanged<int> onSelect;
  final FocusNode? focusNode;

  /// For tests (AN6): dot [i]'s visible dot or pill, its tap area, the
  /// pill's timer fill, the focusable group and its ring.
  static Key dotKey(int i) => ValueKey<String>('updatesDot$i');
  static Key slotKey(int i) => ValueKey<String>('updatesDotSlot$i');
  static const pillFillKey = Key('updatesPillFill');
  static const groupKey = Key('updatesDotsGroup');
  static const focusRingKey = Key('updatesDotsFocusRing');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final duration = reduceMotion ? Duration.zero : AppMotion.normal;
    // The tap area's extra width around the visible dot (or pill), half on
    // each side.
    const inset = (UpdatesMetrics.dotSlot - UpdatesMetrics.dot) / 2;

    return Center(
      child: Focus(
        key: groupKey,
        focusNode: focusNode,
        child: Builder(
          builder: (context) {
            final focused = Focus.of(context).hasFocus;
            return DecoratedBox(
              key: focusRingKey,
              // Painted over the dots, so the ring takes no room.
              position: DecorationPosition.foreground,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.r16),
                border: Border.all(
                  color: focused ? colors.primary : colors.primary.withValues(alpha: 0),
                  width: UpdatesMetrics.focusRing,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < count; i++)
                    Semantics(
                      button: true,
                      selected: i == index,
                      label: l10n.updates_slideOf(i + 1, count),
                      excludeSemantics: true,
                      child: InkResponse(
                        // The group is the keyboard's one stop, not each dot.
                        canRequestFocus: false,
                        onTap: () => onSelect(i),
                        radius: UpdatesMetrics.dotSlot,
                        child: SizedBox(
                          key: slotKey(i),
                          height: UpdatesMetrics.controlsRow,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: inset),
                            child: Center(
                              child: AnimatedContainer(
                                key: dotKey(i),
                                duration: duration,
                                width: i == index ? UpdatesMetrics.pill : UpdatesMetrics.dot,
                                height: UpdatesMetrics.dot,
                                clipBehavior: Clip.antiAlias,
                                decoration: BoxDecoration(
                                  color: colors.textMuted,
                                  borderRadius: BorderRadius.circular(UpdatesMetrics.dot / 2),
                                ),
                                child:
                                    i == index
                                        ? AnimatedBuilder(
                                          animation: progress,
                                          builder:
                                              (context, _) => FractionallySizedBox(
                                                key: pillFillKey,
                                                alignment: AlignmentDirectional.centerStart,
                                                widthFactor: progress.value,
                                                heightFactor: 1,
                                                child: ColoredBox(color: colors.primary),
                                              ),
                                        )
                                        : null,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// "Updates" above the frame; a poster's Important and New beside it (never
/// on the image). Always the same height, so nothing moves between slides;
/// a long label shortens with an ellipsis and the chips keep their place.
/// AN4: 16 px on phones, 18 px on wide windows, semibold. No icon, no chevron.
/// AN5: bold, in textPrimary (textMuted read faded in Light).
class UpdatesLabel extends StatelessWidget {
  const UpdatesLabel({super.key, required this.showChips, required this.urgent, required this.isNew});

  static const rowKey = Key('updatesLabelRow');

  final bool showChips;
  final bool urgent;
  final bool isNew;

  @override
  Widget build(BuildContext context) {
    final wide = UpdatesPlacement.wideOf(context);
    return SizedBox(
      key: rowKey,
      height: wide ? UpdatesMetrics.labelRowWide : UpdatesMetrics.labelRowPhone,
      child: Row(
        children: [
          Flexible(
            child: Text(
              context.l10n.updates_label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: wide ? AppFontSize.f18 : AppFontSize.f16,
                fontWeight: AppFontWeight.bold,
                color: context.colors.textPrimary,
              ),
            ),
          ),
          if (showChips && urgent) ...[const SizedBox(width: AppSpacing.s8), const UpdateChip.important()],
          if (showChips && isNew) ...[const SizedBox(width: AppSpacing.s6), const UpdateChip.fresh()],
        ],
      ),
    );
  }
}

/// AN6: the one layout of the Updates area, for the slides, the skeleton and
/// the calm panel alike, so the card is the same height in all three and
/// nothing moves when the answer arrives: the label row, the 16:9 frame,
/// the link's line ([link]; null when no slide has a link), and the
/// controls row, always [UpdatesMetrics.controlsRow] tall (empty with one
/// slide or none). In the wide card (UpdatesCard) it fills the card's height
/// and the link and controls sit at its bottom (AN4).
class UpdatesFrameLayout extends StatelessWidget {
  const UpdatesFrameLayout({super.key, required this.label, required this.frame, this.frameKey, this.link, this.controls});

  final Widget label;
  final Widget frame;
  final Key? frameKey;
  final Widget? link;
  final Widget? controls;

  @override
  Widget build(BuildContext context) {
    final inCard = UpdatesPlacement.wideOf(context);
    final link = this.link;
    return Column(
      mainAxisSize: inCard ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        label,
        const SizedBox(height: AppSpacing.s6),
        AspectRatio(
          key: frameKey,
          aspectRatio: AppLimits.posterAspectRatio,
          child: ClipRRect(borderRadius: BorderRadius.circular(AppRadius.r16), child: frame),
        ),
        if (inCard) const Spacer(),
        if (link != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.s6),
            child: SizedBox(height: kMinInteractiveDimension, child: link),
          ),
        SizedBox(height: UpdatesMetrics.controlsRow, child: controls),
      ],
    );
  }
}

/// G6, AN6: the Updates area while nothing is known yet (no answer, and no
/// copy from an earlier visit on this device): the label row and a soft
/// placeholder in the 16:9 frame, gently pulsing (still under reduced
/// motion), in the same layout as the slides. Nothing to read in it.
class UpdatesSkeleton extends StatefulWidget {
  const UpdatesSkeleton({super.key});

  @override
  State<UpdatesSkeleton> createState() => _UpdatesSkeletonState();
}

class _UpdatesSkeletonState extends State<UpdatesSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: AppMotion.loop);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse.value = 1;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: UpdatesFrameLayout(
        label: const UpdatesLabel(showChips: false, urgent: false, isNew: false),
        frame: FadeTransition(
          opacity: _pulse.drive(Tween(begin: AppAlpha.a50, end: 1)),
          child: ColoredBox(color: context.colors.surfaceMuted),
        ),
      ),
    );
  }
}

/// AN6: the Updates area when the answer is that there is nothing to show
/// in this language: a calm sentence in the same 16:9 frame, no chips, no
/// controls, so the card keeps its place and its height.
class UpdatesEmpty extends StatelessWidget {
  const UpdatesEmpty({super.key});

  @override
  Widget build(BuildContext context) {
    return UpdatesFrameLayout(
      label: const UpdatesLabel(showChips: false, urgent: false, isNew: false),
      frame: ColoredBox(
        color: context.colors.surfaceMuted,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s16),
            child: Text(
              context.l10n.updates_empty,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: AppFontSize.f14, color: context.colors.textSecondary),
            ),
          ),
        ),
      ),
    );
  }
}
