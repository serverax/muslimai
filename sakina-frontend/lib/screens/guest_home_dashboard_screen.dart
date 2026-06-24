import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../app/app_state.dart';
import '../config/api_config.dart';
import '../config/brand_config.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/sakina_api.dart';
import '../widgets/workflow_states.dart';
import 'account_intro_screen.dart';
import 'daily_essentials_screen.dart';
import 'phase4_screens.dart';
import 'prayer_hub_screen.dart';
import 'study_hub_screen.dart';
import 'subscription_screen.dart';

/// Guest home — public features without login.
class GuestHomeDashboardScreen extends StatefulWidget {
  const GuestHomeDashboardScreen({
    super.key,
    required this.appState,
    this.onLoggedIn,
  });

  final AppState appState;
  final void Function(AuthSession session)? onLoggedIn;

  @override
  State<GuestHomeDashboardScreen> createState() => _GuestHomeDashboardScreenState();
}

class _GuestHomeDashboardScreenState extends State<GuestHomeDashboardScreen> {
  ApiService? _api;
  bool? _healthOk;
  String _apiBase = ApiConfig.defaultBaseUrl;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final base = await ApiConfig.resolveBaseUrl();
    final api = await SakinaApi.create();
    bool ok = false;
    try {
      final res = await http
          .get(Uri.parse(ApiConfig.healthUrlFor(base)))
          .timeout(const Duration(seconds: 6));
      ok = res.statusCode == 200;
    } catch (_) {}
    if (mounted) {
      setState(() {
        _api = api;
        _apiBase = base;
        _healthOk = ok;
      });
    }
  }

  void _go(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  void _login({bool register = false}) async {
    final session = await Navigator.of(context).push<AuthSession>(
      MaterialPageRoute(
        builder: (_) => AccountIntroScreen(
          appState: widget.appState,
          initialLoginMode: !register,
          returnSessionOnSuccess: true,
          onAuthenticated: widget.onLoggedIn,
        ),
      ),
    );
    if (session != null) {
      widget.onLoggedIn?.call(session);
    }
  }

  void _protected(String name, Widget Function(AuthSession) builder) {
    _go(LoginRequiredScreen(
      appState: widget.appState,
      featureName: name,
      onLoggedIn: widget.onLoggedIn,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final api = _api;
    if (api == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.appState.t('appTitle')),
              Text(
                SakinaBrand.tagline,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          actions: [
            _HealthDot(ok: _healthOk),
            TextButton(onPressed: () => _login(register: true), child: const Text('Register')),
            TextButton(onPressed: _login, child: const Text('Login')),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.all(12),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _headerCard(),
              _section('Explore as guest'),
              _card(Icons.menu_book, 'Quran Study', 'Read & search with sources',
                  () => _go(StudyHubScreen(api: api))),
              _card(Icons.access_time, 'Prayer & Qibla', 'Times, Qibla, calendar',
                  () => _go(PrayerHubScreen(api: api))),
              _card(Icons.wb_twilight, 'Dua Library', 'Search duas',
                  () => _go(DuaLibraryScreen(api: api))),
              _card(Icons.article_outlined, 'Islamic Guides', 'Wudu, Salah, Ramadan, Hajj',
                  () => _go(GuidesScreen(api: api))),
              _card(Icons.workspace_premium, 'Subscription Plans', 'Free vs premium preview',
                  () => _go(SubscriptionScreen())),
              _section('Requires login'),
              _card(Icons.bookmark, 'Bookmarks', 'Save your favourites',
                  () => _protected('Bookmarks', (s) => BookmarksScreen(api: api))),
              _card(Icons.notifications, 'Reminders', 'Prayer & study reminders',
                  () => _protected('Reminders', (s) => RemindersScreen(api: api))),
              _card(Icons.chat_bubble, 'Ask AI Shaikh', 'Personalised guidance',
                  () => _protected('Ask AI Shaikh', (_) => const SizedBox())),
              const SizedBox(height: 8),
              Text('API: $_apiBase', style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _headerCard() {
    return Card(
      color: const Color(SakinaBrand.colorPrimary),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'As-salamu alaykum',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              'Browse Quran, prayer times, duas, and guides without an account.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
        child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      );

  Widget _card(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(SakinaBrand.colorAccent),
          child: Icon(icon, color: const Color(SakinaBrand.colorPrimary)),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _HealthDot extends StatelessWidget {
  const _HealthDot({this.ok});
  final bool? ok;
  @override
  Widget build(BuildContext context) {
    final color = ok == null
        ? Colors.grey
        : ok!
            ? Colors.green
            : Colors.orange;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Icon(Icons.circle, size: 10, color: color),
    );
  }
}
