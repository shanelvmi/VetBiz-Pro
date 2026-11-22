import 'package:flutter/material.dart';

import '../../theme/polish_metrics.dart';
import '../../theme/theme_context.dart';
import 'section_label.dart';

/// UX6: the one card template of the PC/tablet Settings pages (Trash, Export
/// Data, Manage Account): an optional SectionLabel over a flat surface with a
/// hairline border (no shadow), the page's full width, the polish padding.
/// [padding] null: the content (rows, a table) reaches the card's edges.
class PageCard extends StatelessWidget {
  final String? title;
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const PageCard({super.key, this.title, required this.child, this.padding = const EdgeInsets.all(PolishMetrics.cardPadding)});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = BorderRadius.circular(PolishMetrics.cardRadius);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null)
          SectionLabel(
            title!,
            padding: const EdgeInsets.only(top: PolishMetrics.sectionLabelPaddingTop, bottom: PolishMetrics.sectionLabelPaddingBottom),
          ),
        DecoratedBox(
          key: const ValueKey('pageCard'),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: radius,
            border: Border.all(color: colors.border, width: PolishMetrics.hairline),
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: Material(
              type: MaterialType.transparency,
              child: padding == null ? child : Padding(padding: padding!, child: child),
            ),
          ),
        ),
      ],
    );
  }
}

/// UX6: the body of a page made of [PageCard]s: the full content width (no
/// narrow centred column), the page padding, scrolling as one.
class PageCardList extends StatelessWidget {
  final List<Widget> children;

  const PageCardList({super.key, required this.children});

  @override
  Widget build(BuildContext context) => ListView(
        key: const ValueKey('pageCardList'),
        padding: const EdgeInsets.fromLTRB(PolishMetrics.pagePadding, 0, PolishMetrics.pagePadding, PolishMetrics.pagePadding),
        children: children,
      );
}
