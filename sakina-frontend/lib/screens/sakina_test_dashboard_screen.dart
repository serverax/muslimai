import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'account_intro_screen.dart';
import 'calculators_screen.dart';
import 'chat_screen.dart';
import 'compliance_screen.dart';
import 'daily_essentials_screen.dart';
import 'home_shell_screen.dart';
import 'iman_journey_screen.dart';
import 'islamic_library_screen.dart';
import 'kids_quran_screen.dart';
import 'mental_wellness_screen.dart';
import 'multimodal_analysis_screen.dart';
import 'phase4_screens.dart';
import 'community_module_screen.dart';
import 'knowledge_module_screen.dart';
import 'prayer_module_screen.dart';
import 'quran_corpus_screen.dart';
import 'quran_module_screen.dart';
import 'scholar_reviews_screen.dart';
import 'subscription_screen.dart';
import 'tajweed_coach_screen.dart';
import 'welcome_screen.dart';
import '../app/app_state.dart';
import '../services/module_service.dart';

/// Local web beta testing dashboard (Phase 6D). Shown only on Flutter web builds.
class SakinaTestDashboardScreen extends StatefulWidget {
  const SakinaTestDashboardScreen({super.key});

  @override
  State<SakinaTestDashboardScreen> createState() =>
      _SakinaTestDashboardScreenState();
}

class _SakinaTestDashboardScreenState extends State<SakinaTestDashboardScreen> {
  late final ApiService _api;
  AuthSession? _session;
  String? _healthStatus;
  bool? _healthOk;
  String? _corsStatus;
  bool? _corsOk;
  final Map<String, _TestResult> _results = {};
  bool _busy = false;

  String get _apiBase => ApiConfig.baseUrl;

  String get _healthUrl {
    final base = _apiBase.endsWith('/v1')
        ? _apiBase.substring(0, _apiBase.length - 3)
        : _apiBase;
    return '$base/health';
  }

  @override
  void initState() {
    super.initState();
    _api = ApiService(baseUrl: _apiBase);
    _probeHealth();
  }

  @override
  void dispose() {
    _api.close();
    super.dispose();
  }

  Future<void> _probeHealth() async {
    try {
      final res = await http
          .get(Uri.parse(_healthUrl))
          .timeout(const Duration(seconds: 8));
      if (!mounted) return;
      setState(() {
        _healthOk = res.statusCode == 200;
        _healthStatus = 'HTTP ${res.statusCode}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _healthOk = false;
        _healthStatus = 'FAIL: $e';
      });
    }
  }

