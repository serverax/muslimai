import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../config/brand_config.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/pending_review_store.dart';
import '../services/sakina_api.dart';
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

/// Logged-in user dashboard — 12 journey cards.
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

  void _go(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
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
      return const Center(child: CircularProgressIndicator());
    }
    final session = widget.session;
    final tier = _entitlements?['tier']?.toString() ?? 'free';

    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            title: Text(widget.appState.t('appTitle')),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => _go(SettingsScreen(
                  appState: widget.appState,
                  session: session,
                  onLogout: _logout,
                )),
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.all(12),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _identityCard(tier),
                if (_prayerSummary != null) _prayerCard(),
                const SizedBox(height: 8),
                _gridCard(
                  icon: Icons.chat_bubble_outline,
                  title: 'Ask AI Shaikh',
                  onTap: () => _go(ChatScreen(session: session)),
                ),
                _gridCard(
                  icon: Icons.menu_book,
                  title: 'Quran Study',
                  onTap: () => _go(StudyHubScreen(api: api, session: session)),
                ),
                _gridCard(
                  icon: Icons.access_time,
                  title: 'Prayer & Qibla',
                  onTap: () => _go(PrayerHubScreen(api: api, session: session)),
                ),
                _gridCard(
                  icon: Icons.wb_twilight,
                  title: 'Dua Library',
                  onTap: () => _go(DuaLibraryScreen(api: api, loggedIn: true)),
                ),
                _gridCard(
                  icon: Icons.bookmark,
                  title: 'Bookmarks',
                  onTap: () => _go(BookmarksScreen(api: api)),
                ),
                _gridCard(
                  icon: Icons.notifications,
                  title: 'Reminders',
                  onTap: () => _go(RemindersScreen(api: api)),
                ),
                _gridCard(
                  icon: Icons.child_care,
                  title: 'Kids Learning',
                  onTap: () => _go(KidsLearningScreen(api: api, loggedIn: true)),
                ),
                _gridCard(
                  icon: Icons.calculate,
                  title: 'Zakat Calculator',
                  onTap: () => _go(CalculatorsScreen(api: api, initialTab: 0)),
                ),
                _gridCard(
                  icon: Icons.family_restroom,
                  title: 'Mirath Calculator',
                  onTap: () => _go(CalculatorsScreen(api: api, initialTab: 1)),
                ),
                _gridCard(
                  icon: Icons.workspace_premium,
                  title: 'Subscription',
                  onTap: () => _go(SubscriptionScreen(session: session)),
                ),
                _gridCard(
                  icon: Icons.gavel,
                  title: 'Scholar Review',
                  subtitle: _pendingReviews > 0 ? '$_pendingReviews pending' : null,
                  onTap: () => _go(ScholarReviewsScreen(session: session)),
                ),
                if (_scholarAccess)
                  _gridCard(
                    icon: Icons.school,
                    title: 'Scholar Dashboard',
                    onTap: () => _go(ScholarDashboardScreen(session: session)),
                  ),
                _gridCard(
                  icon: Icons.admin_panel_settings,
                  title: 'Admin Tools',
                  onTap: () => _go(AdminToolsScreen(session: session)),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout),
                  label: Text('Logout (${session.email})'),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _identityCard(String tier) {
    return Card(
      color: const Color(SakinaBrand.colorPrimary),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const CircleAvatar(
              backgroundColor: Colors.white24,
              child: Icon(Icons.mosque, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Sakina AI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  Text(widget.session.email, style: const TextStyle(color: Colors.white70)),
                  Text('Plan: $tier', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _prayerCard() {
    final p = _prayerSummary!;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.access_time, color: Color(SakinaBrand.colorPrimary)),
        title: const Text('Today\'s prayer times'),
        subtitle: Text(
          'Fajr ${p['fajr']} · Dhuhr ${p['dhuhr']} · Asr ${p['asr']} · Maghrib ${p['maghrib']} · Isha ${p['isha']}',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _go(PrayerHubScreen(api: _api!, session: widget.session)),
      ),
    );
  }

  Widget _gridCard({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(SakinaBrand.colorAccent),
          child: Icon(icon, color: const Color(SakinaBrand.colorPrimary)),
        ),
        title: Text(title),
        subtitle: subtitle != null ? Text(subtitle) : null,
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
