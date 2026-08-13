import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// Reusable static-text screen for Terms of Service / Privacy Policy / About
/// Us — placeholder copy for now; swap [body] for real legal text once it's
/// written, no other changes needed.
class LegalScreen extends StatelessWidget {
  final String title;
  final String body;

  const LegalScreen({super.key, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: Text(title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Text(body, style: const TextStyle(color: AppColors.textDim, fontSize: 14, height: 1.6)),
      ),
    );
  }
}

const kTermsOfServicePlaceholder = '''
Terms of Service

These Terms of Service ("Terms") govern your use of this app. This is placeholder text — replace it with your actual Terms of Service before shipping to production.

1. Acceptance of Terms
By creating an account, you agree to these Terms and our Privacy Policy.

2. Eligibility
You must be at least 18 years old to use this app.

3. User Conduct
You agree not to use the app for any unlawful purpose, to harass other users, or to post content that violates our community guidelines.

4. Content
You retain ownership of content you post, but grant us a license to display it within the app.

5. Termination
We may suspend or terminate accounts that violate these Terms.

6. Changes
We may update these Terms from time to time. Continued use of the app after changes constitutes acceptance.

Contact us with any questions about these Terms.
''';

const kPrivacyPolicyPlaceholder = '''
Privacy Policy

This Privacy Policy describes how we collect, use, and protect your information. This is placeholder text — replace it with your actual Privacy Policy before shipping to production.

1. Information We Collect
Profile details you provide, usage data, and (if you opt in) approximate location for nearby-match features.

2. How We Use Information
To operate the app, match you with other users, process payments, and keep the community safe.

3. Sharing
We don't sell your personal data. Limited data may be shared with service providers (payment processing, push notifications) strictly to operate the app.

4. Your Choices
You can review, edit, or delete your profile information from Settings at any time. Location sharing can be turned off at any time.

5. Security
We use industry-standard measures to protect your data, but no system is 100% secure.

6. Contact
Reach out with any privacy questions or requests.
''';
