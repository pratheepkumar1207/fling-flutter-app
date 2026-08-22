import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';

class LegalSection {
  final String heading;
  final String body;
  const LegalSection(this.heading, this.body);
}

/// Matches LegalDark.dc.html: numbered display-font section headers over
/// faint body paragraphs, with a "Last updated" line under the header.
/// Reusable for Terms of Service / Privacy Policy / About Us — [sections]
/// carries the structured content instead of one flat body string.
class LegalScreen extends StatelessWidget {
  final String title;
  final String? lastUpdated;
  final List<LegalSection> sections;

  const LegalScreen(
      {super.key,
      required this.title,
      this.lastUpdated,
      required this.sections});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
        children: [
          if (lastUpdated != null)
            Padding(
              padding: const EdgeInsets.only(top: 14, bottom: 4),
              child: Text('Last updated · $lastUpdated',
                  style: const TextStyle(
                      color: AppColors.textFaint, fontSize: 11)),
            ),
          for (final section in sections) ...[
            Padding(
              padding: const EdgeInsets.only(top: 18, bottom: 6),
              child: Text(section.heading,
                  style: GoogleFonts.bricolageGrotesque(
                      color: AppColors.text,
                      fontWeight: FontWeight.w700,
                      fontSize: 14)),
            ),
            Text(section.body,
                style: const TextStyle(
                    color: AppColors.textFaint, fontSize: 12.5, height: 1.7)),
          ],
        ],
      ),
    );
  }
}

const kTermsOfServiceSections = [
  LegalSection('1. Acceptance of terms',
      "By creating an account or using any part of Fling, you agree to these terms. If you don't agree, please don't use the app."),
  LegalSection('2. Your account',
      "You're responsible for keeping your login secure and for everything that happens under your account. You must be 18 or older to use Fling."),
  LegalSection('3. Community standards',
      "Harassment, hate speech, impersonation, and sharing others' private information are never allowed — see our Safety Guidelines for the full list."),
  LegalSection('4. Coins & purchases',
      'Coins are a virtual item for use within the app only. Purchases are generally non-refundable except where required by law.'),
  LegalSection('5. Termination',
      'We may suspend or remove accounts that violate these terms, at our discretion, with or without notice.'),
];

const kPrivacyPolicySections = [
  LegalSection('1. Information we collect',
      'Profile details you provide, usage data, and (if you opt in) approximate location for nearby-match features.'),
  LegalSection('2. How we use information',
      'To operate the app, match you with other users, process payments, and keep the community safe.'),
  LegalSection('3. Sharing',
      "We don't sell your personal data. Limited data may be shared with service providers (payment processing, push notifications) strictly to operate the app."),
  LegalSection('4. Your choices',
      'You can review, edit, or delete your profile information from Settings at any time. Location sharing can be turned off at any time.'),
  LegalSection('5. Security',
      'We use industry-standard measures to protect your data, but no system is 100% secure.'),
  LegalSection(
      '6. Contact', 'Reach out with any privacy questions or requests.'),
];
