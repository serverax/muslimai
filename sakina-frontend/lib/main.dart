import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'design/app_theme.dart';
import 'providers/preferences.dart';
import 'screens/app_shell.dart';

void main() {
  runApp(const ProviderScope(child: SakinaApp()));
}

class SakinaApp extends ConsumerWidget {
  const SakinaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(preferencesProvider);

    return MaterialApp(
      title: 'Project Sakina',
      debugShowCheckedModeBanner: false,
      theme: SakinaAppTheme.light(
        highContrast: prefs.highContrast,
        reduceOrnament: prefs.reduceOrnament,
      ),
      darkTheme: SakinaAppTheme.dark(
        highContrast: prefs.highContrast,
        reduceOrnament: prefs.reduceOrnament,
      ),
      themeMode: prefs.themeMode,
      locale: prefs.locale,
      // Apply the user's text-scale preference globally.
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(textScaler: TextScaler.linear(prefs.textScale)),
          child: child!,
        );
      },
      home: const SakinaShell(),
    );
  }
}
