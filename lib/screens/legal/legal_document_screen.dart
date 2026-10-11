import 'package:flutter/material.dart';
import '../../theme/app_breakpoints.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_text.dart';
import '../../theme/theme_context.dart';

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
      backgroundColor: context.colors.background,
      appBar: AppBar(
        backgroundColor: context.colors.surface,
        foregroundColor: context.colors.textPrimary,
        elevation: AppElevation.e1,
        centerTitle: true,
        toolbarHeight: 72,
        title: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title, style: TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f19, color: context.colors.textPrimary)),
            Text(subtitle, style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textSecondary)),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSizes.pageMax),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.s20, AppSpacing.s24, AppSpacing.s20, AppSpacing.s24),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= AppBreakpoints.twoPane;
                final mainCard = _buildMainCard(context);
                final sidebar = _buildSidebar(context);

                if (!isWide) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: AppSpacing.s16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [mainCard, const SizedBox(height: AppSpacing.s20), sidebar],
                    ),
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 7,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.only(bottom: AppSpacing.s16),
                        child: mainCard,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s20),
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

  Widget _buildMainCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpacing.s28, AppSpacing.s28, AppSpacing.s28, AppSpacing.s32),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.r14),
        boxShadow: [
          BoxShadow(color: context.colors.shadow.withValues(alpha: AppAlpha.a05), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: AppFontSize.f24, fontWeight: AppFontWeight.bold, color: context.colors.primary)),
          const SizedBox(height: AppSpacing.s6),
          Text('Last updated: $lastUpdated', style: TextStyle(fontSize: AppFontSize.f12_5, color: context.colors.textMuted)),
          const SizedBox(height: AppSpacing.s18),
          Divider(color: context.colors.divider, height: 1),
          const SizedBox(height: AppSpacing.s20),
          Text(intro, style: TextStyle(fontSize: AppFontSize.f14_5, height: 1.6, color: context.colors.textPrimary)),
          const SizedBox(height: AppSpacing.s28),
          ...sections.asMap().entries.map((entry) {
            final index = entry.key;
            final section = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: context.colors.primary.withValues(alpha: AppAlpha.a10), shape: BoxShape.circle),
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f13_5, color: context.colors.primary),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_stripLeadingNumber(section.heading),
                            style: TextStyle(
                                fontSize: AppFontSize.f17, fontWeight: AppFontWeight.bold, color: context.colors.primary)),
                        const SizedBox(height: AppSpacing.s8),
                        Text(section.body,
                            style: TextStyle(fontSize: AppFontSize.f14_5, height: 1.65, color: context.colors.textPrimary)),
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

  Widget _buildSidebar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpacing.s20, AppSpacing.s22, AppSpacing.s20, AppSpacing.s20),
      decoration: BoxDecoration(
        color: context.colors.primary.withValues(alpha: AppAlpha.a05),
        borderRadius: BorderRadius.circular(AppRadius.r14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Key Points', style: TextStyle(fontSize: AppFontSize.f17, fontWeight: AppFontWeight.bold, color: context.colors.primary)),
          const SizedBox(height: AppSpacing.s6),
          ...keyPoints.asMap().entries.map((entry) {
            final isLast = entry.key == keyPoints.length - 1;
            final point = entry.value;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.s12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration:
                            BoxDecoration(color: context.colors.primary.withValues(alpha: AppAlpha.a10), shape: BoxShape.circle),
                        child: Icon(point.icon, size: AppIconSize.i18, color: context.colors.primary),
                      ),
                      const SizedBox(width: AppSpacing.s12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(point.title,
                                style: TextStyle(fontSize: AppFontSize.f13_5, fontWeight: AppFontWeight.bold, color: context.colors.textPrimary)),
                            const SizedBox(height: AppSpacing.s2),
                            Text(point.description,
                                style: TextStyle(fontSize: AppFontSize.f12_5, height: 1.4, color: context.colors.textSoft)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isLast) Divider(color: context.colors.divider, height: 1),
              ],
            );
          }),
          const SizedBox(height: AppSpacing.s10),
          Container(
            padding: const EdgeInsets.all(AppSpacing.s16),
            decoration: BoxDecoration(
              color: context.colors.primary.withValues(alpha: AppAlpha.a10),
              borderRadius: BorderRadius.circular(AppRadius.r12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: context.colors.primary, shape: BoxShape.circle),
                  child: Icon(Icons.verified_user_outlined, size: AppIconSize.i16, color: context.colors.onPrimary),
                ),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(calloutTitle,
                          style: TextStyle(fontSize: AppFontSize.f13_5, fontWeight: AppFontWeight.bold, color: context.colors.primary)),
                      const SizedBox(height: AppSpacing.s4),
                      Text(calloutBody,
                          style: TextStyle(fontSize: AppFontSize.f12, height: 1.4, color: context.colors.textSoft)),
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
