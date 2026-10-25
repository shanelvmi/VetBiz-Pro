import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../theme/app_dimens.dart';
import '../../theme/app_text.dart';
import '../../theme/theme_context.dart';

/// A tappable name inside [WizardConsentRow]'s sentence.
class WizardLink {
  final String label;
  final VoidCallback onTap;

  const WizardLink({required this.label, required this.onTap});
}

/// The owner's required "I agree" checkbox (RW1 answer 1): a 48 px
/// checkbox, the sentence with its [links] tappable where their labels
/// appear in [text] (one ARB sentence with the names as placeholders, so a
/// translation can move them), and [errorText] under it when the person
/// pressed Create without ticking. Unticked unless the parent says so.
class WizardConsentRow extends StatefulWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final String text;
  final List<WizardLink> links;
  final String? errorText;

  const WizardConsentRow({
    super.key,
    this.value = false,
    required this.onChanged,
    required this.text,
    required this.links,
    this.errorText,
  });

  @override
  State<WizardConsentRow> createState() => _WizardConsentRowState();
}

class _WizardConsentRowState extends State<WizardConsentRow> {
  final List<TapGestureRecognizer> _recognizers = [];

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  // The sentence cut around each link's label, in order. A label missing
  // from the text (a translation that dropped it) leaves plain text.
  List<InlineSpan> _spans(TextStyle linkStyle) {
    _disposeRecognizers();
    final spans = <InlineSpan>[];
    var rest = widget.text;
    for (final link in widget.links) {
      final at = rest.indexOf(link.label);
      if (at < 0) continue;
      if (at > 0) spans.add(TextSpan(text: rest.substring(0, at)));
      final recognizer = TapGestureRecognizer()..onTap = link.onTap;
      _recognizers.add(recognizer);
      spans.add(TextSpan(text: link.label, style: linkStyle, recognizer: recognizer));
      rest = rest.substring(at + link.label.length);
    }
    if (rest.isNotEmpty) spans.add(TextSpan(text: rest));
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hasError = widget.errorText != null;
    final linkStyle = TextStyle(
      color: colors.primary,
      fontWeight: AppFontWeight.semibold,
      decoration: TextDecoration.underline,
      decorationColor: colors.primary,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            SizedBox(
              width: WizardMetrics.consentTapTarget,
              height: WizardMetrics.consentTapTarget,
              child: Checkbox(
                value: widget.value,
                onChanged: (v) => widget.onChanged(v ?? false),
                semanticLabel: widget.text,
                activeColor: colors.primary,
                checkColor: colors.onPrimary,
                side: BorderSide(color: hasError ? colors.danger : colors.textMuted),
              ),
            ),
            const SizedBox(width: WizardMetrics.consentGap),
            Expanded(
              child: Text.rich(
                TextSpan(children: _spans(linkStyle)),
                style: TextStyle(fontSize: WizardFontSize.consent, color: colors.textPrimary),
              ),
            ),
          ],
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: WizardMetrics.consentTapTarget + WizardMetrics.consentGap,
              top: WizardMetrics.consentGap,
            ),
            child: Semantics(
              liveRegion: true,
              child: Text(
                widget.errorText!,
                style: TextStyle(fontSize: WizardFontSize.consentError, color: colors.danger),
              ),
            ),
          ),
      ],
    );
  }
}
