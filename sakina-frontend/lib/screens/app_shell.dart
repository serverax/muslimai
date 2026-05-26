import 'package:flutter/material.dart';

import '../design/patterns/girih_pattern.dart';
import '../design/sakina_luxury.dart';
import '../design/tokens.dart';
import '../l10n/app_localizations.dart';
import 'chat_screen.dart';

class SakinaShell extends StatefulWidget {
  const SakinaShell({super.key});

  @override
  State<SakinaShell> createState() => _SakinaShellState();
}

class _SakinaShellState extends State<SakinaShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          const HomeDashboard(),
          PlaceholderTab(
            title: l10n.tutoring,
            icon: Icons.school_outlined,
            summary: l10n.tutoringSummary,
          ),
          PlaceholderTab(
            title: l10n.quran,
            icon: Icons.menu_book_outlined,
            summary: l10n.quranSummary,
          ),
          PlaceholderTab(
            title: l10n.prayer,
            icon: Icons.mosque_outlined,
            summary: l10n.prayerSummary,
          ),
          PlaceholderTab(
            title: l10n.parent,
            icon: Icons.family_restroom_outlined,
            summary: l10n.parentSummary,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: l10n.home,
          ),
          NavigationDestination(
            icon: const Icon(Icons.school_outlined),
            selectedIcon: const Icon(Icons.school),
            label: l10n.tutoring,
          ),
          NavigationDestination(
            icon: const Icon(Icons.menu_book_outlined),
            selectedIcon: const Icon(Icons.menu_book),
            label: l10n.quran,
          ),
          NavigationDestination(
            icon: const Icon(Icons.mosque_outlined),
            selectedIcon: const Icon(Icons.mosque),
            label: l10n.prayer,
          ),
          NavigationDestination(
            icon: const Icon(Icons.family_restroom_outlined),
            selectedIcon: const Icon(Icons.family_restroom),
            label: l10n.parent,
          ),
        ],
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
    final l10n = AppLocalizations.of(context);
    final luxury = theme.extension<SakinaLuxury>()!;
    return IslamicPatternBackground(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(SakinaSpacing.lg),
          children: [
            Text(
              l10n.home,
              style: theme.textTheme.headlineMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: SakinaSpacing.sm),
            Text(
              l10n.homeSummary,
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
                title: Text(l10n.askSakina),
                subtitle: Text(l10n.openCompanionChat),
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
            _DashboardTile(
              icon: Icons.school_outlined,
              title: l10n.continueLearning,
              subtitle: l10n.continueLearningSummary,
            ),
            _DashboardTile(
              icon: Icons.menu_book_outlined,
              title: l10n.quranFocus,
              subtitle: l10n.quranFocusSummary,
            ),
            _DashboardTile(
              icon: Icons.mosque_outlined,
              title: l10n.prayerRhythm,
              subtitle: l10n.prayerRhythmSummary,
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
