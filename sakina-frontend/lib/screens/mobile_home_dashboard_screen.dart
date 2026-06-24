import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../design/sakina_colors.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/feature_service.dart';
import '../services/pending_review_store.dart';
import '../services/sakina_api.dart';
import '../widgets/luxury/luxury_components.dart';
import 'admin_tools_screen.dart';
import 'calculators_screen.dart';
import 'chat_screen.dart';
import 'daily_essentials_screen.dart';
import 'phase4_screens.dart';
import 'prayer_hub_screen.dart';
import 'scholar_dashboard_screen.dart';
import 'scholar_reviews_screen.dart';
import 'settings_screen.dart';
import 'study_hub_screen.dart';
import 'subscription_screen.dart';

/// Logged-in user dashboard — luxury journey cards with feature gates.
class MobileHomeDashboardScreen extends StatefulWidget {
  const MobileHomeDashboardScreen({
    super.key,
    required this.appState,
    required this.session,
    this.onLogout,
  });

  final AppState appState;
  final AuthSession session;
  final VoidCallback? onLogout;

  @override
  State<MobileHomeDashboardScreen> createState() => _MobileHomeDashboardScreenState();
}

class _MobileHomeDashboardScreenState extends State<MobileHomeDashboardScreen> {
  ApiService? _api;
  Map<String, dynamic>? _entitlements;
  Map<String, dynamic>? _prayerSummary;
  int _pendingReviews = 0;
  bool _scholarAccess = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = await SakinaApi.create(session: widget.session);
    await FeatureService.instance.load(api);
    Map<String, dynamic>? ent;
    Map<String, dynamic>? prayer;
    int pending = 0;
    bool scholar = false;
    try {
      ent = await api.entitlementsMe();
    } catch (_) {}
    try {
      final now = DateTime.now();
      final date =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      prayer = await api.prayerTimes(lat: 51.5074, lng: -0.1278, date: date, tz: 0);
    } catch (_) {}
    try {
      pending = await PendingReviewStore().pendingCount();
    } catch (_) {}
    try {
      await api.scholarQueue();
      scholar = true;
    } catch (_) {}

    if (mounted) {
      setState(() {
        _api = api;
        _entitlements = ent;
        _prayerSummary = prayer;
        _pendingReviews = pending;
        _scholarAccess = scholar;
      });
    }
  }

  void _gate(String featureKey, Widget Function() screen) {
    FeatureService.instance.navigateToFeature(
      context: context,
      featureKey: featureKey,
      appState: widget.appState,
      session: widget.session,
      entitlements: _entitlements,
      isAdmin: false,
      isScholar: _scholarAccess,
      onAllowed: screen,
    );
  }

  Future<void> _logout() async {
    final auth = AuthService();
    await auth.logout();
    auth.close();
    widget.onLogout?.call();
  }

  @override
  Widget build(BuildContext context) {
    final api = _api;
    if (api == null) {
      return const SakinaLoadingState(message: 'Loading your dashboard…');
    }
    final session = widget.session;
    final tier = _entitlements?['tier']?.toString() ?? 'free';

    return RefreshIndicator(
      onRefresh: _load,
      color: SakinaColors.emerald,
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            title: Text(widget.appState.t('appTitle')),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SettingsScreen(
                      appState: widget.appState,
                      session: session,
                      onLogout: _logout,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                LuxuryDashboardCard(
                  title: 'As-salamu alaykum',
                  subtitle: session.email,
                  gradient: true,
                  badges: [
                    RoleBadge(role: SakinaRole.user),
                    StatusBadge(label: 'Plan: $tier', color: SakinaColors.goldSoft),
                  ],
                  leading: const CircleAvatar(
                    backgroundColor: Colors.white24,
                    child: Icon(Icons.mosque, color: Colors.white),
                  ),
                ),
                if (_prayerSummary != null)
                  FeatureTile(
                    icon: Icons.access_time,
                    title: "Today's prayer times",
                    subtitle:
                        'Fajr ${_prayerSummary!['fajr']} · Dhuhr ${_prayerSummary!['dhuhr']} · Asr ${_prayerSummary!['asr']}',
                    onTap: () => _gate('prayer_times', () => PrayerHubScreen(api: api, session: session)),
                  ),
                const IslamicSectionHeader(title: 'Guidance & study'),
                FeatureTile(
                  icon: Icons.chat_bubble_outline,
                  title: 'Ask AI Shaikh',
                  onTap: () => _gate('ask_ai_shaikh', () => ChatScreen(session: session)),
                ),
                FeatureTile(
                  icon: Icons.menu_book,
                  title: 'Quran Study',
                  onTap: () => _gate('quran_reader', () => StudyHubScreen(api: api, session: session)),
                ),
                const IslamicSectionHeader(title: 'Daily essentials'),
                FeatureTile(
                  icon: Icons.access_time,
                  title: 'Prayer & Qibla',
                  onTap: () => _gate('prayer_times', () => PrayerHubScreen(api: api, session: session)),
                ),
                FeatureTile(
                  icon: Icons.wb_twilight,
                  title: 'Dua Library',
                  onTap: () => _gate('dua_library', () => DuaLibraryScreen(api: api, loggedIn: true)),
                ),
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
                const IslamicSectionHeader(title: 'Family & tools'),
                FeatureTile(
                  icon: Icons.child_care,
                  title: 'Kids Learning',
                  onTap: () => _gate('kids_learning', () => KidsLearningScreen(api: api, loggedIn: true)),
                ),
                FeatureTile(
                  icon: Icons.calculate,
                  title: 'Zakat Calculator',
                  onTap: () => _gate('zakat', () => CalculatorsScreen(api: api, initialTab: 0)),
                ),
                FeatureTile(
                  icon: Icons.family_restroom,
                  title: 'Mirath Calculator',
                  onTap: () => _gate('mirath', () => CalculatorsScreen(api: api, initialTab: 1)),
                ),
                FeatureTile(
                  icon: Icons.workspace_premium,
                  title: 'Subscription',
                  onTap: () => _gate('subscription', () => SubscriptionScreen(session: session)),
                ),
                FeatureTile(
                  icon: Icons.gavel,
                  title: 'Scholar Review',
                  subtitle: _pendingReviews > 0 ? '$_pendingReviews pending' : null,
                  onTap: () => _gate('scholar_review', () => ScholarReviewsScreen(session: session)),
                ),
                if (_scholarAccess)
                  FeatureTile(
                    icon: Icons.school,
                    title: 'Scholar Dashboard',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ScholarDashboardScreen(session: session),
                      ),
                    ),
                  ),
                FeatureTile(
                  icon: Icons.admin_panel_settings,
                  title: 'Admin Tools',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AdminToolsScreen(session: session, appState: widget.appState),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout),
                  label: Text('Logout'),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