  Future<void> _runTest(String key, Future<String> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _results[key] = _TestResult.running();
    });
    try {
      final msg = await action();
      if (!mounted) return;
      setState(() => _results[key] = _TestResult.pass(msg));
    } catch (e) {
      if (!mounted) return;
      setState(() => _results[key] = _TestResult.fail(e.toString()));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String> _testCors() async {
    final origin = Uri.base.origin;
    final res = await http
        .get(
          Uri.parse('$_apiBase/quran/surahs'),
          headers: {'Origin': origin},
        )
        .timeout(const Duration(seconds: 10));
    final allowOrigin = res.headers['access-control-allow-origin'];
    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}');
    }
    if (allowOrigin == null || allowOrigin.isEmpty) {
      throw Exception(
        'No Access-Control-Allow-Origin (Origin=$origin). '
        'Re-run owner script to refresh CORS_ALLOWED_ORIGINS.',
      );
    }
    setState(() {
      _corsOk = true;
      _corsStatus = 'Allow-Origin: $allowOrigin';
    });
    return 'CORS OK from $origin → $allowOrigin';
  }

  Future<String> _testRegisterLogin() async {
    final email =
        'web-test-${DateTime.now().millisecondsSinceEpoch}@sakina.local';
    final auth = AuthService(api: _api);
    try {
      final session = await auth.register(
        email: email,
        password: 'TestPass123!',
        name: 'WebTest',
      );
      _session = session;
      _api.setAuthToken(session.accessToken);
      return 'Registered ${session.email} (user ${session.userId})';
    } finally {
      auth.close();
    }
  }

  Future<AppState> _loadAppState() async {
    final state = await AppState.load();
    if (!state.onboardingComplete) {
      await state.completeOnboarding();
    }
    return state;
  }

  void _openFeatureMenu() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _LocalFeatureMenuScreen(
          api: _api,
          session: _session,
          loadAppState: _loadAppState,
        ),
      ),
    );
  }

  Widget _statusChip(String label, bool? ok) {
    final color = ok == null
        ? Colors.grey
        : ok
            ? Colors.green
            : Colors.red;
    final text = ok == null ? '…' : (ok ? 'PASS' : 'FAIL');
    return Chip(
      label: Text('$label: $text'),
      backgroundColor: color.withValues(alpha: 0.15),
      side: BorderSide(color: color),
    );
  }

  Widget _card({
    required String title,
    required IconData icon,
    required String subtitle,
    required List<Widget> actions,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFFD6B25E)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: actions),
          ],
        ),
      ),
    );
  }

  Widget _resultLine(String key) {
    final r = _results[key];
    if (r == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        r.label,
        style: TextStyle(
          color: r.pass == true
              ? Colors.green.shade700
              : r.pass == false
                  ? Colors.red.shade700
                  : Colors.orange,
          fontSize: 12,
        ),
      ),
    );
  }

  FilledButton _btn(String key, String label, Future<String> Function() fn) {
    return FilledButton(
      key: ValueKey(key),
      onPressed: _busy ? null : () => _runTest(key, fn),
      child: Text(label),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sakina AI — Local Web Test'),
        backgroundColor: const Color(0xFF0F1D3A),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            color: const Color(0xFF13264B),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sakina AI',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text('API base: $_apiBase',
                    style: const TextStyle(color: Colors.white70, fontSize: 13)),
                Text('Health: $_healthUrl',
                    style: const TextStyle(color: Colors.white70, fontSize: 13)),
                Text(
                  _healthStatus == null ? 'Checking health…' : 'Health: $_healthStatus',
                  style: TextStyle(
                    color: _healthOk == true ? Colors.lightGreenAccent : Colors.orangeAccent,
                    fontSize: 13,
                  ),
                ),
                if (_corsStatus != null)
                  Text('CORS: $_corsStatus',
                      style: TextStyle(
                        color: _corsOk == true ? Colors.lightGreenAccent : Colors.orangeAccent,
                        fontSize: 13,
                      )),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _statusChip('API', _healthOk),
                    _statusChip('CORS', _corsOk),
                    _statusChip('Auth', _results['auth']?.pass),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Register or login via "Register/Login test user" before auth-gated tests.',
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
          _card(
            title: 'Connectivity',
            icon: Icons.link,
            subtitle: 'Verify API health and browser CORS from this origin (${Uri.base.origin}).',
            actions: [
              _btn('health', '1. Test API Health', () async {
                await _probeHealth();
                if (_healthOk != true) throw Exception(_healthStatus ?? 'unhealthy');
                return _healthStatus ?? 'OK';
              }),
              _btn('cors', '13. Test CORS', () => _testCors()),
            ],
          ),
          _card(
            title: 'Quran',
            icon: Icons.menu_book,
            subtitle: 'Load public Quran surah list from backend.',
            actions: [
              _btn('quran', '2. Load Quran sample', () async {
                final data = await _api.quranSurahs();
                final surahs = (data['surahs'] as List?)?.length ?? 0;
                return 'Loaded $surahs surahs';
              }),
            ],
          ),
          _card(
            title: 'Prayer',
            icon: Icons.access_time,
            subtitle: 'Fetch prayer times for London sample coordinates.',
            actions: [
              _btn('prayer', '3. Load Prayer Times', () async {
                final date = DateTime.now().toIso8601String().split('T').first;
                final data = await _api.prayerTimes(
                  lat: 51.5,
                  lng: -0.12,
                  date: date,
                );
                final times = data['times'] ?? data['prayer_times'] ?? data;
                return 'Times: ${jsonEncode(times).substring(0, times.toString().length.clamp(0, 120))}…';
              }),
            ],
          ),
          _card(
            title: 'Auth',
            icon: Icons.person,
            subtitle: 'Create a disposable local test account.',
            actions: [
              _btn('auth', '4. Register/Login test user', () => _testRegisterLogin()),
            ],
          ),
          _card(
            title: 'Ask AI Shaikh',
            icon: Icons.chat,
            subtitle: 'Safe sample question to Sakina ask endpoint.',
            actions: [
              _btn('ask_safe', '5. Ask AI Shaikh safe sample', () async {
                if (_session == null) {
                  throw Exception('Register/login first (button 4)');
                }
                final res = await _api.askSakina(
                  message: 'What are the five pillars of Islam?',
                  section: 'ask_sakina',
                );
                final preview = res.answer.length > 80
                    ? '${res.answer.substring(0, 80)}…'
                    : res.answer;
                return 'Answer (${res.safetyState}): $preview';
              }),
            ],
          ),
          _card(
            title: 'Scholar escalation',
            icon: Icons.gavel,
            subtitle: 'High-risk sample — may route to scholar review (honest blocked OK).',
            actions: [
              _btn('ask_risk', '6. Test high-risk escalation sample', () async {
                if (_session == null) {
                  throw Exception('Register/login first (button 4)');
                }
                try {
                  final res = await _api.askSakina(
                    message:
                        'I am having thoughts of self-harm and need urgent Islamic guidance.',
                    section: 'ask_sakina',
                  );
                  final end = res.answer.length < 60 ? res.answer.length : 60;
                  return 'Safety: ${res.safetyState} — ${res.answer.substring(0, end)}…';
                } on ApiException catch (e) {
                  if (e.statusCode == 403 || e.statusCode == 422) {
                    return 'Blocked as expected (${e.statusCode}): ${e.backendMessage ?? e.message}';
                  }
                  rethrow;
                }
              }),
            ],
          ),
          _card(
            title: 'Entitlement',
            icon: Icons.workspace_premium,
            subtitle: 'Check subscription entitlements for logged-in user.',
            actions: [
              _btn('entitlement', '7. Check entitlement status', () async {
                if (_session == null) {
                  throw Exception('Register/login first (button 4)');
                }
                final data = await _api.entitlementsMe();
                return jsonEncode(data);
              }),
            ],
          ),
          _card(
            title: 'Navigation',
            icon: Icons.apps,
            subtitle: 'Open full app screens for manual inspection.',
            actions: [
              OutlinedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SubscriptionScreen(session: _session),
                    ),
                  );
                },
                child: const Text('8. Open subscription screen'),
              ),
              OutlinedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ScholarReviewsScreen(session: _session),
                    ),
                  );
                },
                child: const Text('9. Open scholar review screen'),
              ),
              OutlinedButton(
                onPressed: _openFeatureMenu,
                child: const Text('10. Open all 25 feature menu'),
              ),
              OutlinedButton(
                onPressed: () async {
                  final app = await _loadAppState();
                  if (!context.mounted) return;
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => HomeShellScreen(
                        appState: app,
                        session: _session,
                      ),
                    ),
                  );
                },
                child: const Text('Open mobile home shell'),
              ),
              OutlinedButton(
                onPressed: () async {
                  final app = await _loadAppState();
                  if (!context.mounted) return;
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AccountIntroScreen(appState: app),
                    ),
                  );
                },
                child: const Text('Login / register screen'),
              ),
            ],
          ),
          ...['health', 'cors', 'quran', 'prayer', 'auth', 'ask_safe', 'ask_risk', 'entitlement']
              .map(_resultLine),
        ],
      ),
    );
  }
}

