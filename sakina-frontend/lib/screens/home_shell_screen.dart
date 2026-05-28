import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../app/feature_flags.dart';
import '../services/module_service.dart';
import 'chat_screen.dart';
import 'community_module_screen.dart';
import 'knowledge_module_screen.dart';
import 'phase2_placeholder_screen.dart';
import 'prayer_module_screen.dart';
import 'quran_module_screen.dart';

class HomeShellScreen extends StatefulWidget {
  const HomeShellScreen({super.key, required this.appState});

  final AppState appState;

  @override
  State<HomeShellScreen> createState() => _HomeShellScreenState();
}

class _HomeShellScreenState extends State<HomeShellScreen> {
  int _index = 0;
  late final ModuleService _moduleService;

  @override
  void initState() {
    super.initState();
    _moduleService = ModuleService(
      apiClient: ModuleApiClient(),
      entitlementGate: EntitlementGate(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.appState;
    final screens = [
      const ChatScreen(),
      FeatureFlags.quran
          ? QuranModuleScreen(
              moduleService: _moduleService, title: app.t('quran'))
          : Phase2PlaceholderScreen(title: app.t('quran'), appState: app),
      FeatureFlags.prayer
          ? PrayerModuleScreen(
              moduleService: _moduleService,
              title: app.t('prayer'),
            )
          : Phase2PlaceholderScreen(title: app.t('prayer'), appState: app),
      FeatureFlags.community
          ? CommunityModuleScreen(
              moduleService: _moduleService,
              title: app.t('community'),
            )
          : Phase2PlaceholderScreen(title: app.t('community'), appState: app),
      FeatureFlags.knowledge
          ? KnowledgeModuleScreen(
              moduleService: _moduleService,
              title: app.t('knowledge'),
            )
          : Phase2PlaceholderScreen(title: app.t('knowledge'), appState: app),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(app.t('appTitle')),
      ),
      body: screens[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.chat_bubble_outline),
            selectedIcon: const Icon(Icons.chat_bubble),
            label: app.t('chat'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.menu_book_outlined),
            selectedIcon: const Icon(Icons.menu_book),
            label: app.t('quran'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.access_time),
            selectedIcon: const Icon(Icons.access_time_filled),
            label: app.t('prayer'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.groups_outlined),
            selectedIcon: const Icon(Icons.groups),
            label: app.t('community'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.school_outlined),
            selectedIcon: const Icon(Icons.school),
            label: app.t('knowledge'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _moduleService.close();
    super.dispose();
  }
}
