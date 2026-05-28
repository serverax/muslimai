import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app_state.dart';
import 'config/theme.dart';
import 'screens/account_intro_screen.dart';
import 'screens/welcome_screen.dart';

void main() {
  runApp(const ProviderScope(child: SakinaApp()));
}

class SakinaApp extends StatefulWidget {
  const SakinaApp({super.key});

  @override
  State<SakinaApp> createState() => _SakinaAppState();
}

class _SakinaAppState extends State<SakinaApp> {
  AppState? _appState;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final state = await AppState.load();
    if (!mounted) return;
    setState(() => _appState = state);
  }

  @override
  Widget build(BuildContext context) {
    final state = _appState;
    if (state == null) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text('Loading Sakina AI...'),
              ],
            ),
          ),
        ),
      );
    }

    return MaterialApp(
      title: state.t('appTitle'),
      theme: SakinaTheme.buildLightTheme(state.isArabic),
      darkTheme: SakinaTheme.buildDarkTheme(state.isArabic),
      home: AnimatedBuilder(
        animation: state,
        builder: (_, __) {
          if (state.onboardingComplete) {
            return AccountIntroScreen(appState: state);
          }
          return WelcomeScreen(appState: state);
        },
      ),
    );
  }
}
