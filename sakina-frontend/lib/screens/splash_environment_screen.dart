import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../app/app_state.dart';
import '../config/api_config.dart';
import '../design/sakina_colors.dart';
import '../services/auth_service.dart';
import '../widgets/luxury/luxury_components.dart';
import 'account_intro_screen.dart';
import 'home_shell_screen.dart';
import 'terms_privacy_screen.dart';
import 'welcome_screen.dart';

/// Splash + API health probe with luxury styling and safety disclaimer.
class SplashEnvironmentScreen extends StatefulWidget {
  const SplashEnvironmentScreen({super.key, required this.appState});

  final AppState appState;

  @override
  State<SplashEnvironmentScreen> createState() => _SplashEnvironmentScreenState();
}

class _SplashEnvironmentScreenState extends State<SplashEnvironmentScreen> {
  String? _apiBase;
  bool? _healthOk;
  String _status = 'Checking Sakina environment…';
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() => _status = 'Resolving API base URL…');
    final baseUrl = await ApiConfig.resolveBaseUrl();
    setState(() {
      _apiBase = baseUrl;
      _status = 'Checking API health…';
    });

    bool healthOk = false;
    try {
      final healthUrl = ApiConfig.healthUrlFor(baseUrl);
      final res = await http.get(Uri.parse(healthUrl)).timeout(const Duration(seconds: 8));
      healthOk = res.statusCode == 200;
    } catch (_) {
      healthOk = false;
    }

    AuthSession? session;
    try {
      final auth = AuthService();
      session = await auth.currentSession();
      auth.close();
    } catch (_) {
      session = null;
    }

    if (!mounted) return;
    setState(() {
      _healthOk = healthOk;
      _status = healthOk
          ? 'Sakina API is online.'
          : 'API offline — you can still browse guides and cached content.';
      _ready = true;
    });

    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    _continue(session);
  }

  void _continue(AuthSession? session) {
    final app = widget.appState;
    Widget next;
    if (!app.onboardingComplete) {
      next = WelcomeScreen(appState: app);
    } else {
      next = HomeShellScreen(appState: app, session: session);
    }
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => next));
  }

  Future<void> _retry() async {
    setState(() {
      _ready = false;
      _healthOk = null;
      _status = 'Retrying…';
    });
    await _bootstrap();
  }

  @override
  Widget build(BuildContext context) {
    final health = _healthOk;
    return Scaffold(
      backgroundColor: SakinaColors.cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [SakinaColors.navy, SakinaColors.emerald],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.mosque, size: 48, color: Colors.white),
                    const SizedBox(height: 12),
                    Text(
                      'Sakina AI',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Your trusted Islamic companion',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const SafeDisclaimerBanner(compact: true),
              const SizedBox(height: 16),
              if (!_ready)
                const SakinaLoadingState(message: 'Connecting…')
              else ...[
                LuxuryDashboardCard(
                  title: 'Environment',
                  subtitle: _apiBase ?? '—',
                  badges: [
                    StatusBadge(
                      label: health == true ? 'API online' : 'API offline',
                      color: health == true ? SakinaColors.success : SakinaColors.error,
                      icon: health == true ? Icons.check_circle : Icons.warning_amber,
                    ),
                  ],
                ),
                Text(_status, textAlign: TextAlign.center, style: const TextStyle(color: SakinaColors.textSecondary)),
              ],
              const Spacer(),
              if (_ready) ...[
                FilledButton(
                  onPressed: () => _openAuth(login: false),
                  child: const Text('Register'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => _openAuth(login: true),
                  child: const Text('Login'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const TermsPrivacyScreen()),
                  ),
                  child: const Text('Terms & Privacy'),
                ),
                TextButton(onPressed: _retry, child: const Text('Retry health check')),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _openAuth({required bool login}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AccountIntroScreen(
          appState: widget.appState,
          initialLoginMode: login,
        ),
      ),
    );
  }
}
