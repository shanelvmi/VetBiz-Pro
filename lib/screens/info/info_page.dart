import 'package:flutter/material.dart';

import '../../theme/app_dimens.dart';
import '../../theme/app_text.dart';
import '../../theme/theme_context.dart';

/// The frame of the About, How to use it and FAQs pages (G4): a top bar
/// with the back arrow, and one readable column, centred and never wider
/// than [InfoPageMetrics.maxWidth], that scrolls. They open from the
/// sign-in footer, so nothing here needs a signed-in user.
class InfoPage extends StatelessWidget {
  const InfoPage({super.key, required this.title, required this.children});

  /// For tests: the readable column.
  static const columnKey = ValueKey<String>('info-page-column');

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      // G5: the title centred on every platform, here once so the three
      // pages agree. The toolbar keeps it clear of the back arrow; a long
      // one ends in an ellipsis.
      appBar: AppBar(centerTitle: true, title: Text(title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(InfoPageMetrics.padding),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: InfoPageMetrics.maxWidth),
            child: Column(
              key: columnKey,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}

/// A paragraph of an info page.
class InfoParagraph extends StatelessWidget {
  const InfoParagraph(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: InfoPageMetrics.itemGap),
        child: Text(text, style: InfoPageText.body(context)),
      );
}

/// A section heading of an info page.
class InfoHeading extends StatelessWidget {
  const InfoHeading(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: InfoPageMetrics.sectionGap, bottom: InfoPageMetrics.itemGap),
        child: Semantics(
          header: true,
          child: Text(text, style: InfoPageText.heading(context)),
        ),
      );
}

/// The info pages' text styles, from roles and named sizes only.
class InfoPageText {
  InfoPageText._();

  static TextStyle body(BuildContext context) =>
      TextStyle(fontSize: InfoPageFontSize.body, height: InfoPageMetrics.lineHeight, color: context.colors.textPrimary);

  static TextStyle question(BuildContext context) =>
      TextStyle(fontSize: InfoPageFontSize.body, fontWeight: AppFontWeight.semibold, color: context.colors.textPrimary);

  static TextStyle heading(BuildContext context) =>
      TextStyle(fontSize: InfoPageFontSize.heading, fontWeight: AppFontWeight.bold, color: context.colors.textStrong);
}
