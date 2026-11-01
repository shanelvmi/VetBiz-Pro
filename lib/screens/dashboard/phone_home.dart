import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_text.dart';
import '../../theme/theme_context.dart';
import '../../widgets/profile/profile_avatar.dart';
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
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final list = ListView(
      padding: const EdgeInsets.all(PhoneHomeMetrics.pagePadding),
      children: [
        TodayCard(
          figures: figures,
          isAdmin: isAdmin,
          period: period,
          onPeriodChanged: onPeriodChanged,
          onAllDetails: onAllDetails,
        ),
        const SizedBox(height: PhoneHomeMetrics.sectionGap),
        _SectionTitle(title: l10n.home_quickAccess, link: l10n.subscription_viewAll, onLink: onViewAll),
        QuickAccessTiles(onAction: onQuickAction),
        const SizedBox(height: PhoneHomeMetrics.sectionGap),
        _SectionTitle(title: l10n.home_goTo),
        GoToRow(items: goToItemsFor(isAdmin: isAdmin), onGoTo: onGoTo),
        if (!attention.isEmpty) ...[
          const SizedBox(height: PhoneHomeMetrics.sectionGap),
          NeedsAttentionStrip(counts: attention, onOpen: onAttention),
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

  const _SectionTitle({required this.title, this.link, this.onLink});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: PhoneHomeMetrics.linkHeight),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: PhoneHomeMetrics.sectionTitle,
                fontWeight: AppFontWeight.semibold,
                color: colors.textPrimary,
              ),
            ),
          ),
          if (link != null)
            TextButton(
              onPressed: onLink,
              style: TextButton.styleFrom(
                foregroundColor: colors.primary,
                minimumSize: const Size(PhoneHomeMetrics.linkHeight, PhoneHomeMetrics.linkHeight),
              ),
              child: Text(link!),
            ),
        ],
      ),
    );
  }
}

