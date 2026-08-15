import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Shows a Firestore query error clearly - and if the error contains a
/// URL (the common case: "this query requires an index, create it here:
/// https://..."), that link is rendered as an actual clickable button
/// instead of plain unclickable text, so tapping it takes you straight to
/// Firebase Console with the correct index pre-filled in.
class FirestoreErrorView extends StatelessWidget {
  final Object? error;
  const FirestoreErrorView({super.key, required this.error});

  static const Color primaryColor = Color(0xFF2F5D62);

  @override
  Widget build(BuildContext context) {
    final message = '$error';
    final urlMatch = RegExp(r'https?://\S+').firstMatch(message);
    final url = urlMatch?.group(0);
    final textWithoutUrl = url != null ? message.replaceAll(url, '').trim() : message;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
          const SizedBox(height: 12),
          const Text('Could not load data:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SelectableText(
            textWithoutUrl,
            style: const TextStyle(fontSize: 12, color: Colors.redAccent),
            textAlign: TextAlign.center,
          ),
          if (url != null) ...[
            const SizedBox(height: 14),
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
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'This opens Firebase Console with the exact index needed already filled in.',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
