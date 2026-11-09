import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_text.dart';
import '../../theme/theme_context.dart';
import '../../widgets/profile/profile_avatar.dart';
import '../../widgets/reveal/reveal.dart';
import 'dashboard_figures.dart';
import 'needs_attention.dart';
import 'phone_home_rows.dart';
import 'phone_shell.dart';
import 'today_card.dart';

export 'dashboard_figures.dart';
export 'phone_home_rows.dart' show HomeActionGrid, HomeTile, homeTilesFor, homeTileAction, homeTilePlace, homeTileLabel;
export 'today_card.dart' show TodayCard;

/// UI5: Home's top bar content: the avatar (opens the profile drawer), then
/// the current facility's name (FacilityDisplay.name, 16 semibold) over the
/// greeting ("Good afternoon, Mr. Time", 12 muted), each one line. The
/// dashboard wraps it in its AppBar with the bell (no Help: More has it).
class PhoneHomeTopBar extends StatelessWidget {
  final String facilityName;
  final String greeting;

  /// The person's name, for the avatar's initials.
  final String name;
  final String? avatarUrl;
  final VoidCallback onAvatar;

  const PhoneHomeTopBar({
    super.key,
    required this.facilityName,
    required this.greeting,
    required this.name,
    required this.avatarUrl,
    required this.onAvatar,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        Tooltip(
          message: context.l10n.dashboard_account,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onAvatar,
            child: SizedBox.square(
              dimension: PhoneHomeMetrics.linkHeight,
              child: Center(child: ProfileAvatar(avatarUrl: avatarUrl, name: name, size: PhoneHomeMetrics.avatar)),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.s8),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                facilityName,
                key: const ValueKey('phone-home-facility-name'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: PhoneHomeMetrics.topBarName,
                  fontWeight: AppFontWeight.semibold,
                  color: colors.textPrimary,
                ),
              ),
              Text(
                greeting,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: PhoneHomeMetrics.topBarGreeting, color: colors.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// UI5: the phone's Home tab body, calm and meant to fit between the bars
/// without scrolling: the Today card, then (only when something needs it)
/// ONE Needs attention strip, then the 4 x 2 action grid. The list stays a
/// scroll view only as a safety net (large text, landscape). It reads nothing
/// itself: the dashboard hands it its figures.
class PhoneHome extends StatelessWidget {
  final PhoneHomeFigures figures;
  final bool isAdmin;
  final String period;

  /// The exact range the figures cover (dashboardPeriodRangeLabel).
  final String periodLabel;
  final ValueChanged<String> onPeriodChanged;
  final VoidCallback onAllDetails;

  /// What needs attention, most urgent first (attentionItemsFor).
  final List<AttentionItem> attention;

  /// The strip's tap: the sheet of every item.
  final VoidCallback onAttention;

  /// A grid tile's tap (a record action or a place).
  final Future<void> Function(HomeTile tile) onTile;

  /// Drawn over the top of the page (the subscription pill).
  final Widget? overlay;

  /// RV1: Home's skeleton, the same layout drawn as soft boxes
  /// (docs/design/screen_reveal.md).
  final bool skeleton;

  /// RV1: whether Needs attention's data (products and debts) has answered;
  /// until then its slot keeps the strip's place.
  final bool attentionReady;

  /// NAV1: the Today card's amounts are masked, and its eye (null: none).
  final bool amountsHidden;
  final VoidCallback? onToggleAmounts;

  const PhoneHome({
    super.key,
    required this.figures,
    required this.isAdmin,
    required this.period,
    required this.onPeriodChanged,
    required this.attention,
    required this.onAllDetails,
    required this.onAttention,
    required this.onTile,
    this.periodLabel = '',
    this.overlay,
    this.skeleton = false,
    this.attentionReady = true,
    this.amountsHidden = false,
    this.onToggleAmounts,
  });

  /// The strip's slot: while its data has not answered, a reserved place of
  /// the strip's height (a soft box in the skeleton, a LateSlot in the
  /// content); then the strip, or nothing. A strip that comes or goes later
  /// (the data changed) animates its height once; at once under reduced
  /// motion.
  Widget _attentionSlot(BuildContext context) {
    const gap = SizedBox(height: PhoneHomeMetrics.stripGap);
    Widget? slot;
    if (skeleton) {
      if (!attentionReady) {
        slot = const SkeletonBox(height: PhoneHomeMetrics.attentionStripHeight);
      } else if (attention.isNotEmpty) {
        slot = SkeletonOf(
          radius: PhoneHomeMetrics.cardRadius,
          child: AttentionStrip(items: attention, onTap: () {}),
        );
      }
    } else if (!attentionReady || attention.isNotEmpty) {
      slot = LateSlot(
        height: attentionReady ? null : PhoneHomeMetrics.attentionStripHeight,
        ready: attentionReady,
        child: attention.isEmpty ? const SizedBox.shrink() : AttentionStrip(items: attention, onTap: onAttention),
      );
    }
    return AnimatedSize(
      duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : AppMotion.attentionResize,
      alignment: Alignment.topCenter,
      child: slot == null
          ? const SizedBox(width: double.infinity)
          : Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [gap, slot]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final card = TodayCard(
      figures: figures,
      isAdmin: isAdmin,
      period: period,
      periodLabel: periodLabel,
      onPeriodChanged: onPeriodChanged,
      onAllDetails: onAllDetails,
      amountsHidden: amountsHidden,
      onToggleAmounts: onToggleAmounts,
    );
    final list = ListView(
      key: const ValueKey('phone-home-list'),
      // UI4: the end of the page clears the shell's raised "+".
      padding: EdgeInsets.fromLTRB(
        PhoneHomeMetrics.pagePadding,
        PhoneHomeMetrics.pagePadding,
        PhoneHomeMetrics.pagePadding,
        PhoneHomeMetrics.pagePadding + PhoneShellInsets.overhangOf(context),
      ),
      children: [
        if (skeleton) SkeletonOf(radius: PhoneHomeMetrics.cardRadius, child: card) else card,
        _attentionSlot(context),
        const SizedBox(height: PhoneHomeMetrics.stripGap),
        HomeActionGrid(tiles: homeTilesFor(isAdmin: isAdmin), onTile: onTile, skeleton: skeleton),
      ],
    );
    return ColoredBox(
      color: context.colors.background,
      child: overlay == null
          ? list
          : Stack(children: [list, Positioned(top: AppSpacing.s8, left: 0, right: 0, child: Center(child: overlay))]),
    );
  }
}
