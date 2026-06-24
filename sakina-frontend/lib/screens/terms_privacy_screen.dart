import 'package:flutter/material.dart';

import '../widgets/luxury/luxury_components.dart';

/// Placeholder terms/privacy screen for app-store readiness foundation.
class TermsPrivacyScreen extends StatelessWidget {
  const TermsPrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Terms & Privacy')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          SafeDisclaimerBanner(),
          SizedBox(height: 16),
          Text(
            'Terms of Use (placeholder)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          SizedBox(height: 8),
          Text(
            'Sakina AI provides Islamic learning and guidance support. By using this app you agree '
            'to use it for educational purposes. AI answers may be limited and are not a substitute '
            'for qualified scholarly fatwa on personal matters.',
          ),
          SizedBox(height: 20),
          Text(
            'Privacy Policy (placeholder)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          SizedBox(height: 8),
          Text(
            'Sakina respects your privacy. Account data, bookmarks, and reminders are stored securely. '
            'Location is used only for prayer times and Qibla when you grant permission. '
            'A full privacy policy will be published before public app store release.',
          ),
          SizedBox(height: 20),
          Text(
            'Account deletion',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          SizedBox(height: 8),
          Text(
            'Self-service account deletion will be available before public release. '
            'For local testing, contact the app owner.',
          ),
        ],
      ),
    );
  }
}
