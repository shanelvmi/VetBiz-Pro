import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_text.dart';
import '../../theme/theme_context.dart';

// MR1: the parts of the phone More page (more_screen.dart): Find a feature,
// a section of round icons and one icon (UI1: the profile card is gone).
// Measures from MoreMetrics, colours from context.colors roles only.

/// Find a feature: a rounded 48 px field with a search icon and, while it
/// has text, a clear button.
class MoreSearchField extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onChanged;

  const MoreSearchField({super.key, required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(MoreMetrics.searchRadius),
      borderSide: BorderSide(color: colors.border),
    );
    return TextField(
      key: const ValueKey('more-search'),
      controller: controller,
      onChanged: (_) => onChanged(),
      textInputAction: TextInputAction.search,
      style: TextStyle(fontSize: MoreMetrics.searchText, color: colors.textPrimary),
      decoration: InputDecoration(
        hintText: context.l10n.more_findFeature,
        hintStyle: TextStyle(fontSize: MoreMetrics.searchText, color: colors.textSecondary),
        prefixIcon: Icon(Icons.search, size: MoreMetrics.searchIcon, color: colors.textSecondary),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                key: const ValueKey('more-search-clear'),
                tooltip: context.l10n.common_clear,
                icon: Icon(Icons.close, size: MoreMetrics.searchIcon, color: colors.textSecondary),
                onPressed: () {
                  controller.clear();
                  onChanged();
                },
              ),
        filled: true,
        fillColor: colors.surface,
        constraints: const BoxConstraints(minHeight: MoreMetrics.searchHeight),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(borderSide: BorderSide(color: colors.primary)),
      ),
    );
  }
}

/// A section: its title over its round icons, [columns] a row.
class MoreSectionGrid extends StatelessWidget {
  final String title;
  final int columns;
  final List<Widget> cells;

  const MoreSectionGrid({super.key, required this.title, required this.columns, required this.cells});

  @override
  Widget build(BuildContext context) {
    // Taller with larger text, so two lines of label always fit.
    final cellHeight = MediaQuery.textScalerOf(context).scale(MoreMetrics.cellHeight);
    return Padding(
      padding: const EdgeInsets.only(top: MoreMetrics.sectionGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              title,
              style: TextStyle(
                fontSize: MoreMetrics.sectionTitle,
                fontWeight: AppFontWeight.semibold,
                color: context.colors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: MoreMetrics.sectionTitleGap),
          for (var start = 0; start < cells.length; start += columns)
            SizedBox(
              height: cellHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = start; i < start + columns; i++)
                    Expanded(child: i < cells.length ? cells[i] : const SizedBox.shrink()),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class MoreCell extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const MoreCell({super.key, required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.r12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Container(
              width: MoreMetrics.circle,
              height: MoreMetrics.circle,
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: MoreMetrics.circleAlpha),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: MoreMetrics.icon, color: colors.primary),
            ),
            const SizedBox(height: MoreMetrics.labelGap),
            Text(
              label,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: MoreMetrics.label, color: colors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

