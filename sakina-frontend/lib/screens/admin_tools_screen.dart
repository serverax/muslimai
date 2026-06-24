import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/sakina_api.dart';
import 'scholar_dashboard_screen.dart';

class AdminToolsScreen extends StatefulWidget {
  const AdminToolsScreen({super.key, this.session});

  final AuthSession? session;

  @override
  State<AdminToolsScreen> createState() => _AdminToolsScreenState();
}

class _AdminToolsScreenState extends State<AdminToolsScreen> {
  ApiService? _api;
  String _apiBase = ApiConfig.defaultBaseUrl;
  Map<String, dynamic>? _health;
  Map<String, dynamic>? _payment;
  Map<String, dynamic>? _entitlements;
  Map<String, dynamic>? _modules;
  String? _adminGrantStatus;
  String? _error;
  bool _loading = true;
  bool _adminApisAvailable = false;

  final _grantUserId = TextEditingController();
  final _grantKey = TextEditingController(text: 'premium');

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _grantUserId.dispose();
    _grantKey.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final base = await ApiConfig.resolveBaseUrl();
      final api = await SakinaApi.create(session: widget.session);
      Map<String, dynamic>? health;
      Map<String, dynamic>? payment;
      Map<String, dynamic>? ent;
      Map<String, dynamic>? modules;
      bool adminOk = false;

      try {
        health = await api.checkHealth();
      } catch (e) {
        health = {'error': e.toString()};
      }
      try {
        payment = await api.paymentProviderStatus();
      } catch (_) {}
      if (widget.session != null) {
        try {
          ent = await api.entitlementsMe();
        } catch (_) {}
      }
      try {
        modules = await api.modulesStatus();
        adminOk = true;
      } catch (_) {}

      if (mounted) {
        setState(() {
          _api = api;
          _apiBase = base;
          _health = health;
          _payment = payment;
          _entitlements = ent;
          _modules = modules;
          _adminApisAvailable = adminOk;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _grant({required bool revoke}) async {
    final api = _api;
    if (api == null || widget.session == null) return;
    setState(() => _adminGrantStatus = null);
    try {
      final userId = _grantUserId.text.trim();
      final key = _grantKey.text.trim();
      if (revoke) {
        await api.adminRevokeEntitlement(userId: userId, entitlementKey: key);
        setState(() => _adminGrantStatus = 'Revoked $key for $userId');
      } else {
        await api.adminGrantEntitlement(userId: userId, entitlementKey: key);
        setState(() => _adminGrantStatus = 'Granted $key to $userId');
      }
    } catch (e) {
      setState(() => _adminGrantStatus = 'Admin grant/revoke unavailable: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin / Owner Tools'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
                _card('API base URL', _apiBase),
                _card('API health', _health?.toString() ?? 'unknown'),
                _card('Payment provider', _payment?.toString() ?? 'not loaded'),
                _card('Your entitlements', _entitlements?.toString() ?? 'login required'),
                _card('Feature gates', _modules?.toString() ?? 'not available'),
                _card(
                  'Session',
                  widget.session != null
                      ? '${widget.session!.email} (${widget.session!.userId})'
                      : 'Not logged in',
                ),
                const SizedBox(height: 12),
                if (!_adminApisAvailable)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'Admin APIs require an admin account. Health, payment status, and entitlement check are still available. Grant/revoke and scholar queue may return 403 for non-admin users.',
                      ),
                    ),
                  ),
                const Text('Grant test premium (admin only)', style: TextStyle(fontWeight: FontWeight.bold)),
                TextField(
                  controller: _grantUserId,
                  decoration: const InputDecoration(labelText: 'User ID', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _grantKey,
                  decoration: const InputDecoration(labelText: 'Entitlement key', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    FilledButton(onPressed: () => _grant(revoke: false), child: const Text('Grant')),
                    const SizedBox(width: 8),
                    OutlinedButton(onPressed: () => _grant(revoke: true), child: const Text('Revoke')),
                  ],
                ),
                if (_adminGrantStatus != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_adminGrantStatus!),
                  ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: widget.session == null
                      ? null
                      : () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ScholarDashboardScreen(session: widget.session!),
                            ),
                          ),
                  icon: const Icon(Icons.school),
                  label: const Text('Open scholar queue'),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Local test notes: payment provider is not configured in local QA. Ollama LLM may be required for full Ask AI answers.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
    );
  }

  Widget _card(String title, String body) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(body),
      ),
    );
  }
}
