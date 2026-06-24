import 'package:flutter/material.dart';

import '../app/app_state.dart';
import 'account_intro_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.appState});

  final AppState appState;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _index = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.appState;
    final slides = [
      (app.t('onboardingTitle1'), app.t('onboardingBody1')),
      (app.t('onboardingTitle2'), app.t('onboardingBody2')),
      (app.t('onboardingTitle3'), app.t('onboardingBody3')),
    ];
    final isLast = _index == slides.length - 1;

    return Scaffold(
      appBar: AppBar(title: Text(app.t('appTitle'))),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: slides.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) {
                  final slide = slides[i];
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        slide.$1,
                        textAlign:
                            app.isArabic ? TextAlign.right : TextAlign.left,
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        slide.$2,
                        textAlign:
                            app.isArabic ? TextAlign.right : TextAlign.left,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                slides.length,
                (i) => Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: i == _index
                        ? const Color(0xFF1B6B5E)
                        : Colors.grey.shade400,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                final navigator = Navigator.of(context);
                if (!isLast) {
                  await _pageController.nextPage(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                  );
                  return;
                }
                await app.completeOnboarding();
                if (!mounted) return;
                navigator.pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => AccountIntroScreen(appState: app),
                  ),
                );
              },
              child: Text(app.t('continue')),
            ),
          ],
        ),
      ),
    );
  }
}
