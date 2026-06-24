import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../services/auth_service.dart';
import 'admin_tools_screen.dart';
import 'calculators_screen.dart';
import 'phase4_screens.dart';
import 'scholar_dashboard_screen.dart';
import 'scholar_reviews_screen.dart';
import 'settings_screen.dart';
import 'subscription_screen.dart';
import '../services/sakina_api.dart';

class MoreMenuScreen extends StatelessWidget {
  const MoreMenuScreen({
    super.key,
    required this.appState,
    this.session,
    this.onLogout,
  });

  final AppState appState;
  final AuthSession? session;
  final VoidCallback? onLogout;

  void _go(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: FutureBuilder(
        future: SakinaApi.create(session: session),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final api = snapshot.data!;
          return ListView(
            children: [
              _tile(context, Icons.calculate, 'Zakat & Mirath', () => _go(context, CalculatorsScreen(api: api))),
              _tile(context, Icons.child_care, 'Kids Learning',
                  () => _go(context, KidsLearningScreen(api: api, loggedIn: session != null))),
              _tile(context, Icons.article_outlined, 'Guides',
                  () => _go(context, GuidesScreen(api: api))),
              _tile(context, Icons.workspace_premium, 'Subscription',
                  () => _go(context, SubscriptionScreen(session: session))),
              if (session != null)
                _tile(context, Icons.gavel, 'Scholar Reviews',
                    () => _go(context, ScholarReviewsScreen(session: session))),
              if (session != null)
                _tile(context, Icons.school, 'Scholar Dashboard',
                    () => _go(context, ScholarDashboardScreen(session: session!))),
              _tile(context, Icons.admin_panel_settings, 'Admin Tools',
                  () => _go(context, AdminToolsScreen(session: session))),
              _tile(context, Icons.settings, 'Settings',
                  () => _go(context, SettingsScreen(
                        appState: appState,
                        session: session,
                        onLogout: onLogout,
                      ))),
            ],
          );
        },
      ),
    );
  }

  Widget _tile(BuildContext context, IconData icon, String title, VoidCallback onTap) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
