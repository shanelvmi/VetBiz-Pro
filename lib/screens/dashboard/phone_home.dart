import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_text.dart';
import '../../theme/theme_context.dart';
import '../../widgets/profile/profile_avatar.dart';
import '../../widgets/reveal/reveal.dart';
import 'dashboard_figures.dart';
import 'needs_attention.dart';
import 'phone_home_rows.dart';
import 'record_sheet.dart';
import 'today_card.dart';

export 'dashboard_figures.dart';
export 'phone_home_rows.dart' show GoToItem, goToItemsFor, goToMoreItem, goToLabel;
export 'today_card.dart' show TodayCard;

/// PH4: Home's top bar content (phone_shell.md section 3): the avatar (opens
/// the profile drawer), a small greeting over the name, then [actions] (the
/// bell and Help). The dashboard wraps it in its AppBar.
class PhoneHomeTopBar extends StatelessWidget {
  final String greeting;
  final String name;
  final String? avatarUrl;
  final VoidCallback onAvatar;

  const PhoneHomeTopBar({
    super.key,
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
                greeting,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: PhoneHomeMetrics.greeting, color: colors.textMuted),
              ),
              if (name.isNotEmpty)
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: PhoneHomeMetrics.name,
                    fontWeight: AppFontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// PH4: the phone's Home tab body (phone_shell.md D2): the Today card, Quick
/// access, Go to and, only when something needs it, Needs attention. It
/// reads nothing itself: the dashboard hands it its figures.
class PhoneHome extends StatelessWidget {
  final PhoneHomeFigures figures;
  final bool isAdmin;
  final String period;
  final ValueChanged<String> onPeriodChanged;
  final AttentionCounts attention;
  final VoidCallback onAllDetails;
  final Future<void> Function(RecordAction action) onQuickAction;
  final VoidCallback onViewAll;
  final ValueChanged<GoToItem> onGoTo;
  final ValueChanged<AttentionTarget> onAttention;

  /// Drawn over the top of the page (the subscription pill).
  final Widget? overlay;

  /// RV1: Home's skeleton, the same layout drawn as soft boxes
  /// (docs/design/screen_reveal.md).
  final bool skeleton;

  /// RV1: whether Needs attention's data (products and debts) has answered;
  /// until then its late slot keeps a place at the end of the list.
  final bool attentionReady;

  /// NAV1: the Today card's amounts are masked, and its eye (null: none).
  final bool amountsHidden;
  final VoidCallback? onToggleAmounts;

  /// UI3: the current facility's name for the Today card.
  final String facilityName;

  const PhoneHome({
    super.key,
    required this.figures,
    required this.isAdmin,
    required this.period,
    required this.onPeriodChanged,
    required this.attention,
    required this.onAllDetails,
    required this.onQuickAction,
    required this.onViewAll,
    required this.onGoTo,
    required this.onAttention,
    this.overlay,
    this.skeleton = false,
    this.attentionReady = true,
    this.amountsHidden = false,
    this.onToggleAmounts,
    this.facilityName = '',
  });

  /// [child] as it is, or as a soft box of its size in the skeleton.
  Widget skeletonOf(Widget child, {double radius = RevealMetrics.skeletonRadius}) =>
      skeleton ? SkeletonOf(radius: radius, child: child) : child;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final list = ListView(
      padding: const EdgeInsets.all(PhoneHomeMetrics.pagePadding),
      children: [
        skeletonOf(
          TodayCard(
            figures: figures,
            isAdmin: isAdmin,
            period: period,
            onPeriodChanged: onPeriodChanged,
            onAllDetails: onAllDetails,
            amountsHidden: amountsHidden,
            onToggleAmounts: onToggleAmounts,
            facilityName: facilityName,
          ),
          radius: PhoneHomeMetrics.cardRadius,
        ),
        const SizedBox(height: PhoneHomeMetrics.sectionGap),
        _SectionTitle(title: l10n.home_quickAccess, link: l10n.subscription_viewAll, onLink: onViewAll, skeleton: skeleton),
        QuickAccessTiles(onAction: onQuickAction, skeleton: skeleton),
        const SizedBox(height: PhoneHomeMetrics.sectionGap),
        _SectionTitle(title: l10n.home_goTo, skeleton: skeleton),
        GoToRow(items: goToItemsFor(isAdmin: isAdmin), onGoTo: onGoTo, skeleton: skeleton),
        // A late slot (secondary): the last block, so while it waits it keeps
        // a place below everything else, and when it answers with nothing to
        // show it is not drawn; nothing is below it to move.
        if (!attentionReady || !attention.isEmpty) ...[
          const SizedBox(height: PhoneHomeMetrics.sectionGap),
          if (skeleton)
            attentionReady
                ? skeletonOf(NeedsAttentionStrip(counts: attention, onOpen: onAttention))
                : const SkeletonBox(height: RevealMetrics.attentionReserve)
          else
            LateSlot(
              height: attentionReady ? null : RevealMetrics.attentionReserve,
              ready: attentionReady,
              child: NeedsAttentionStrip(counts: attention, onOpen: onAttention),
            ),
        ],
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

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? link;
  final VoidCallback? onLink;
  final bool skeleton;

  const _SectionTitle({required this.title, this.link, this.onLink, this.skeleton = false});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final titleText = Text(
      title,
      style: TextStyle(
        fontSize: PhoneHomeMetrics.sectionTitle,
        fontWeight: AppFontWeight.semibold,
        color: colors.textPrimary,
      ),
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: PhoneHomeMetrics.linkHeight),
      child: Row(
        children: [
          Expanded(
            child: skeleton
                ? Align(alignment: AlignmentDirectional.centerStart, child: SkeletonOf(child: titleText))
                : titleText,
          ),
          if (link != null)
            TextButton(
              onPressed: skeleton ? null : onLink,
              style: TextButton.styleFrom(
                foregroundColor: colors.primary,
                minimumSize: const Size(PhoneHomeMetrics.linkHeight, PhoneHomeMetrics.linkHeight),
              ),
              child: skeleton ? SkeletonOf(child: Text(link!)) : Text(link!),
            ),
        ],
      ),
    );
  }
}

