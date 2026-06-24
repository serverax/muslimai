import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../services/auth_service.dart';
import '../screens/account_intro_screen.dart';
import '../screens/subscription_screen.dart';

/// Reusable login-required gate screen.
class LoginRequiredScreen extends StatelessWidget {
  const LoginRequiredScreen({
    super.key,
    required this.appState,
    required this.featureName,
    this.onContinueAsGuest,
    this.onLoggedIn,
  });

  final AppState appState;
  final String featureName;
  final VoidCallback? onContinueAsGuest;
  final void Function(AuthSession session)? onLoggedIn;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(featureName)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.lock_outline, size: 56, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              'Please login to save your progress and use this feature.',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              featureName,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
            ),
            const Spacer(),
            FilledButton(
              onPressed: () => _openAuth(context, loginMode: true),
              child: const Text('Login'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => _openAuth(context, loginMode: false),
              child: const Text('Register'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                if (onContinueAsGuest != null) {
                  onContinueAsGuest!();
                } else {
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Continue as guest'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openAuth(BuildContext context, {required bool loginMode}) async {
    final session = await Navigator.of(context).push<AuthSession>(
      MaterialPageRoute(
        builder: (_) => AccountIntroScreen(
          appState: appState,
          initialLoginMode: loginMode,
          returnSessionOnSuccess: true,
          onAuthenticated: onLoggedIn,
        ),
      ),
    );
    if (session != null && context.mounted) {
      onLoggedIn?.call(session);
      Navigator.of(context).pop(session);
    }
  }
}

class PremiumLockedScreen extends StatelessWidget {
  const PremiumLockedScreen({
    super.key,
    required this.featureName,
    this.reason,
    this.session,
  });

  final String featureName;
  final String? reason;
  final AuthSession? session;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(featureName)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.workspace_premium, size: 56, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(featureName, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              reason ?? 'This feature requires a premium subscription.',
              textAlign: TextAlign.center,
            ),
            const Spacer(),
            FilledButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SubscriptionScreen(session: session),
                  ),
                );
              },
              child: const Text('View plans'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Back home'),
            ),
          ],
        ),
      ),
    );
  }
}

class NotImplementedScreen extends StatelessWidget {
  const NotImplementedScreen({
    super.key,
    required this.featureName,
    this.reason,
    this.nextPhase,
  });

  final String featureName;
  final String? reason;
  final String? nextPhase;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(featureName)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.construction_outlined, size: 56, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text('Not implemented yet', style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(featureName, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600)),
            if (reason != null) ...[
              const SizedBox(height: 12),
              Text(reason!, textAlign: TextAlign.center),
            ],
            if (nextPhase != null) ...[
              const SizedBox(height: 12),
              Text('Next planned phase: $nextPhase', textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
            ],
            const Spacer(),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Back'),
            ),
          ],
        ),
      ),
    );
  }
}

class FeatureGate {
  static Future<T?> requireLogin<T>({
    required BuildContext context,
    required AppState appState,
    required AuthSession? session,
    required String featureName,
    required Future<T> Function(AuthSession session) onAllowed,
    void Function(AuthSession session)? onLoggedIn,
  }) async {
    if (session != null) {
      return onAllowed(session);
    }
    final result = await Navigator.of(context).push<AuthSession>(
      MaterialPageRoute(
        builder: (_) => LoginRequiredScreen(
          appState: appState,
          featureName: featureName,
          onLoggedIn: onLoggedIn,
        ),
      ),
    );
    if (result != null) {
      return onAllowed(result);
    }
    return null;
  }
}
