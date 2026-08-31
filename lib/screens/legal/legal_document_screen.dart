import 'package:flutter/material.dart';

/// One heading + body pair within a legal document.
class LegalSection {
  final String heading;
  final String body;
  const LegalSection({required this.heading, required this.body});
}

/// Shared scaffold for both Terms of Service and Privacy Policy -
/// responsive by construction rather than needing separate mobile/
/// desktop logic: a capped reading width keeps lines comfortable to
/// read on a wide screen, and naturally shrinks to fill a narrow one,
/// the same way a well-set article column does regardless of viewport.
class LegalDocumentScreen extends StatelessWidget {
  final String title;
  final String lastUpdated;
  final String intro;
  final List<LegalSection> sections;

  const LegalDocumentScreen({
    super.key,
    required this.title,
    required this.lastUpdated,
    required this.intro,
    required this.sections,
  });

  static const Color _primaryDeepGreen = Color(0xFF2F5D62);
  static const Color _offWhite = Color(0xFFFDFDF9);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _offWhite,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: _primaryDeepGreen,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _primaryDeepGreen)),
                const SizedBox(height: 6),
                Text('Last updated: $lastUpdated',
                    style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
                const SizedBox(height: 20),
                Text(intro, style: const TextStyle(fontSize: 14.5, height: 1.6, color: Colors.black87)),
                const SizedBox(height: 28),
                ...sections.map(
                  (section) => Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(section.heading,
                            style: const TextStyle(
                                fontSize: 16.5, fontWeight: FontWeight.bold, color: _primaryDeepGreen)),
                        const SizedBox(height: 8),
                        Text(section.body,
                            style: const TextStyle(fontSize: 14.5, height: 1.65, color: Colors.black87)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
