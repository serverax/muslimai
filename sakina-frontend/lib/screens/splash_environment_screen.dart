import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../app/app_state.dart';
import '../config/api_config.dart';
import '../services/auth_service.dart';
import 'account_intro_screen.dart';
import 'home_shell_screen.dart';
import 'welcome_screen.dart';

/// Splash + API health probe, then route to welcome/guest/logged-in shell.
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
      _status = healthOk ? 'Sakina API is online.' : 'API offline — you can still browse cached guides.';
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
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => next),
    );
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Text(
                'Sakina AI',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1B6B5E),
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Your Muslim companion',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 32),
              if (!_ready)
                const Center(child: CircularProgressIndicator())
              else ...[
                _infoRow('API base', _apiBase ?? '—'),
                _infoRow(
                  'Health',
                  health == true ? 'Online' : 'Offline',
                  color: health == true ? Colors.green : Colors.orange,
                ),
                const SizedBox(height: 12),
                Text(_status, textAlign: TextAlign.center),
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
                  onPressed: _retry,
                  child: const Text('Retry health check'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
          Expanded(child: Text(value, style: TextStyle(color: color))),
        ],
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
