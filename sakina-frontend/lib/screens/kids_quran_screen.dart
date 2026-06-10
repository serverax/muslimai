import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../config/api_config.dart';

class KidsQuranScreen extends StatefulWidget {
  KidsQuranScreen({
    super.key,
    ApiService? api,
    AuthSession? session,
  }) : api = api ?? ApiService(baseUrl: ApiConfig.baseUrl) {
    if (session != null) {
      this.api.setAuthToken(session.accessToken);
    }
  }

  final ApiService api;

  @override
  State<KidsQuranScreen> createState() => _KidsQuranScreenState();
}

class _KidsQuranScreenState extends State<KidsQuranScreen> {
  final List<String> _stories = [
    'The Elephant and the Kaaba',
    'The Story of Prophet Nuh',
    'The Cave of Hira',
    'The First Ayah',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kids Quran World'),
        backgroundColor: Colors.orange.shade100,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.orange.shade50, Colors.white],
          ),
        ),
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Assalamu Alaikum! Let\'s learn Quran together!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: _stories.length + 2,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _KidsCard(
                      title: 'Learn Letters',
                      icon: Icons.abc,
                      color: Colors.blue,
                      onTap: () {},
                    );
                  }
                  if (index == 1) {
                    return _KidsCard(
                      title: 'Short Surahs',
                      icon: Icons.mic_none,
                      color: Colors.green,
                      onTap: () {},
                    );
                  }
                  final story = _stories[index - 2];
                  return _KidsCard(
                    title: story,
                    icon: Icons.auto_stories,
                    color: Colors.purple,
                    onTap: () {},
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KidsCard extends StatelessWidget {
  const _KidsCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: color.withValues(alpha: 0.1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: color),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: color.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
