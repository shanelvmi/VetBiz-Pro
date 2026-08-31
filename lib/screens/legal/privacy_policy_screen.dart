import 'package:flutter/material.dart';
import 'legal_document_screen.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalDocumentScreen(
      title: 'Privacy Policy',
      lastUpdated: 'August 30, 2026',
      intro: 'This Privacy Policy explains what information VetBiz Pro ("we", "us", "the platform") '
          'collects when you or your facility use the app, how that information is used, and the '
          'choices you have. It applies to every account type on the platform - Admin, Assistant, and '
          'Platform Admin.',
      sections: [
        LegalSection(
          heading: '1. Information We Collect',
          body: 'Account information: your name, email address, phone number, and password (stored '
              'securely by our authentication provider, never in plain text or visible to us).\n\n'
              'Facility and business data: information you or your team enter while using the app - '
              'products, stock levels, sales, clients, services, transactions, and debts belonging to '
              'your facility.\n\n'
              'Facility details: your facility\'s name, type, logo, contact details, and subscription '
              'status.\n\n'
              'Usage information: basic activity logs (who did what, and when) within your facility, '
              'used for accountability between your own Admin and Assistant accounts, not for '
              'tracking outside the app.',
        ),
        LegalSection(
          heading: '2. How We Use Information',
          body: 'To provide the core service: running your facility\'s day-to-day operations, keeping '
              'your records in sync across your team\'s devices in real time, and generating reports '
              'and summaries from your own data.\n\n'
              'To manage your account and subscription: verifying your identity when you sign in, '
              'tracking your trial period or subscription status, and sending you service-related '
              'notices (a rejected request, a subscription reminder, a maintenance notice).\n\n'
              'To keep the platform secure: detecting and preventing misuse, and enforcing the access '
              'boundaries between facilities, so one facility can never see another\'s data.',
        ),
        LegalSection(
          heading: '3. Where Your Data Is Stored',
          body: 'VetBiz Pro is built on Firebase, a cloud platform operated by Google. Your data is '
              'stored and processed on Firebase\'s infrastructure, protected by access rules that '
              'restrict every piece of facility data to only the accounts that actually belong to '
              'that facility. We do not maintain a separate, independent copy of your data outside '
              'this infrastructure.',
        ),
        LegalSection(
          heading: '4. Who Can See Your Data',
          body: 'Within your facility: any Admin or Assistant account you\'ve added to your facility '
              'can see the facility data relevant to their role, exactly as intended for a shared '
              'business tool.\n\n'
              'Platform Admins: a small number of trusted platform administrators can access account '
              'and subscription information across facilities, for support, billing, and '
              'platform-management purposes - not to view your day-to-day sales or client details '
              'without reason.\n\n'
              'We do not sell your data, and we do not share it with advertisers or unrelated third '
              'parties. It is never used for anything beyond operating the platform itself.',
        ),
        LegalSection(
          heading: '5. Your Choices and Rights',
          body: 'You can update your own profile information at any time from Settings > Manage '
              'Account.\n\n'
              'You can permanently delete your account from that same screen, which removes your '
              'login entirely, so the email address becomes available to register again. Certain '
              'accounts (a Platform Admin, or an Admin who still owns a facility) are required to '
              'resolve that first, since deleting them would otherwise leave a facility without an '
              'owner.\n\n'
              'A facility Admin can also permanently wipe all of a specific facility\'s business '
              'records (sales, products, clients, transactions) from that same screen, while keeping '
              'the login itself intact.',
        ),
        LegalSection(
          heading: '6. Data Retention',
          body: 'We keep your account and facility data for as long as your account remains active. '
              'Items you delete within the app (a product, a client) are held in a recoverable Trash '
              'for a limited period before being permanently removed, to protect against accidental '
              'deletion. If you delete your account entirely, your personal account data is removed '
              'at that time.',
        ),
        LegalSection(
          heading: '7. Children\'s Privacy',
          body: 'VetBiz Pro is a business tool intended for adults managing a veterinary or agrovet '
              'facility. It is not directed at children, and we do not knowingly collect information '
              'from anyone under the age of 18.',
        ),
        LegalSection(
          heading: '8. Changes to This Policy',
          body: 'We may update this Privacy Policy from time to time as the platform evolves. The '
              '"Last updated" date at the top of this page reflects the most recent revision. '
              'Continued use of VetBiz Pro after a change means you accept the updated policy.',
        ),
        LegalSection(
          heading: '9. Contact',
          body: 'If you have questions about this Privacy Policy or how your data is handled, please '
              'reach out through your Platform Admin or the support contact provided to your '
              'organization.',
        ),
      ],
    );
  }
}
