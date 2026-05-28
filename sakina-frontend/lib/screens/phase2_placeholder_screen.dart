import 'package:flutter/material.dart';

import '../app/app_state.dart';

class Phase2PlaceholderScreen extends StatelessWidget {
  const Phase2PlaceholderScreen({
    super.key,
    required this.title,
    required this.appState,
  });

  final String title;
  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_clock_outlined, size: 42),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              appState.t('featureDisabled'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              appState.t('enableFeatureHint'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
