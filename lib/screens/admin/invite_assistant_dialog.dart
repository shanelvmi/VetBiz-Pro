import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../services/invite_code_service.dart';
import '../../services/membership_service.dart';
import '../../config/app_date_format.dart';
import '../../theme/app_text.dart';
import '../../theme/app_dimens.dart';
import '../../theme/theme_context.dart';
import '../../ui/feedback/friendly_error.dart';
import '../../ui/feedback/app_feedback.dart';

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

  final inviteService = InviteCodeService();
  final authService = Provider.of<AuthService>(context, listen: false);

  bool isLoading = true;
  // The first check for an existing invite must run ONCE. It was guarded by
  // "still loading and no code yet", which is ALSO true the moment someone taps
  // Generate - so tapping it started a second check, which came back empty and
  // switched the dialog back to the Generate button while the first request was
  // still running. Each further tap made another code (the earlier unused one
  // is replaced each time, so they all appeared at once when the server caught
  // up).
  bool initialCheckStarted = false;
  // One request at a time, whatever the buttons show.
  bool busy = false;
  String loadingMessage = 'Checking for an existing invite...';
  String? activeCode;
  DateTime? activeExpiresAt;
  String? errorMessage;

  await showDialog(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) {
        Future<void> loadActiveInvite() async {
          setDialogState(() {
            isLoading = true;
            loadingMessage = 'Checking for an existing invite...';
          });
          try {
            final active = await inviteService.getActiveInvite(facilityId);
            if (!dialogContext.mounted) return;
            setDialogState(() {
              activeCode = active?['code'] as String?;
              activeExpiresAt = active?['expiresAt'] as DateTime?;
              isLoading = false;
            });
          } catch (e) {
            if (!dialogContext.mounted) return;
            setDialogState(() {
              errorMessage = 'Could not check for an existing invite: ${FriendlyError.messageFor(e)}';
              isLoading = false;
            });
          }
        }

        // Kick off the initial check exactly once.
        if (!initialCheckStarted) {
          initialCheckStarted = true;
          // Deferred so setDialogState isn't called during build.
          WidgetsBinding.instance.addPostFrameCallback((_) => loadActiveInvite());
        }

        Future<void> generateNew() async {
          if (busy) return;
          busy = true;
          setDialogState(() {
            isLoading = true;
            loadingMessage = 'Generating your invite code...';
          });
          try {
            final user = authService.getCurrentUser();
            final code = await inviteService.generateInviteCode(
              facilityId: facilityId,
              createdByUserId: user?.uid ?? '',
            );
            if (!dialogContext.mounted) return;
            setDialogState(() {
              activeCode = code;
              activeExpiresAt = DateTime.now().add(InviteCodeService.validityDuration);
              isLoading = false;
              errorMessage = null;
            });
          } catch (e) {
            if (!dialogContext.mounted) return;
            setDialogState(() {
              errorMessage = 'Could not generate an invite: ${MembershipService.errorMessage(e)}';
              isLoading = false;
            });
          } finally {
            busy = false;
          }
        }

        Future<void> revoke() async {
          if (busy) return;
          busy = true;
          setDialogState(() {
            isLoading = true;
            loadingMessage = 'Revoking the code...';
          });
          try {
            await inviteService.revokeInviteCode(facilityId);
            if (!dialogContext.mounted) return;
            setDialogState(() {
              activeCode = null;
              activeExpiresAt = null;
              isLoading = false;
            });
          } catch (e) {
            if (!dialogContext.mounted) return;
            setDialogState(() {
              errorMessage = 'Could not revoke: ${FriendlyError.messageFor(e)}';
              isLoading = false;
            });
          } finally {
            busy = false;
          }
        }

        final formatted = activeCode != null ? inviteService.formatForDisplay(activeCode!) : null;

        return AlertDialog(
          title: const Text('Invite Assistant'),
          // A fixed width keeps the dialog's horizontal size stable
          // across states; height now follows the actual content
          // (mainAxisSize.min on the Column below) instead of a single
          // shared fixed value sized for the tallest state, which left
          // visible blank space in the shorter ones.
          content: SizedBox(
            width: 320,
            child: isLoading
                ? SizedBox(
                    height: 120,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: dialogContext.colors.primary),
                        const SizedBox(height: AppSpacing.s14),
                        // Says what it's doing - generating a code can take a
                        // few seconds, and a bare spinner looks like nothing is.
                        Text(loadingMessage, style: TextStyle(fontSize: AppFontSize.f13, color: dialogContext.colors.textSoft)),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (errorMessage != null) ...[
                        Text(errorMessage!, style: TextStyle(color: dialogContext.colors.dangerAccent, fontSize: AppFontSize.f13)),
                        const SizedBox(height: AppSpacing.s12),
                      ],
                      if (formatted != null) ...[
                        const Text(
                          'Share this code with the person you\'re hiring - '
                          'they\'ll enter it when registering as an Assistant.',
                          style: TextStyle(fontSize: AppFontSize.f13),
                        ),
                        const SizedBox(height: AppSpacing.s16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.s16),
                          decoration: BoxDecoration(
                            color: dialogContext.colors.primary.withValues(alpha: AppAlpha.a10),
                            borderRadius: BorderRadius.circular(AppRadius.r10),
                            border: Border.all(color: dialogContext.colors.primary.withValues(alpha: AppAlpha.a30)),
                          ),
                          child: Column(
                            children: [
                              Text(
                                formatted,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: AppFontSize.f28,
                                  fontWeight: AppFontWeight.bold,
                                  letterSpacing: 3,
                                  color: dialogContext.colors.primary,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.s4),
                              if (activeExpiresAt != null)
                                Text(
                                  'Expires ${AppDateFormat.dateDayTime24.format(activeExpiresAt!)}',
                                  style: TextStyle(fontSize: AppFontSize.f11, color: dialogContext.colors.textMuted),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: formatted));
                                  AppFeedback.success('Copied to clipboard');
                                },
                                icon: const Icon(Icons.copy, size: AppIconSize.i16),
                                label: const Text('Copy'),
                                style: OutlinedButton.styleFrom(foregroundColor: dialogContext.colors.primary),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.s8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: revoke,
                                icon: const Icon(Icons.cancel_outlined, size: AppIconSize.i16),
                                label: const Text('Revoke'),
                                style: OutlinedButton.styleFrom(foregroundColor: dialogContext.colors.dangerAccent),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.s8),
                        Center(
                          child: TextButton(
                            onPressed: generateNew,
                            style: TextButton.styleFrom(foregroundColor: dialogContext.colors.accent),
                            child: const Text('Generate a new one instead'),
                          ),
                        ),
                      ] else ...[
                        const Text(
                          'Generate a one-time code for the person you\'re '
                          'hiring - it works for 48 hours or until used once, '
                          'whichever comes first.',
                          style: TextStyle(fontSize: AppFontSize.f13),
                        ),
                        const SizedBox(height: AppSpacing.s16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: generateNew,
                            style: ButtonStyle(
                              backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                                if (states.contains(WidgetState.hovered)) return dialogContext.colors.accent;
                                return dialogContext.colors.primary;
                              }),
                              foregroundColor: WidgetStateProperty.all(dialogContext.colors.onPrimary),
                              padding: WidgetStateProperty.all(const EdgeInsets.symmetric(vertical: AppSpacing.s12)),
                            ),
                            child: const Text('Generate Invite Code'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              style: ButtonStyle(
                foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                  if (states.contains(WidgetState.hovered)) return dialogContext.colors.accent;
                  return dialogContext.colors.primary;
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
