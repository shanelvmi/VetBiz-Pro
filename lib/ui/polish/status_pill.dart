import 'package:flutter/material.dart';

import '../../theme/app_text.dart';
import '../../theme/polish_metrics.dart';
import '../../theme/theme_context.dart';
import 'app_status.dart';

/// POL2, owner rule 3: the one low-opacity pill, only where a pill is truly
/// needed (a figure's change beside a large amount, for example). It is the
/// StatusDot inside a soft fill of the state's role: the same word size, the
/// same gap after the dot, the word in textPrimary. [icon], when given,
/// takes the dot's place in the role's colour (an arrow saying up or down);
/// the word is always there, so the state never rests on colour alone. No
/// other pill style exists.
class StatusPill extends StatelessWidget {
  final AppStatus status;
  final String label;
  final IconData? icon;

  const StatusPill({super.key, required this.status, required this.label, this.icon});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final role = status.roleIn(colors);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: PolishMetrics.pillPaddingH, vertical: PolishMetrics.pillPaddingV),
      decoration: BoxDecoration(
        color: role.withValues(alpha: PolishMetrics.pillAlpha),
        borderRadius: BorderRadius.circular(PolishMetrics.pillRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Icon(icon, key: const ValueKey('statusPill-icon'), size: PolishMetrics.statusText, color: role)
          else
            SizedBox(
              key: const ValueKey('statusPill-dot'),
              width: PolishMetrics.dot,
              height: PolishMetrics.dot,
              child: DecoratedBox(decoration: BoxDecoration(color: role, shape: BoxShape.circle)),
            ),
          const SizedBox(width: PolishMetrics.dotGap),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: PolishMetrics.statusText,
                fontWeight: AppFontWeight.medium,
                color: colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
