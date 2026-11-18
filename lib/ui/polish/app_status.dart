import 'package:flutter/material.dart';

import '../../data/payment_status.dart';
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

/// POL4: a sale's or a service's payment status (the STORED value,
/// [PaymentStatus.of]) as one of the four states: the one mapping the Sales
/// and Services lists, their archives, details and the receipt preview's
/// panel use (before POL4 four copies of it in the lists, and the receipt
/// panel showed a part payment red). An unknown value is neutral.
AppStatus paymentAppStatus(String status) => switch (status) {
      PaymentStatus.paid => AppStatus.success,
      PaymentStatus.partial => AppStatus.warning,
      PaymentStatus.unpaid => AppStatus.danger,
      _ => AppStatus.neutral,
    };

/// POL7: a daily report's STORED status ('draft' | 'submitted', DailyReport)
/// as one of the four states: the one mapping Past Reports, View Reports,
/// the detail and the full view use (each had its own pill or coloured
/// text). Submitted is done (success); a draft still waits (warning); an
/// unknown value is neutral. The words shown are unchanged.
AppStatus reportAppStatus(String status) => switch (status) {
      'submitted' => AppStatus.success,
      'draft' => AppStatus.warning,
      _ => AppStatus.neutral,
    };

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

/// POL5: a product's stock status (the STORED value products_screen's
/// `_getProductStatus` writes and the counts and status filter compare:
/// Active, Depleted, Low Stock, Reorder Soon, Expiring Soon, Expired, Not
/// Stocked, Unknown) as one of the four states. It takes the stored English
/// text, never a translated label, so the dot is the same in every language.
/// Nothing in stock is "success": in stock is the normal case, so neutral.
/// An unknown value is neutral.
AppStatus stockAppStatus(String storedStatus) => switch (storedStatus) {
      'Depleted' || 'Expired' => AppStatus.danger,
      'Low Stock' || 'Reorder Soon' || 'Expiring Soon' => AppStatus.warning,
      _ => AppStatus.neutral,
    };

/// POL6: a client's debt standing as one of the four states, keeping
/// today's words and threshold (Debtors' `isOverdue`: older than the
/// overdue days). Overdue is danger; Current is neutral (the normal case,
/// green before POL6).
AppStatus debtAppStatus({required bool isOverdue}) => isOverdue ? AppStatus.danger : AppStatus.neutral;

/// POL6: a client's STORED status (Active, Inactive) as one of the four
/// states: neutral either way, the word tells them apart (owner answer 1).
AppStatus clientAppStatus(String storedStatus) => AppStatus.neutral;
