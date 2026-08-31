import 'package:flutter/material.dart';
import 'legal_document_screen.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalDocumentScreen(
      title: 'Terms of Service',
      lastUpdated: 'August 30, 2026',
      intro: 'These Terms of Service ("Terms") govern your use of VetBiz Pro, a business management '
          'platform for veterinary and agrovet facilities. By registering an account or using the '
          'app, you agree to these Terms on behalf of yourself and, if applicable, your facility.',
      sections: [
        LegalSection(
          heading: '1. The Service',
          body: 'VetBiz Pro provides tools for managing a veterinary or agrovet facility\'s day-to-day '
              'operations - products and stock, sales, clients, services, transactions, debts, and '
              'staff access - accessible from any device your facility uses.',
        ),
        LegalSection(
          heading: '2. Accounts and Roles',
          body: 'Every user signs in with their own individual account. An Admin account creates and '
              'owns a facility, manages its subscription, and can add Assistant accounts to help run '
              'it. An Assistant account works within a facility an Admin has added them to, with '
              'access appropriate to that role.\n\n'
              'You are responsible for keeping your own login credentials secure, and for the '
              'activity that happens under your account. An Admin is responsible for who they choose '
              'to add to their facility, and for that person\'s access to the facility\'s data.',
        ),
        LegalSection(
          heading: '3. Trial Period and Subscription',
          body: 'A new facility starts with a trial period, the length of which is set by the '
              'platform and may change over time. After the trial ends, continued use of the '
              'facility\'s full features requires an active subscription, according to the pricing '
              'and plans presented within the app at the time.\n\n'
              'An Admin account is limited in how many facilities it may create, to keep the trial '
              'period a genuine trial rather than a way to repeatedly avoid subscribing.\n\n'
              'A facility whose subscription has lapsed enters a short grace period, after which it '
              'moves to a read-only state - existing records remain visible, but new sales, services, '
              'and similar entries are paused until the subscription is renewed.',
        ),
        LegalSection(
          heading: '4. Acceptable Use',
          body: 'You agree to use VetBiz Pro only for legitimate business purposes related to '
              'operating your veterinary or agrovet facility, and not to attempt to access another '
              'facility\'s data, interfere with the platform\'s normal operation, or use the service '
              'in any way that violates applicable law.',
        ),
        LegalSection(
          heading: '5. Your Data',
          body: 'The business records you and your team enter - products, sales, clients, and the '
              'rest - belong to your facility. We do not claim ownership of it, and use it only to '
              'provide the service back to you, as described in our Privacy Policy.\n\n'
              'You are responsible for the accuracy of the information you enter, and for complying '
              'with any laws that apply to how your own facility collects and handles its clients\' '
              'information.',
        ),
        LegalSection(
          heading: '6. Account and Facility Deletion',
          body: 'You may delete your own account at any time from Settings > Manage Account, which '
              'permanently removes it from the platform. A Platform Admin account, or an Admin '
              'account that still owns a facility, must resolve that first (transfer or delete the '
              'facility) before the account itself can be deleted, since a facility left without an '
              'owner could not be managed by anyone afterward.\n\n'
              'An Admin may also permanently delete a facility they own, and separately, may wipe a '
              'facility\'s business records while keeping the account itself active. Both actions are '
              'irreversible once confirmed.',
        ),
        LegalSection(
          heading: '7. Service Availability',
          body: 'We aim to keep VetBiz Pro available and reliable, but the service may occasionally '
              'be unavailable for maintenance or reasons outside our control. We will make reasonable '
              'efforts to notify users of planned maintenance in advance where practical.',
        ),
        LegalSection(
          heading: '8. Termination',
          body: 'We may suspend or terminate an account that violates these Terms, misuses the '
              'platform, or engages in fraudulent activity. You may stop using the service, and '
              'delete your account, at any time.',
        ),
        LegalSection(
          heading: '9. Limitation of Liability',
          body: 'VetBiz Pro is provided on an "as is" basis. To the fullest extent permitted by law, '
              'we are not liable for indirect, incidental, or consequential damages arising from your '
              'use of the platform, including loss of business data, except where caused by our own '
              'gross negligence or willful misconduct.',
        ),
        LegalSection(
          heading: '10. Changes to These Terms',
          body: 'We may update these Terms as the platform evolves. The "Last updated" date at the '
              'top of this page reflects the most recent revision. Continued use of VetBiz Pro after '
              'a change means you accept the updated Terms.',
        ),
        LegalSection(
          heading: '11. Contact',
          body: 'If you have questions about these Terms, please reach out through your Platform '
              'Admin or the support contact provided to your organization.',
        ),
      ],
    );
  }
}
