import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'calculators_screen.dart';
import 'daily_essentials_screen.dart';

/// Prayer times, Qibla, calendar, and adhan preferences.
class PrayerHubScreen extends StatefulWidget {
  const PrayerHubScreen({super.key, required this.api, this.session});

  final ApiService api;
  final AuthSession? session;

  @override
  State<PrayerHubScreen> createState() => _PrayerHubScreenState();
}

class _PrayerHubScreenState extends State<PrayerHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prayer & Qibla'),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Prayer'),
            Tab(text: 'Qibla'),
            Tab(text: 'Calendar'),
            Tab(text: 'Adhan'),
          ],
        ),
      ),
      body: Column(
        children: [
          MaterialBanner(
            content: const Text(
              'Location provider not configured. Using manual city mode (default: London).',
            ),
            leading: const Icon(Icons.info_outline),
            backgroundColor: Colors.blue.shade50,
            actions: [TextButton(onPressed: () {}, child: const Text('OK'))],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                PrayerTimesScreen(api: widget.api),
                _QiblaEmbed(api: widget.api),
                IslamicCalendarScreen(api: widget.api),
                const AdhanSettingsScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QiblaEmbed extends StatelessWidget {
  const _QiblaEmbed({required this.api});
  final ApiService api;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.explore, size: 64),
            const SizedBox(height: 16),
            const Text('Qibla direction helper', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Open the full Qibla calculator with latitude and longitude.'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CalculatorsScreen(api: api, initialTab: 2),
                ),
              ),
              child: const Text('Open Qibla'),
            ),
          ],
        ),
      ),
    );
  }
}
