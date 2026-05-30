import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../services/module_service.dart';
import 'chat_screen.dart';
import 'module_read_only_state_screen.dart';

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
      ChatScreen(),
      ModuleReadOnlyStateScreen(
        title: app.t('quran'),
        load: _moduleService.quran,
      ),
      ModuleReadOnlyStateScreen(
        title: app.t('prayer'),
        load: _moduleService.prayer,
      ),
      ModuleReadOnlyStateScreen(
        title: app.t('community'),
        load: _moduleService.community,
      ),
      ModuleReadOnlyStateScreen(
        title: app.t('knowledge'),
        load: _moduleService.knowledge,
      ),
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
