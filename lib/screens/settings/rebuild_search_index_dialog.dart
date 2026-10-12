import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/client_provider.dart';
import '../../providers/facility_provider.dart';
import '../../theme/app_text.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_dimens.dart';
import '../../theme/theme_context.dart';
import '../../ui/feedback/friendly_error.dart';

/// One-time, admin-triggered action - not something that runs
/// automatically, since that would mean re-downloading the entire
/// client collection on every app load, exactly what the paginated
/// client list is meant to avoid.
///
/// Why this exists: clients created before this update was applied
/// only have the old data on their Firestore document - they're
/// missing the `nameLower` field the new search feature depends on.
/// A Firestore query can't match a field that was never written, so
/// without running this once, any client who's never been individually
/// opened and re-saved since this update simply won't turn up in
/// search results, even though they still show up fine when browsing
/// or filtering by type.
///
/// Wire this in from Settings with something like:
///   ListTile(
///     leading: const Icon(Icons.search),
///     title: const Text('Rebuild Client Search Index'),
///     subtitle: const Text('Needed once, for clients added before search was available'),
///     onTap: () => showRebuildSearchIndexDialog(context),
///   ),
Future<void> showRebuildSearchIndexDialog(BuildContext context) async {

  bool isRunning = false;
  String? resultMessage;

  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        title: Text(dialogContext.l10n.searchIndex_title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (resultMessage == null) ...[
              Text(
                context.l10n.searchIndex_body,
                style: const TextStyle(fontSize: AppFontSize.f13),
              ),
            ] else
              Text(resultMessage!, style: const TextStyle(fontSize: AppFontSize.f13)),
            if (isRunning) ...[
              const SizedBox(height: AppSpacing.s16),
              Center(child: CircularProgressIndicator(color: dialogContext.colors.primary)),
            ],
          ],
        ),
        actions: [
          if (resultMessage == null)
            TextButton(
              onPressed: isRunning ? null : () => Navigator.pop(dialogContext),
              style: ButtonStyle(
                foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                  if (states.contains(WidgetState.hovered)) return dialogContext.colors.accent;
                  return dialogContext.colors.primary;
                }),
              ),
              child: Text(context.l10n.common_cancel),
            ),
          if (resultMessage == null)
            ElevatedButton(
              onPressed: isRunning
                  ? null
                  : () async {
                      setDialogState(() => isRunning = true);
                      final facilityId =
                          Provider.of<FacilityProvider>(context, listen: false).selectedFacilityId;
                      if (facilityId == null) {
                        setDialogState(() {
                          isRunning = false;
                          resultMessage = L10n.current.common_noFacilityDot;
                        });
                        return;
                      }
                      try {
                        final updated = await Provider.of<ClientProvider>(context, listen: false)
                            .rebuildSearchIndex(facilityId);
                        setDialogState(() {
                          isRunning = false;
                          resultMessage = updated == 0
                              ? L10n.current.searchIndex_nothing
                              : L10n.current.searchIndex_done(updated);
                        });
                      } catch (e) {
                        setDialogState(() {
                          isRunning = false;
                          resultMessage = L10n.current.searchIndex_failed(FriendlyError.messageFor(e));
                        });
                      }
                    },
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                  if (states.contains(WidgetState.hovered)) return dialogContext.colors.accent;
                  return dialogContext.colors.primary;
                }),
                foregroundColor: WidgetStateProperty.all(dialogContext.colors.onPrimary),
              ),
              child: Text(context.l10n.searchIndex_run),
            ),
          if (resultMessage != null)
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext),
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.all(dialogContext.colors.primary),
                foregroundColor: WidgetStateProperty.all(dialogContext.colors.onPrimary),
              ),
              child: Text(context.l10n.common_done),
            ),
        ],
      ),
    ),
  );
}
