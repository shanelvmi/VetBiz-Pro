import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/ui_settings_provider.dart';
import '../../theme/app_palette.dart';
import '../../utils/force_logout.dart';

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
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
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
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel('COLOUR THEME'),
                    const SizedBox(height: 8),
                    for (final theme in AppColorTheme.all) ...[
                      _ThemeTile(
                        theme: theme,
                        selected: settings.colorTheme.id == theme.id,
                        onTap: () => settings.setColorTheme(theme.id),
                      ),
                      const SizedBox(height: 8),
                    ],
                    const SizedBox(height: 10),
                    _sectionLabel('APPEARANCE'),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.dark_mode_outlined, color: Colors.grey.shade500),
                      title: const Text('Dark Mode', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text('Coming soon'),
                      trailing: const Switch(value: false, onChanged: null),
                    ),
                    const SizedBox(height: 6),
                    _sectionLabel('LAYOUT'),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(Icons.view_sidebar_outlined, color: AppPalette.primary),
                      title: const Text('Layout Fixed Mode', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text(
                        'Keeps the sidebar open and hides its collapse button on large screens.',
                      ),
                      value: settings.layoutFixed,
                      activeTrackColor: AppPalette.primary,
                      onChanged: (value) => settings.setLayoutFixed(value),
                    ),
                    const SizedBox(height: 6),
                    _sectionLabel('SYSTEM'),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.refresh, color: AppPalette.primary),
                      title: const Text('System Refresh', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text(
                        'Reloads your data and takes you back to the start. You stay signed in.',
                      ),
                      trailing: OutlinedButton(
                        onPressed: () => _confirmRefresh(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppPalette.primary,
                          side: const BorderSide(color: AppPalette.primary),
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
      padding: const EdgeInsets.fromLTRB(20, 16, 8, 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppPalette.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.tune, color: AppPalette.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('UI Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text('Saved on this device', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
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

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: Colors.grey.shade600,
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
            style: ElevatedButton.styleFrom(backgroundColor: AppPalette.primary, foregroundColor: Colors.white),
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
          borderRadius: BorderRadius.circular(12),
          onTap: theme.available ? onTap : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: selected ? AppPalette.primary.withValues(alpha: 0.05) : null,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? AppPalette.primary : Colors.grey.shade300,
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
                      Positioned(left: 0, top: 0, child: _dot(theme.primary, 28)),
                      Positioned(left: 18, top: 5, child: _dot(theme.accent, 20)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(theme.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
                ),
                if (!theme.available)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('Coming soon', style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                  )
                else if (selected)
                  const Icon(Icons.check_circle, color: AppPalette.primary, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dot(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
    );
  }
}
