import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/ui_settings_provider.dart';
import '../../utils/force_logout.dart';
import '../../theme/app_palette.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_text.dart';
import '../../theme/app_dimens.dart';
import '../../theme/theme_context.dart';

/// UI Settings: how the app looks and lays itself out.
///
/// The four colour themes (T1), Layout Fixed Mode and System Refresh work.
/// Dark Mode is shown as "Coming soon" (RUNBOOK2 block D).
Future<void> showUiSettingsDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _UiSettingsDialog(),
  );
}

class _UiSettingsDialog extends StatelessWidget {
  const _UiSettingsDialog();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<UiSettingsProvider>();
    final maxHeight = MediaQuery.of(context).size.height * 0.85;

    return Dialog(
      backgroundColor: context.colors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.r16)),
      // A dialog with no width limit stretches across a whole desktop screen.
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 460, maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.s20, AppSpacing.s16, AppSpacing.s20, AppSpacing.s20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel(context, context.l10n.uiSettings_colourTheme),
                    const SizedBox(height: AppSpacing.s8),
                    for (final theme in AppColorTheme.all) ...[
                      _ThemeTile(
                        theme: theme,
                        selected: settings.colorTheme.id == theme.id,
                        onTap: () => settings.setColorTheme(theme.id),
                      ),
                      const SizedBox(height: AppSpacing.s8),
                    ],
                    const SizedBox(height: AppSpacing.s10),
                    _sectionLabel(context, context.l10n.uiSettings_appearance),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.dark_mode_outlined, color: context.colors.textHint),
                      title: Text(context.l10n.uiSettings_darkMode, style: const TextStyle(fontWeight: AppFontWeight.semibold)),
                      subtitle: Text(context.l10n.uiSettings_comingSoon),
                      trailing: const Switch(value: false, onChanged: null),
                    ),
                    const SizedBox(height: AppSpacing.s6),
                    _sectionLabel(context, context.l10n.uiSettings_layout),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: Icon(Icons.view_sidebar_outlined, color: context.colors.primary),
                      title: Text(context.l10n.uiSettings_layoutFixed, style: const TextStyle(fontWeight: AppFontWeight.semibold)),
                      subtitle: Text(
                        context.l10n.uiSettings_layoutFixedHint,
                      ),
                      value: settings.layoutFixed,
                      activeTrackColor: context.colors.primary,
                      onChanged: (value) => settings.setLayoutFixed(value),
                    ),
                    const SizedBox(height: AppSpacing.s6),
                    _sectionLabel(context, context.l10n.uiSettings_system),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.refresh, color: context.colors.primary),
                      title: Text(context.l10n.uiSettings_systemRefresh, style: const TextStyle(fontWeight: AppFontWeight.semibold)),
                      subtitle: Text(
                        context.l10n.uiSettings_systemRefreshHint,
                      ),
                      trailing: OutlinedButton(
                        onPressed: () => _confirmRefresh(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: context.colors.primary,
                          side: BorderSide(color: context.colors.primary),
                        ),
                        child: Text(context.l10n.common_refresh),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.s20, AppSpacing.s16, AppSpacing.s8, AppSpacing.s12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.s8),
            decoration: BoxDecoration(
              color: context.colors.primary.withValues(alpha: AppAlpha.a10),
              borderRadius: BorderRadius.circular(AppRadius.r10),
            ),
            child: Icon(Icons.tune, color: context.colors.primary),
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.l10n.uiSettings_title, style: const TextStyle(fontSize: AppFontSize.f18, fontWeight: AppFontWeight.bold)),
                Text(context.l10n.uiSettings_savedOnDevice, style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textMuted)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: context.l10n.common_close,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s2),
      child: Text(
        text,
        style: TextStyle(
          fontSize: AppFontSize.f11_5,
          fontWeight: AppFontWeight.bold,
          letterSpacing: 0.8,
          color: context.colors.textMuted,
        ),
      ),
    );
  }

  // Refreshing takes you back to the start and drops anything unsaved, so it
  // asks first rather than firing from a stray tap.
  Future<void> _confirmRefresh(BuildContext context) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.r16)),
        title: Text(context.l10n.uiSettings_refreshTitle),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Text(
            context.l10n.uiSettings_refreshBody,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.l10n.common_cancel)),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: context.colors.primary, foregroundColor: context.colors.onPrimary),
            child: Text(context.l10n.common_refresh),
          ),
        ],
      ),
    );
    if (go != true) return;
    if (context.mounted) Navigator.of(context).pop(); // close UI Settings first
    await returnToAccountDecision();
  }
}

/// One selectable colour theme: its two swatches, its name, and a tick when
/// it is the one in use.
// A theme's name as shown, through colorThemeLabel; AppColorTheme.name stays
// the English name, shown as is for a theme added later without a label.
String _themeName(BuildContext context, AppColorTheme theme) {
  final label = context.l10n.colorThemeLabel(theme.id);
  return label == theme.id ? theme.name : label;
}

class _ThemeTile extends StatelessWidget {
  final AppColorTheme theme;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeTile({required this.theme, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.r12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s14, vertical: AppSpacing.s12),
          decoration: BoxDecoration(
            color: selected ? context.colors.primary.withValues(alpha: AppAlpha.a05) : null,
            borderRadius: BorderRadius.circular(AppRadius.r12),
            border: Border.all(
              color: selected ? context.colors.primary : context.colors.border,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 44,
                height: 28,
                child: Stack(
                  children: [
                    Positioned(left: 0, top: 0, child: _dot(context, theme.primary, 28)),
                    Positioned(left: 18, top: 5, child: _dot(context, theme.accent, 20)),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Text(_themeName(context, theme), style: const TextStyle(fontWeight: AppFontWeight.semibold, fontSize: AppFontSize.f14_5)),
              ),
              if (selected)
                Icon(Icons.check_circle, color: context.colors.primary, size: AppIconSize.i22),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dot(BuildContext context, Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: context.colors.surface, width: 2),
      ),
    );
  }
}
