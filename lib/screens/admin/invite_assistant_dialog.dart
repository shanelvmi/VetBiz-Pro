import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../services/auth_service.dart';
import '../../services/invite_code_service.dart';

/// Generates a short-lived, single-use code for inviting a new
/// Assistant to join this facility - shown to the Admin to share
/// verbally or over WhatsApp with the specific person they're hiring.
///
/// Wire this in from Manage Assistants with something like:
///   IconButton(
///     icon: const Icon(Icons.person_add_alt),
///     tooltip: 'Invite Assistant',
///     onPressed: () => showInviteAssistantDialog(context, facilityId),
///   ),
Future<void> showInviteAssistantDialog(BuildContext context, String facilityId) async {
  const primaryDeepGreen = Color(0xFF2F5D62);
  const warmAmber = Color(0xFFFFB200);

  final inviteService = InviteCodeService();
  final authService = Provider.of<AuthService>(context, listen: false);

  bool isLoading = true;
  String? activeCode;
  DateTime? activeExpiresAt;
  String? errorMessage;

  await showDialog(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) {
        Future<void> loadActiveInvite() async {
          setDialogState(() => isLoading = true);
          try {
            final active = await inviteService.getActiveInvite(facilityId);
            setDialogState(() {
              activeCode = active?['code'] as String?;
              activeExpiresAt = active?['expiresAt'] as DateTime?;
              isLoading = false;
            });
          } catch (e) {
            setDialogState(() {
              errorMessage = 'Could not check for an existing invite: $e';
              isLoading = false;
            });
          }
        }

        // Kick off the initial check exactly once.
        if (isLoading && activeCode == null && errorMessage == null) {
          // Deferred so setDialogState isn't called during build.
          WidgetsBinding.instance.addPostFrameCallback((_) => loadActiveInvite());
        }

        Future<void> generateNew() async {
          setDialogState(() => isLoading = true);
          try {
            final user = authService.getCurrentUser();
            final code = await inviteService.generateInviteCode(
              facilityId: facilityId,
              createdByUserId: user?.uid ?? '',
            );
            setDialogState(() {
              activeCode = code;
              activeExpiresAt = DateTime.now().add(InviteCodeService.validityDuration);
              isLoading = false;
              errorMessage = null;
            });
          } catch (e) {
            setDialogState(() {
              errorMessage = 'Could not generate an invite: $e';
              isLoading = false;
            });
          }
        }

        Future<void> revoke() async {
          setDialogState(() => isLoading = true);
          try {
            await inviteService.revokeInviteCode(facilityId);
            setDialogState(() {
              activeCode = null;
              activeExpiresAt = null;
              isLoading = false;
            });
          } catch (e) {
            setDialogState(() {
              errorMessage = 'Could not revoke: $e';
              isLoading = false;
            });
          }
        }

        final formatted = activeCode != null ? inviteService.formatForDisplay(activeCode!) : null;

        return AlertDialog(
          title: const Text('Invite Assistant'),
          content: SizedBox(
            width: 320,
            child: isLoading
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator(color: primaryDeepGreen)),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (errorMessage != null) ...[
                        Text(errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                        const SizedBox(height: 12),
                      ],
                      if (formatted != null) ...[
                        const Text(
                          'Share this code with the person you\'re hiring - '
                          'they\'ll enter it when registering as an Assistant.',
                          style: TextStyle(fontSize: 13),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: primaryDeepGreen.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: primaryDeepGreen.withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            children: [
                              Text(
                                formatted,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 3,
                                  color: primaryDeepGreen,
                                ),
                              ),
                              const SizedBox(height: 4),
                              if (activeExpiresAt != null)
                                Text(
                                  'Expires ${DateFormat('dd MMM, HH:mm').format(activeExpiresAt!)}',
                                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: formatted));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Copied to clipboard')),
                                  );
                                },
                                icon: const Icon(Icons.copy, size: 16),
                                label: const Text('Copy'),
                                style: OutlinedButton.styleFrom(foregroundColor: primaryDeepGreen),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: revoke,
                                icon: const Icon(Icons.cancel_outlined, size: 16),
                                label: const Text('Revoke'),
                                style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: TextButton(
                            onPressed: generateNew,
                            style: TextButton.styleFrom(foregroundColor: warmAmber),
                            child: const Text('Generate a new one instead'),
                          ),
                        ),
                      ] else ...[
                        const Text(
                          'Generate a one-time code for the person you\'re '
                          'hiring - it works for 48 hours or until used once, '
                          'whichever comes first.',
                          style: TextStyle(fontSize: 13),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: generateNew,
                            style: ButtonStyle(
                              backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                                if (states.contains(WidgetState.hovered)) return warmAmber;
                                return primaryDeepGreen;
                              }),
                              foregroundColor: WidgetStateProperty.all(Colors.white),
                              padding: WidgetStateProperty.all(const EdgeInsets.symmetric(vertical: 12)),
                            ),
                            child: const Text('Generate Invite Code'),
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              style: ButtonStyle(
                foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                  if (states.contains(WidgetState.hovered)) return warmAmber;
                  return primaryDeepGreen;
                }),
              ),
              child: const Text('Close'),
            ),
          ],
        );
      },
    ),
  );
}
