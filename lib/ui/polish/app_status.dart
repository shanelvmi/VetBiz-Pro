import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../theme/polish_metrics.dart';
import '../../theme/theme_context.dart';

/// POL1, owner rule 2: colour means one of four states, nothing else. A
/// category, type, method or kind is never coloured.
enum AppStatus { success, warning, danger, neutral }

extension AppStatusRole on AppStatus {
  /// The state's role (the dot's colour).
  Color roleIn(AppColors c) => switch (this) {
        AppStatus.success => c.success,
        AppStatus.warning => c.warning,
        AppStatus.danger => c.danger,
        AppStatus.neutral => c.textSecondary,
      };
}

/// POL1, owner rule 3: the one status style, a small dot plus the word, in
/// one size and one gap. The word is always shown, so the state never rests
/// on colour alone; it is in textPrimary, which reads on every surface.
class StatusDot extends StatelessWidget {
  final AppStatus status;
  final String label;

  const StatusDot({super.key, required this.status, required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // A SizedBox and a DecoratedBox: a round dot, never read as a strip.
        SizedBox(
          key: const ValueKey('statusDot-dot'),
          width: PolishMetrics.dot,
          height: PolishMetrics.dot,
          child: DecoratedBox(decoration: BoxDecoration(color: status.roleIn(colors), shape: BoxShape.circle)),
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
    );
  }
}
