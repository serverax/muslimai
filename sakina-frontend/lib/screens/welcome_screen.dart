import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../app/app_strings.dart';
import 'account_intro_screen.dart';
import 'onboarding_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0F1D3A),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (appState.mockMode)
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      appState.t('mockMode'),
                      style: const TextStyle(color: Colors.black87),
                    ),
                  ),
                Align(
                  alignment: Alignment.centerRight,
                  child: DropdownButton<AppLanguage>(
                    value: appState.language,
                    dropdownColor: const Color(0xFF13264B),
                    style: const TextStyle(color: Colors.white),
                    iconEnabledColor: Colors.white,
                    onChanged: (value) {
                      if (value != null) {
                        appState.setLanguage(value);
                      }
                    },
                    items: const [
                      DropdownMenuItem(
                        value: AppLanguage.english,
                        child: Text('English'),
                      ),
                      DropdownMenuItem(
                        value: AppLanguage.arabic,
                        child: Text('العربية'),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF13264B),
                    border:
                        Border.all(color: const Color(0xFFD6B25E), width: 1.4),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        appState.t('heroTitle'),
                        textAlign: appState.isArabic
                            ? TextAlign.right
                            : TextAlign.left,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        appState.t('heroSubtitle'),
                        textAlign: appState.isArabic
                            ? TextAlign.right
                            : TextAlign.left,
                        style: const TextStyle(
                          color: Color(0xFFE3D3A8),
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => OnboardingScreen(appState: appState),
                      ),
                    );
                  },
                  child: Text(appState.t('getStarted')),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () {
                    showDialog<void>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(appState.t('learnMore')),
                        content: Text(appState.t('phase2Notice')),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(appState.t('continue')),
                          ),
                        ],
                      ),
                    );
                  },
                  child: Text(appState.t('learnMore')),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AccountIntroScreen(appState: appState),
                      ),
                    );
                  },
                  child: Text(appState.t('continueLimited')),
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
