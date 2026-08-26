import 'package:flutter/material.dart';

/// The canonical list of payment methods, used consistently everywhere
/// money is recorded as received in this app - sales, services, debt
/// repayments, and other-income transactions. Matches the existing
/// Subscription payment flow's own vocabulary, so there's one shared
/// language for "how was this paid" across the whole app, rather than
/// a different list invented separately in every screen that happens
/// to need one.
const List<String> kPaymentMethods = [
  'Cash',
  'M-Pesa',
  'Tigo Pesa',
  'Airtel Money',
  'Bank Transfer',
];

IconData iconForPaymentMethod(String method) {
  switch (method) {
    case 'Cash':
      return Icons.payments_outlined;
    case 'M-Pesa':
    case 'Tigo Pesa':
    case 'Airtel Money':
      return Icons.phone_android;
    case 'Bank Transfer':
      return Icons.account_balance_outlined;
    default:
      return Icons.payment;
  }
}

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
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[700]),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: kPaymentMethods.map((method) {
            final selected = value == method;
            return ChoiceChip(
              selected: selected,
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    iconForPaymentMethod(method),
                    size: 16,
                    color: selected ? Colors.white : activeColor,
                  ),
                  const SizedBox(width: 6),
                  Text(method),
                ],
              ),
              labelStyle: TextStyle(
                color: selected ? Colors.white : Colors.black87,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
              selectedColor: activeColor,
              backgroundColor: activeColor.withValues(alpha: 0.08),
              side: BorderSide(color: selected ? activeColor : Colors.grey.shade300),
              onSelected: (_) => onChanged(method),
            );
          }).toList(),
        ),
      ],
    );
  }
}
