import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/ui_settings_provider.dart';
import '../../utils/force_logout.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_text.dart';
import '../../theme/app_dimens.dart';
import '../../theme/theme_context.dart';

/// UI Settings: how the app looks and lays itself out.
///
/// Phase 1: Layout Fixed Mode and System Refresh work. The colour themes other
/// than today's, and Dark Mode, are shown as "Coming soon" - they need every
/// screen to read its colours from one place first.
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
                    _sectionLabel(context, 'COLOUR THEME'),
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
                    _sectionLabel(context, 'APPEARANCE'),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.dark_mode_outlined, color: context.colors.textHint),
                      title: const Text('Dark Mode', style: TextStyle(fontWeight: AppFontWeight.semibold)),
                      subtitle: const Text('Coming soon'),
                      trailing: const Switch(value: false, onChanged: null),
                    ),
                    const SizedBox(height: AppSpacing.s6),
                    _sectionLabel(context, 'LAYOUT'),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: Icon(Icons.view_sidebar_outlined, color: context.colors.primary),
                      title: const Text('Layout Fixed Mode', style: TextStyle(fontWeight: AppFontWeight.semibold)),
                      subtitle: const Text(
                        'Keeps the sidebar open and hides its collapse button on large screens.',
                      ),
                      value: settings.layoutFixed,
                      activeTrackColor: context.colors.primary,
                      onChanged: (value) => settings.setLayoutFixed(value),
                    ),
                    const SizedBox(height: AppSpacing.s6),
                    _sectionLabel(context, 'SYSTEM'),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.refresh, color: context.colors.primary),
                      title: const Text('System Refresh', style: TextStyle(fontWeight: AppFontWeight.semibold)),
                      subtitle: const Text(
                        'Reloads your data and takes you back to the start. You stay signed in.',
                      ),
                      trailing: OutlinedButton(
                        onPressed: () => _confirmRefresh(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: context.colors.primary,
                          side: BorderSide(color: context.colors.primary),
                        ),
                        child: const Text('Refresh'),
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
                const Text('UI Settings', style: TextStyle(fontSize: AppFontSize.f18, fontWeight: AppFontWeight.bold)),
                Text('Saved on this device', style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textMuted)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Close',
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
        title: const Text('Refresh the app?'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: const Text(
            "This reloads your data and takes you back to the start. You stay signed in, "
            "but anything you haven't saved will be lost.",
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: context.colors.primary, foregroundColor: context.colors.onPrimary),
            child: const Text('Refresh'),
          ),
        ],
      ),
    );
    if (go != true) return;
    if (context.mounted) Navigator.of(context).pop(); // close UI Settings first
    await returnToAccountDecision();
  }
}

/// One selectable colour theme. A theme that isn't built yet is shown dimmed,
/// with a "Coming soon" tag, and can't be chosen.
class _ThemeTile extends StatelessWidget {
  final AppColorTheme theme;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeTile({required this.theme, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: theme.available ? 1 : 0.55,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.r12),
          onTap: theme.available ? onTap : null,
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
                  child: Text(theme.name, style: const TextStyle(fontWeight: AppFontWeight.semibold, fontSize: AppFontSize.f14_5)),
                ),
                if (!theme.available)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: AppSpacing.s3),
                    decoration: BoxDecoration(
                      color: context.colors.divider,
                      borderRadius: BorderRadius.circular(AppRadius.r20),
                    ),
                    child: Text('Coming soon', style: TextStyle(fontSize: AppFontSize.f11, color: context.colors.textSoft)),
                  )
                else if (selected)
                  Icon(Icons.check_circle, color: context.colors.primary, size: AppIconSize.i22),
              ],
            ),
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