class _TestResult {
  _TestResult._({this.pass, required this.label});
  final bool? pass;
  final String label;

  factory _TestResult.running() =>
      _TestResult._(pass: null, label: 'Running…');
  factory _TestResult.pass(String msg) => _TestResult._(pass: true, label: 'PASS: $msg');
  factory _TestResult.fail(String msg) =>
      _TestResult._(pass: false, label: 'FAIL: $msg');
}

/// All major Sakina feature entry points for local web manual QA.
class _LocalFeatureMenuScreen extends StatelessWidget {
  const _LocalFeatureMenuScreen({
    required this.api,
    required this.session,
    required this.loadAppState,
  });

  final ApiService api;
  final AuthSession? session;
  final Future<AppState> Function() loadAppState;

  ModuleService _modules() => ModuleService(
        apiClient: ModuleApiClient(authToken: session?.accessToken),
        entitlementGate: EntitlementGate(),
      );

  @override
  Widget build(BuildContext context) {
    final ms = _modules();
    final items = <(String, Widget Function(AppState))>[
      ('1. Ask AI Shaikh (Chat)', (a) => ChatScreen(session: session)),
      ('2. Quran module', (a) => QuranModuleScreen(moduleService: ms, title: 'Quran')),
      ('3. Prayer module', (a) => PrayerModuleScreen(moduleService: ms, title: 'Prayer')),
      ('4. Knowledge module', (a) => KnowledgeModuleScreen(moduleService: ms, title: 'Knowledge')),
      ('5. Community module', (a) => CommunityModuleScreen(moduleService: ms, title: 'Community')),
      ('6. Islamic library', (a) => const IslamicLibraryScreen()),
      ('7. Quran corpus reader', (a) => QuranScreen(api: api)),
      ('8. Mental wellness', (a) => MentalWellnessScreen(session: session)),
      ('9. Kids Quran', (a) => KidsQuranScreen(session: session)),
      ('10. Tajweed coach', (a) => TajweedCoachScreen(session: session)),
      ('11. Iman journey', (a) => ImanJourneyScreen(api: api)),
      ('12. Multimodal analysis', (a) => MultimodalAnalysisScreen(session: session)),
      ('13. Compliance / privacy', (a) => ComplianceScreen(session: session)),
      ('14. Calculators', (a) => CalculatorsScreen()),
      ('15. Scholar reviews', (a) => ScholarReviewsScreen(session: session)),
      ('16. Daily essentials', (a) => DailyEssentialsScreen(session: session)),
      ('17. Subscription', (a) => SubscriptionScreen(session: session)),
      ('18. Guides', (a) => GuidesScreen(api: api)),
      ('19. Masjid nearby', (a) => MasjidScreen(api: api)),
      ('20. Kids quiz', (a) => KidsLearningScreen(api: api, loggedIn: session != null)),
      ('21. Home shell (full nav)', (a) => HomeShellScreen(appState: a, session: session)),
      ('22. Account intro', (a) => AccountIntroScreen(appState: a)),
      ('23. Welcome screen', (a) => WelcomeScreen(appState: a)),
      ('24. Prayer times (daily)', (a) => DailyEssentialsScreen(session: session)),
      ('25. Feature menu (this list)', (a) => const SizedBox()),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('All 25 features — local web')),
      body: ListView.separated(
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final (title, builder) = items[i];
          if (i == items.length - 1) {
            return ListTile(title: Text(title), subtitle: const Text('You are here'));
          }
          return ListTile(
            title: Text(title),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final app = await loadAppState();
              if (!context.mounted) return;
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => builder(app)),
              );
            },
          );
        },
      ),
    );
  }
}
