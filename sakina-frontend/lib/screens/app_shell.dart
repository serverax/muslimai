import 'package:flutter/material.dart';

import '../design/patterns/girih_pattern.dart';
import '../design/sakina_luxury.dart';
import '../design/tokens.dart';
import 'chat_screen.dart';

class SakinaShell extends StatefulWidget {
  const SakinaShell({super.key});

  @override
  State<SakinaShell> createState() => _SakinaShellState();
}

class _SakinaShellState extends State<SakinaShell> {
  int _selectedIndex = 0;

  static const _destinations = <NavigationDestination>[
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home),
      label: 'Home',
    ),
    NavigationDestination(
      icon: Icon(Icons.school_outlined),
      selectedIcon: Icon(Icons.school),
      label: 'Tutoring',
    ),
    NavigationDestination(
      icon: Icon(Icons.menu_book_outlined),
      selectedIcon: Icon(Icons.menu_book),
      label: 'Quran',
    ),
    NavigationDestination(
      icon: Icon(Icons.mosque_outlined),
      selectedIcon: Icon(Icons.mosque),
      label: 'Prayer',
    ),
    NavigationDestination(
      icon: Icon(Icons.family_restroom_outlined),
      selectedIcon: Icon(Icons.family_restroom),
      label: 'Parent',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Project Sakina'),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          HomeDashboard(),
          PlaceholderTab(
            title: 'Tutoring',
            icon: Icons.school_outlined,
            summary: 'Personalized lessons and study support.',
          ),
          PlaceholderTab(
            title: 'Quran',
            icon: Icons.menu_book_outlined,
            summary: 'Reading, memorization, and reflection tools.',
          ),
          PlaceholderTab(
            title: 'Prayer',
            icon: Icons.mosque_outlined,
            summary: 'Prayer times, qibla, and worship routines.',
          ),
          PlaceholderTab(
            title: 'Parent',
            icon: Icons.family_restroom_outlined,
            summary: 'Guardian view for progress and settings.',
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        destinations: _destinations,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }
}

class HomeDashboard extends StatelessWidget {
  const HomeDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final luxury = theme.extension<SakinaLuxury>()!;
    return IslamicPatternBackground(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(SakinaSpacing.lg),
          children: [
            Text(
              'Home',
              style: theme.textTheme.headlineMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: SakinaSpacing.sm),
            Text(
              'A calm starting point for guidance, learning, Quran, prayer, and family care.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: SakinaSpacing.lg),
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: SakinaSpacing.lg,
                  vertical: SakinaSpacing.md,
                ),
                leading: CircleAvatar(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  foregroundColor: theme.colorScheme.onPrimaryContainer,
                  child: const Icon(Icons.chat_bubble_outline),
                ),
                title: const Text('Ask Sakina'),
                subtitle: const Text('Open the companion chat'),
                trailing: Icon(
                  Icons.arrow_forward,
                  color: luxury.gold,
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => const ChatScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: SakinaSpacing.md),
            const _DashboardTile(
              icon: Icons.school_outlined,
              title: 'Continue Learning',
              subtitle: 'Resume tutoring sessions from the Tutoring tab.',
            ),
            const _DashboardTile(
              icon: Icons.menu_book_outlined,
              title: 'Quran Focus',
              subtitle: 'Jump into recitation, memorization, and tafsir work.',
            ),
            const _DashboardTile(
              icon: Icons.mosque_outlined,
              title: 'Prayer Rhythm',
              subtitle: 'Keep daily worship visible from the Prayer tab.',
            ),
          ],
        ),
      ),
    );
  }
}

class PlaceholderTab extends StatelessWidget {
  const PlaceholderTab({
    super.key,
    required this.title,
    required this.icon,
    required this.summary,
  });

  final String title;
  final IconData icon;
  final String summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IslamicPatternBackground(
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(SakinaSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 44,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: SakinaSpacing.md),
                Text(
                  title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: SakinaSpacing.sm),
                Text(
                  summary,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardTile extends StatelessWidget {
  const _DashboardTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        leading: Icon(
          icon,
          color: theme.colorScheme.primary,
        ),
        title: Text(title),
        subtitle: Text(subtitle),
      ),
    );
  }
}
