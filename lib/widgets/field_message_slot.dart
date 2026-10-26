import 'package:flutter/material.dart';

/// The line under a form field (G5, the register wizard): its helper, or
/// its error in the same place, in a space that is always kept. The space
/// is as tall as the longest of [reserve] (every message the field can
/// show), laid out at the field's width in the current language and text
/// size, at most [maxLines] lines; with nothing to say it is still one
/// line. So pressing Continue on an empty step changes the words, never the
/// height of the card.
///
/// The kept space is drawn by invisible RichTexts (not Texts, so finders by
/// text see only [message]) and left out of semantics.
class FieldMessageSlot extends StatelessWidget {
  const FieldMessageSlot({super.key, this.message, this.reserve = const [], required this.style, this.maxLines = 2});

  /// What shows now: the helper, the error, or nothing.
  final String? message;

  /// The messages the field can show; the tallest sets the height.
  final List<String> reserve;
  final TextStyle style;

  /// Null: as many lines as the longest needs.
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final defaults = DefaultTextStyle.of(context);
    // Not the inherited default: the decorator gives its error a different
    // line height from its helper, which made the line 2 px shorter with an
    // error. The theme's small text (not inheriting) is the same for both.
    final lineStyle = (Theme.of(context).textTheme.bodySmall ?? const TextStyle(inherit: false)).merge(style);
    return Stack(
      children: [
        // One space keeps a line even when every message is empty.
        for (final text in [' ', ...reserve, if (message != null) message!])
          ExcludeSemantics(
            child: Opacity(
              opacity: 0,
              child: RichText(
                text: TextSpan(text: text, style: lineStyle),
                maxLines: maxLines,
                textScaler: MediaQuery.textScalerOf(context),
                textHeightBehavior: defaults.textHeightBehavior,
              ),
            ),
          ),
        if (message != null) Text(message!, style: lineStyle, maxLines: maxLines, overflow: TextOverflow.ellipsis),
      ],
    );
  }
}
