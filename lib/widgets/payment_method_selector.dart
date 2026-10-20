import 'package:flutter/material.dart';

import '../config/payment_methods.dart';
import '../l10n/l10n.dart';
import '../theme/app_dimens.dart';
import '../theme/app_text.dart';
import '../theme/theme_context.dart';

/// The canonical list of payment methods, used consistently everywhere
/// money is recorded as received in this app - sales, services, debt
/// repayments, and other-income transactions. Matches the existing
/// Subscription payment flow's own vocabulary, so there's one shared
/// language for "how was this paid" across the whole app, rather than
/// a different list invented separately in every screen that happens
/// to need one.
/// The stored keys, in the order the chips show them (PaymentMethod.recordable).
final List<String> kPaymentMethods = [for (final m in PaymentMethod.recordable) m.key];

IconData iconForPaymentMethod(String method) => switch (PaymentMethod.fromKey(method)) {
      PaymentMethod.cash => Icons.payments_outlined,
      // Tigo Pesa (only on old records) is Mixx by Yas's old name, so it gets
      // the same phone icon (R3, D5).
      PaymentMethod.mPesa || PaymentMethod.mixxByYas || PaymentMethod.tigoPesa || PaymentMethod.haloPesa || PaymentMethod.airtelMoney =>
        Icons.phone_android,
      PaymentMethod.bankTransfer => Icons.account_balance_outlined,
      // Any unknown key keeps the generic icon.
      null => Icons.payment,
    };

/// A row of selectable chips, each carrying its own icon - one tap to
/// choose, rather than opening a dropdown first to see the options.
/// Wraps onto a second line on a narrow screen instead of overflowing.
class PaymentMethodSelector extends StatelessWidget {
  final String? value;
  final ValueChanged<String> onChanged;
  final Color activeColor;
  /// Null: "Payment Method" in the current language.
  final String? label;

  const PaymentMethodSelector({
    super.key,
    required this.value,
    required this.onChanged,
    required this.activeColor,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label ?? context.l10n.payments_method,
          style: TextStyle(fontSize: AppFontSize.f13, fontWeight: AppFontWeight.semibold, color: context.colors.textSoft),
        ),
        const SizedBox(height: AppSpacing.s8),
        Wrap(
          spacing: AppSpacing.s8,
          runSpacing: AppSpacing.s8,
          children: kPaymentMethods.map((method) {
            final selected = value == method;
            return ChoiceChip(
              selected: selected,
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    iconForPaymentMethod(method),
                    size: AppIconSize.i16,
                    color: selected ? context.colors.onPrimary : activeColor,
                  ),
                  const SizedBox(width: AppSpacing.s6),
                  // Shows the label; the chip selects the stored method.
                  Text(context.l10n.paymentMethodLabel(method)),
                ],
              ),
              labelStyle: TextStyle(
                color: selected ? context.colors.onPrimary : context.colors.textPrimary,
                fontWeight: selected ? AppFontWeight.semibold : AppFontWeight.regular,
              ),
              selectedColor: activeColor,
              backgroundColor: activeColor.withValues(alpha: AppAlpha.a10),
              side: BorderSide(color: selected ? activeColor : context.colors.border),
              onSelected: (_) => onChanged(method),
            );
          }).toList(),
        ),
      ],
    );
  }
}
