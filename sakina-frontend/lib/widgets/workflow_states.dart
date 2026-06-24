import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../design/sakina_colors.dart';
import '../services/auth_service.dart';
import '../screens/account_intro_screen.dart';
import '../screens/subscription_screen.dart';
import 'luxury/luxury_components.dart';

/// Gate state screens — luxury styled, no red debug UI.
class GateStateScreen extends StatelessWidget {
  const GateStateScreen._({
    required this.title,
    required this.icon,
    required this.headline,
    required this.body,
    this.actions = const [],
    this.showDisclaimer = false,
  });

  final String title;
  final IconData icon;
  final String headline;
  final String body;
  final List<Widget> actions;
  final bool showDisclaimer;

  factory GateStateScreen.loginRequired({
    required String featureName,
    required AppState appState,
    void Function(AuthSession session)? onLoggedIn,
  }) {
    return GateStateScreen._(
      title: featureName,
      icon: Icons.lock_outline,
      headline: 'Login required',
      body: 'Please sign in to use $featureName and save your progress.',
      showDisclaimer: false,
      actions: [
        _GateActions.login(appState: appState, featureName: featureName, onLoggedIn: onLoggedIn),
      ],
    );
  }

  factory GateStateScreen.premiumLocked({
    required String featureName,
    AuthSession? session,
    String? reason,
  }) {
    return GateStateScreen._(
      title: featureName,
      icon: Icons.workspace_premium,
      headline: 'Premium feature',
      body: reason ?? '$featureName is available with a premium subscription.',
      actions: [
        _GateActions.premium(session: session),
      ],
    );
  }

  factory GateStateScreen.comingSoon({required String featureName}) {
    return GateStateScreen._(
      title: featureName,
      icon: Icons.hourglass_top,
      headline: 'Coming soon',
      body: '$featureName is being prepared with care. Check back in a future update.',
      actions: [_GateActions.back()],
    );
  }

  factory GateStateScreen.disabled({required String featureName}) {
    return GateStateScreen._(
      title: featureName,
      icon: Icons.block,
      headline: 'Unavailable',
      body: '$featureName is currently turned off by the Sakina team.',
      actions: [_GateActions.back()],
    );
  }

  factory GateStateScreen.maintenance({required String featureName}) {
    return GateStateScreen._(
      title: featureName,
      icon: Icons.build_circle_outlined,
      headline: 'Under maintenance',
      body: '$featureName is temporarily unavailable while we improve it.',
      actions: [_GateActions.back()],
    );
  }

  factory GateStateScreen.notImplemented({
    required String featureName,
    String? reason,
  }) {
    return GateStateScreen._(
      title: featureName,
      icon: Icons.construction_outlined,
      headline: 'Not available yet',
      body: reason ?? '$featureName is planned but not yet available in this build.',
      actions: [_GateActions.back()],
    );
  }

  factory GateStateScreen.accessDenied({required String featureName}) {
    return GateStateScreen._(
      title: featureName,
      icon: Icons.shield_outlined,
      headline: 'Access restricted',
      body: 'You do not have permission to open $featureName.',
      actions: [_GateActions.back()],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showDisclaimer) const SafeDisclaimerBanner(compact: true),
              const Spacer(),
              Icon(icon, size: 56, color: SakinaColors.emerald),
              const SizedBox(height: 20),
              Text(
                headline,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: SakinaColors.navy,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(body, textAlign: TextAlign.center, style: const TextStyle(color: SakinaColors.textSecondary)),
              const Spacer(),
              ...actions,
            ],
          ),
        ),
      ),
    );
  }
}

class _GateActions {
  const _GateActions._();

  static Widget login({
    required AppState appState,
    required String featureName,
    void Function(AuthSession session)? onLoggedIn,
  }) {
    return _LoginActions(
      appState: appState,
      featureName: featureName,
      onLoggedIn: onLoggedIn,
    );
  }

  static Widget premium({AuthSession? session}) {
    return _PremiumActions(session: session);
  }

  static Widget back() => const _BackButton();
}

class _LoginActions extends StatelessWidget {
  const _LoginActions({
    required this.appState,
    required this.featureName,
    this.onLoggedIn,
  });

  final AppState appState;
  final String featureName;
  final void Function(AuthSession session)? onLoggedIn;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Continue as guest'),
        ),
      ],
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

class _PremiumActions extends StatelessWidget {
  const _PremiumActions({this.session});

  final AuthSession? session;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => SubscriptionScreen(session: session)),
          ),
          child: const Text('View plans'),
        ),
        const SizedBox(height: 8),
        const _BackButton(),
      ],
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton();

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: () => Navigator.of(context).pop(),
      child: const Text('Back'),
    );
  }
}

// Back-compat wrappers for existing imports.
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
    return GateStateScreen.loginRequired(
      featureName: featureName,
      appState: appState,
      onLoggedIn: onLoggedIn,
    );
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
    return GateStateScreen.premiumLocked(
      featureName: featureName,
      session: session,
      reason: reason,
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
    final body = reason ?? (nextPhase != null ? 'Planned for $nextPhase.' : null);
    return GateStateScreen.notImplemented(featureName: featureName, reason: body);
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
