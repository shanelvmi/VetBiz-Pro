import 'package:flutter/material.dart';

/// One heading + body pair within a legal document.
class LegalSection {
  final String heading;
  final String body;
  const LegalSection({required this.heading, required this.body});
}

/// One entry in the "Key Points" sidebar - a quick, scannable summary
/// of something the full document explains in detail below.
class LegalKeyPoint {
  final IconData icon;
  final String title;
  final String description;
  const LegalKeyPoint({required this.icon, required this.title, required this.description});
}

/// Shared scaffold for both Terms of Service and Privacy Policy.
/// Two-column on a wide screen - the numbered sections on the left,
/// a "Key Points" summary card on the right - and stacks to one
/// column on a narrow one, the same responsive-by-construction
/// approach as the rest of the app rather than separate mobile/
/// desktop logic.
class LegalDocumentScreen extends StatelessWidget {
  final String title;
  final String subtitle;
  final String lastUpdated;
  final String intro;
  final List<LegalSection> sections;
  final List<LegalKeyPoint> keyPoints;
  final String calloutTitle;
  final String calloutBody;

  const LegalDocumentScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.lastUpdated,
    required this.intro,
    required this.sections,
    required this.keyPoints,
    required this.calloutTitle,
    required this.calloutBody,
  });

  static const Color _primaryDeepGreen = Color(0xFF2F5D62);
  static const Color _offWhite = Color(0xFFFDFDF9);

  // The existing section headings already carry their own "1. ", "2. "
  // prefix (needed elsewhere they're used as plain text) - stripped
  // here since the circled number badge now carries that role instead,
  // so the number isn't shown twice on the same line.
  static String _stripLeadingNumber(String heading) {
    return heading.replaceFirst(RegExp(r'^\d+\.\s*'), '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _offWhite,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        centerTitle: true,
        toolbarHeight: 72,
        title: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 19, color: Colors.black87)),
            Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1440),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 820;
                final mainCard = _buildMainCard();
                final sidebar = _buildSidebar();

                if (!isWide) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [mainCard, const SizedBox(height: 20), sidebar],
                    ),
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 7,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: mainCard,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 3,
                      child: SingleChildScrollView(
                        physics: const NeverScrollableScrollPhysics(),
                        child: sidebar,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _primaryDeepGreen)),
          const SizedBox(height: 6),
          Text('Last updated: $lastUpdated', style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
          const SizedBox(height: 18),
          Divider(color: Colors.grey.shade200, height: 1),
          const SizedBox(height: 20),
          Text(intro, style: const TextStyle(fontSize: 14.5, height: 1.6, color: Colors.black87)),
          const SizedBox(height: 28),
          ...sections.asMap().entries.map((entry) {
            final index = entry.key;
            final section = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: _primaryDeepGreen.withValues(alpha: 0.12), shape: BoxShape.circle),
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: _primaryDeepGreen),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_stripLeadingNumber(section.heading),
                            style: const TextStyle(
                                fontSize: 16.5, fontWeight: FontWeight.bold, color: _primaryDeepGreen)),
                        const SizedBox(height: 8),
                        Text(section.body,
                            style: const TextStyle(fontSize: 14.5, height: 1.65, color: Colors.black87)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        color: _primaryDeepGreen.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Key Points', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _primaryDeepGreen)),
          const SizedBox(height: 6),
          ...keyPoints.asMap().entries.map((entry) {
            final isLast = entry.key == keyPoints.length - 1;
            final point = entry.value;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration:
                            BoxDecoration(color: _primaryDeepGreen.withValues(alpha: 0.12), shape: BoxShape.circle),
                        child: Icon(point.icon, size: 17, color: _primaryDeepGreen),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(point.title,
                                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.black87)),
                            const SizedBox(height: 2),
                            Text(point.description,
                                style: TextStyle(fontSize: 12.5, height: 1.4, color: Colors.grey.shade700)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isLast) Divider(color: Colors.grey.shade200, height: 1),
              ],
            );
          }),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _primaryDeepGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: _primaryDeepGreen, shape: BoxShape.circle),
                  child: const Icon(Icons.verified_user_outlined, size: 16, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(calloutTitle,
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: _primaryDeepGreen)),
                      const SizedBox(height: 4),
                      Text(calloutBody,
                          style: TextStyle(fontSize: 12, height: 1.4, color: Colors.grey.shade700)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
