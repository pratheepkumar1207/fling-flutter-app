import 'package:flutter/material.dart';
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
                  style: TextStyle(
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
      "By creating an account or using any part of Insync, you agree to these terms. If you don't agree, please don't use the app."),
  LegalSection('2. Your account',
      "You're responsible for keeping your login secure and for everything that happens under your account. You must be 18 or older to use Insync."),
  LegalSection('3. Community standards',
      "Harassment, hate speech, impersonation, and sharing others' private information are never allowed — see our Community Rules for the full list."),
  LegalSection('4. Coins & purchases',
      'Coins are a virtual item for use within the app only. Purchases are generally non-refundable except where required by law.'),
  LegalSection('5. Termination',
      'We may suspend or remove accounts that violate these terms, at our discretion, with or without notice.'),
];

// What's allowed on Insync and what happens when a rule is broken. The steps
// at the end are the ones moderators actually have in the admin panel.
const kCommunityRulesSections = [
  LegalSection('1. Adults only',
      "Insync is for people 18 and over. Accounts that belong to someone younger are removed. Anything that sexualises a minor is reported to the police, and the account is banned straight away."),
  LegalSection('2. Be real',
      "Use your own photos, your real age and your own name. Don't pretend to be someone else, run fake accounts or buy followers."),
  LegalSection('3. Respect people',
      "No bullying, threats, hate or slurs about anyone's religion, caste, race, gender, sexuality or disability. If someone says no or stops replying, leave it there."),
  LegalSection('4. Nudity and sexual content',
      "No nudity or sexual acts in photos, reels, stories, rooms, live streams or your profile. Don't send explicit photos to anyone who hasn't asked for them. Never share intimate images of someone else."),
  LegalSection('5. Violence and dangerous acts',
      "No violence, gore, weapons for sale, drugs, or content that encourages self-harm. If you're struggling, Support in Settings can point you to help."),
  LegalSection('6. Live streams and rooms',
      "Hosts are responsible for what happens on their stream or room. Don't stream while driving, don't show people who haven't agreed to be on camera, and don't play films, matches or music you don't have the rights to."),
  LegalSection('7. Gifts, coins and diamonds',
      "Don't ask for gifts in exchange for anything sexual or off-app. Don't sell coins, diamonds or accounts outside the app. Gifts gained through fraud, chargebacks or fake accounts are taken back."),
  LegalSection('8. Scams and spam',
      "No fake giveaways, loan or investment offers, or links that ask for logins. Insync staff will never ask for your OTP, password or bank details in chat."),
  LegalSection('9. Privacy',
      "Don't share anyone's phone number, address, private chats or location without their permission. Don't record calls or rooms without telling everyone."),
  LegalSection("10. Other people's work",
      "Only post photos, videos and music you made or have the right to use. We remove content when the owner reports it."),
  LegalSection('11. What happens if a rule is broken',
      "Depending on how serious it is, we remove the post, message or stream, give the account a warning, suspend it for a number of days, or ban it. Serious harm, like anything involving a minor, means an instant ban. Gifts and diamonds earned by breaking these rules can be taken back."),
  LegalSection('12. Reporting and appeals',
      "Tap ••• on any profile, post, message, room or stream to report it. Reports are private. If you think we got a decision wrong, write to Support in Settings and someone will look at it again."),
];

const kPrivacyPolicySections = [
  LegalSection('1. Information we collect',
      'Profile details you provide, usage data, and (if you opt in) approximate location for nearby-match features.'),
  LegalSection('2. How we use information',
      'To operate the app, match you with other users, process payments, and keep the community safe.'),
  LegalSection('3. Sharing',
      "We don't sell your personal data. Limited data may be shared with service providers (payment processing, push notifications) strictly to operate the app."),
  LegalSection('4. Your choices',
      'You can review or edit your profile from Settings, and download a copy of your data. Location sharing can be turned off at any time.\n\nDeactivating hides your account until you log in again. Deleting hides it straight away and erases it after 30 days, unless you log in and keep it. That removes your profile, photos, posts, comments, identity and bank details. Coins and diamonds on the account are lost.\n\nWe keep payment records where the law requires, messages already in other people\'s chats (shown from "Deleted user"), reports and moderation records, and content held as evidence for a safety review.'),
  LegalSection('5. Security',
      'We use industry-standard measures to protect your data, but no system is 100% secure.'),
  LegalSection(
      '6. Contact', 'Reach out with any privacy questions or requests.'),
];
