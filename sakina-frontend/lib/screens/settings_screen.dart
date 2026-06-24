import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../app/app_strings.dart';
import '../config/api_config.dart';
import '../services/auth_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.appState,
    this.session,
    this.onLogout,
  });

  final AppState appState;
  final AuthSession? session;
  final VoidCallback? onLogout;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _customUrl = TextEditingController();
  String _currentBase = ApiConfig.defaultBaseUrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _customUrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final base = await ApiConfig.resolveBaseUrl();
    if (mounted) {
      setState(() {
        _currentBase = base;
        _customUrl.text = base;
      });
    }
  }

  Future<void> _applyPreset(String url) async {
    await ApiConfig.setBaseUrlOverride(url);
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('API base set to $url')),
      );
    }
  }

  Future<void> _saveCustom() async {
    setState(() => _saving = true);
    await ApiConfig.setBaseUrlOverride(_customUrl.text.trim());
    await _load();
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('API base saved.')),
      );
    }
  }

  Future<void> _reset() async {
    await ApiConfig.setBaseUrlOverride(null);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.appState;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('API environment', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Current: $_currentBase'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: () => _applyPreset('http://10.0.2.2:28080/v1'),
                child: const Text('Emulator'),
              ),
              OutlinedButton(
                onPressed: () => _applyPreset('http://localhost:28080/v1'),
                child: const Text('Localhost'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _customUrl,
            decoration: const InputDecoration(
              labelText: 'Custom API base URL',
              border: OutlineInputBorder(),
              hintText: 'http://192.168.x.x:28080/v1',
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              FilledButton(
                onPressed: _saving ? null : _saveCustom,
                child: Text(_saving ? 'Saving…' : 'Save URL'),
              ),
              const SizedBox(width: 8),
              TextButton(onPressed: _reset, child: const Text('Reset')),
            ],
          ),
          const Divider(height: 32),
          const Text('Language', style: TextStyle(fontWeight: FontWeight.bold)),
          DropdownButton<AppLanguage>(
            value: app.language,
            isExpanded: true,
            items: const [
              DropdownMenuItem(value: AppLanguage.english, child: Text('English')),
              DropdownMenuItem(value: AppLanguage.arabic, child: Text('العربية')),
            ],
            onChanged: (v) {
              if (v != null) app.setLanguage(v);
            },
          ),
          if (widget.session != null) ...[
            const Divider(height: 32),
            FilledButton.icon(
              onPressed: widget.onLogout,
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
            ),
          ],
        ],
      ),
    );
  }
}
