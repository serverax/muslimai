import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../services/auth_service.dart';
import 'chat_screen.dart';
import 'guest_home_dashboard_screen.dart';
import 'mobile_home_dashboard_screen.dart';
import 'more_menu_screen.dart';
import 'prayer_hub_screen.dart';
import 'study_hub_screen.dart';
import '../services/sakina_api.dart';

/// Mobile shell — 5-tab navigation with guest or logged-in home.
class HomeShellScreen extends StatefulWidget {
  const HomeShellScreen({
    super.key,
    required this.appState,
    this.session,
  });

  final AppState appState;
  final AuthSession? session;

  @override
  State<HomeShellScreen> createState() => _HomeShellScreenState();
}

class _HomeShellScreenState extends State<HomeShellScreen> {
  int _index = 0;
  AuthSession? _session;

  @override
  void initState() {
    super.initState();
    _session = widget.session;
  }

  void _onLoggedIn(AuthSession session) {
    setState(() => _session = session);
  }

  void _onLogout() {
    setState(() {
      _session = null;
      _index = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.appState;
    final session = _session;

    final home = session != null
        ? MobileHomeDashboardScreen(
            appState: app,
            session: session,
            onLogout: _onLogout,
          )
        : GuestHomeDashboardScreen(
            appState: app,
            onLoggedIn: _onLoggedIn,
          );

    return FutureBuilder(
      future: SakinaApi.create(session: session),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(title: Text(app.t('appTitle'))),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final api = snapshot.data!;
        final screens = [
          home,
          ChatScreen(session: session, api: api),
          StudyHubScreen(api: api, session: session),
          PrayerHubScreen(api: api, session: session),
          MoreMenuScreen(appState: app, session: session, onLogout: _onLogout),
        ];

        return Scaffold(
          body: IndexedStack(index: _index, children: screens),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.chat_bubble_outline),
                selectedIcon: Icon(Icons.chat_bubble),
                label: 'Ask AI',
              ),
              NavigationDestination(
                icon: Icon(Icons.menu_book_outlined),
                selectedIcon: Icon(Icons.menu_book),
                label: 'Study',
              ),
              NavigationDestination(
                icon: Icon(Icons.access_time),
                selectedIcon: Icon(Icons.access_time_filled),
                label: 'Daily',
              ),
              NavigationDestination(
                icon: Icon(Icons.more_horiz),
                selectedIcon: Icon(Icons.more_horiz),
                label: 'More',
              ),
            ],
          ),
        );
      },
    );
  }
}
