import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_dimens.dart';
import '../theme/app_text.dart';
import '../theme/theme_context.dart';

/// Shows a Firestore query error clearly - and if the error contains a
/// URL (the common case: "this query requires an index, create it here:
/// https://..."), that link is rendered as an actual clickable button
/// instead of plain unclickable text, so tapping it takes you straight to
/// Firebase Console with the correct index pre-filled in.
class FirestoreErrorView extends StatelessWidget {
  final Object? error;
  const FirestoreErrorView({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    final message = '$error';
    final urlMatch = RegExp(r'https?://\S+').firstMatch(message);
    final url = urlMatch?.group(0);
    final textWithoutUrl = url != null ? message.replaceAll(url, '').trim() : message;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.s24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: context.colors.dangerAccent),
          const SizedBox(height: AppSpacing.s12),
          const Text('Could not load data:', style: TextStyle(fontWeight: AppFontWeight.bold)),
          const SizedBox(height: AppSpacing.s8),
          SelectableText(
            textWithoutUrl,
            style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.dangerAccent),
            textAlign: TextAlign.center,
          ),
          if (url != null) ...[
            const SizedBox(height: AppSpacing.s14),
            ElevatedButton.icon(
              onPressed: () async {
                final uri = Uri.parse(url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              icon: const Icon(Icons.build_circle_outlined),
              label: const Text('Create Missing Index'),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.primary,
                foregroundColor: context.colors.onPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.s6),
            Text(
              'This opens Firebase Console with the exact index needed already filled in.',
              style: TextStyle(fontSize: AppFontSize.f11, color: context.colors.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
