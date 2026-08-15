import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/client_provider.dart';
import '../../providers/facility_provider.dart';

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
  const primaryDeepGreen = Color(0xFF2F5D62);
  const warmAmber = Color(0xFFFFB200);

  bool isRunning = false;
  String? resultMessage;

  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        title: const Text('Rebuild Client Search Index'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (resultMessage == null) ...[
              const Text(
                'This makes clients added before search was available '
                'show up correctly when searched by name. It only needs '
                'to be run once - existing, unaffected clients are left '
                'alone.',
                style: TextStyle(fontSize: 13),
              ),
            ] else
              Text(resultMessage!, style: const TextStyle(fontSize: 13)),
            if (isRunning) ...[
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator(color: primaryDeepGreen)),
            ],
          ],
        ),
        actions: [
          if (resultMessage == null)
            TextButton(
              onPressed: isRunning ? null : () => Navigator.pop(dialogContext),
              style: ButtonStyle(
                foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                  if (states.contains(WidgetState.hovered)) return warmAmber;
                  return primaryDeepGreen;
                }),
              ),
              child: const Text('Cancel'),
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
                          resultMessage = 'No facility selected.';
                        });
                        return;
                      }
                      try {
                        final updated = await Provider.of<ClientProvider>(context, listen: false)
                            .rebuildSearchIndex(facilityId);
                        setDialogState(() {
                          isRunning = false;
                          resultMessage = updated == 0
                              ? 'Nothing to update - every client is already searchable.'
                              : 'Done. $updated client${updated == 1 ? '' : 's'} updated and now searchable.';
                        });
                      } catch (e) {
                        setDialogState(() {
                          isRunning = false;
                          resultMessage = 'Could not complete: $e';
                        });
                      }
                    },
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                  if (states.contains(WidgetState.hovered)) return warmAmber;
                  return primaryDeepGreen;
                }),
                foregroundColor: WidgetStateProperty.all(Colors.white),
              ),
              child: const Text('Run Now'),
            ),
          if (resultMessage != null)
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext),
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.all(primaryDeepGreen),
                foregroundColor: WidgetStateProperty.all(Colors.white),
              ),
              child: const Text('Done'),
            ),
        ],
      ),
    ),
  );
}
