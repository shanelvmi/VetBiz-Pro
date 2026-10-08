import 'package:flutter/material.dart';

import '../config/payment_methods.dart';
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
      PaymentMethod.mPesa || PaymentMethod.mixxByYas || PaymentMethod.haloPesa || PaymentMethod.airtelMoney =>
        Icons.phone_android,
      PaymentMethod.bankTransfer => Icons.account_balance_outlined,
      // Tigo Pesa (only on old records) and any unknown key keep the generic
      // icon they always had. Giving Tigo Pesa the phone icon is listed in
      // design-open-questions.md.
      PaymentMethod.tigoPesa || null => Icons.payment,
    };

/// A row of selectable chips, each carrying its own icon - one tap to
/// choose, rather than opening a dropdown first to see the options.
/// Wraps onto a second line on a narrow screen instead of overflowing.
class PaymentMethodSelector extends StatelessWidget {
  final String? value;
  final ValueChanged<String> onChanged;
  final Color activeColor;
  final String label;

  const PaymentMethodSelector({
    super.key,
    required this.value,
    required this.onChanged,
    required this.activeColor,
    this.label = 'Payment Method',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
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
                  Text(method),
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
