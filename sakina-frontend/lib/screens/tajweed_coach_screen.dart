import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../config/api_config.dart';

class TajweedCoachScreen extends StatefulWidget {
  TajweedCoachScreen({
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
  State<TajweedCoachScreen> createState() => _TajweedCoachScreenState();
}

class _TajweedCoachScreenState extends State<TajweedCoachScreen> {
  bool _recording = false;
  String _feedback = 'Select a letter or rule to practice.';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Makharij & Tajweed Coach'),
        backgroundColor: Colors.indigo.shade50,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              height: 200,
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.indigo.shade100),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.face, size: 80, color: Colors.indigo.shade300),
                    const SizedBox(height: 8),
                    const Text('Makharij Diagram Placeholder'),
                    const Text('Showing tongue position for "Qaf"', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _feedback,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ActionButton(
                  icon: _recording ? Icons.stop : Icons.mic,
                  label: _recording ? 'Stop' : 'Practice Recitation',
                  color: _recording ? Colors.red : Colors.indigo,
                  onTap: () {
                    setState(() {
                      _recording = !_recording;
                      if (!_recording) {
                        _feedback = 'Excellent! Your makhraj for "Qaf" is 92% accurate.';
                      } else {
                        _feedback = 'Listening to your recitation...';
                      }
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 32),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Common Tajweed Rules', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
            _RuleTile(title: 'Idgham', description: 'Merging letters with Ghunnah.', color: Colors.blue),
            _RuleTile(title: 'Ikhfa', description: 'Hiding the sound of Noon Saakin.', color: Colors.teal),
            _RuleTile(title: 'Qalqalah', description: 'Echoing sounds for strong letters.', color: Colors.deepOrange),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(
            radius: 35,
            backgroundColor: color,
            child: Icon(icon, color: Colors.white, size: 30),
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _RuleTile extends StatelessWidget {
  const _RuleTile({
    required this.title,
    required this.description,
    required this.color,
  });

  final String title;
  final String description;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: color.withOpacity(0.2), child: Text(title[0], style: TextStyle(color: color, fontWeight: FontWeight.bold))),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(description),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {},
      ),
    );
  }
}
