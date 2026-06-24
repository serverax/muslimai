import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../app/app_state.dart';
import '../config/api_config.dart';
import '../design/sakina_colors.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/feature_service.dart';
import '../services/sakina_api.dart';
import '../widgets/luxury/luxury_components.dart';
import 'account_intro_screen.dart';
import 'daily_essentials_screen.dart';
import 'phase4_screens.dart';
import 'prayer_hub_screen.dart';
import 'study_hub_screen.dart';
import 'subscription_screen.dart';

/// Guest home — public features with luxury design and feature gates.
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
    await FeatureService.instance.load(api);
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

  void _gate(String featureKey, Widget Function() screen) {
    FeatureService.instance.navigateToFeature(
      context: context,
      featureKey: featureKey,
      appState: widget.appState,
      session: null,
      entitlements: null,
      isAdmin: false,
      isScholar: false,
      onAllowed: screen,
    );
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

  @override
  Widget build(BuildContext context) {
    final api = _api;
    if (api == null) {
      return const SakinaLoadingState(message: 'Loading…');
    }

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.appState.t('appTitle')),
              Text('Trusted Islamic companion', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          actions: [
            _HealthDot(ok: _healthOk),
            TextButton(onPressed: () => _login(register: true), child: const Text('Register')),
            TextButton(onPressed: () => _login(), child: const Text('Login')),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              LuxuryDashboardCard(
                title: 'As-salamu alaykum',
                subtitle: 'Browse Quran, prayer times, duas, and guides as a guest.',
                gradient: true,
                badges: const [RoleBadge(role: SakinaRole.guest)],
              ),
              const SafeDisclaimerBanner(compact: true),
              const IslamicSectionHeader(title: 'Explore as guest'),
              FeatureTile(
                icon: Icons.menu_book,
                title: 'Quran Study',
                subtitle: 'Read & search with sources',
                onTap: () => _gate('quran_reader', () => StudyHubScreen(api: api)),
              ),
              FeatureTile(
                icon: Icons.access_time,
                title: 'Prayer & Qibla',
                subtitle: 'Times, Qibla, calendar',
                onTap: () => _gate('prayer_times', () => PrayerHubScreen(api: api)),
              ),
              FeatureTile(
                icon: Icons.wb_twilight,
                title: 'Dua Library',
                onTap: () => _gate('dua_library', () => DuaLibraryScreen(api: api)),
              ),
              FeatureTile(
                icon: Icons.article_outlined,
                title: 'Islamic Guides',
                onTap: () => _gate('new_muslim_guide', () => GuidesScreen(api: api)),
              ),
              FeatureTile(
                icon: Icons.workspace_premium,
                title: 'Subscription Plans',
                onTap: () => _gate('subscription', () => SubscriptionScreen()),
              ),
              const IslamicSectionHeader(title: 'Requires login'),
              FeatureTile(
                icon: Icons.bookmark,
                title: 'Bookmarks',
                onTap: () => _gate('bookmarks', () => BookmarksScreen(api: api)),
              ),
              FeatureTile(
                icon: Icons.notifications,
                title: 'Reminders',
                onTap: () => _gate('reminders', () => RemindersScreen(api: api)),
              ),
              FeatureTile(
                icon: Icons.chat_bubble,
                title: 'Ask AI Shaikh',
                onTap: () => _gate('ask_ai_shaikh', () => const SizedBox()),
              ),
              const SizedBox(height: 8),
              Text('API: $_apiBase', style: const TextStyle(fontSize: 11, color: SakinaColors.textSecondary)),
            ]),
          ),
        ),
      ],
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
            ? SakinaColors.success
            : SakinaColors.error;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Icon(Icons.circle, size: 10, color: color),
    );
  }
}
