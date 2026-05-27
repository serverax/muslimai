import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'config/theme.dart';
import 'screens/chat_screen.dart';

void main() {
  runApp(const ProviderScope(child: SakinaApp()));
}

class SakinaApp extends StatelessWidget {
  const SakinaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Project Sakina',
      theme: SakinaTheme.buildLightTheme(false),
      darkTheme: SakinaTheme.buildDarkTheme(false),
      home: const ChatScreen(),
    );
  }
}
