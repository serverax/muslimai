import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../config/api_config.dart';
import '../design/sakina_colors.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/feature_service.dart';
import '../services/sakina_api.dart';
import '../widgets/luxury/luxury_components.dart';
import '../widgets/workflow_states.dart';
import 'scholar_dashboard_screen.dart';
import 'settings_screen.dart';
import 'terms_privacy_screen.dart';

class AdminToolsScreen extends StatefulWidget {
  const AdminToolsScreen({
    super.key,
    this.session,
    this.appState,
  });

  final AuthSession? session;
  final AppState? appState;

  @override
  State<AdminToolsScreen> createState() => _AdminToolsScreenState();
}

class _AdminToolsScreenState extends State<AdminToolsScreen> {
  ApiService? _api;
  String _apiBase = ApiConfig.defaultBaseUrl;
  Map<String, dynamic>? _health;
  Map<String, dynamic>? _payment;
  Map<String, dynamic>? _entitlements;
  Map<String, dynamic>? _appStatus;
  List<Map<String, dynamic>> _features = [];
  String? _adminError;
  String? _actionStatus;
  bool _loading = true;
  bool _adminAuthorized = false;
  String? _editingKey;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _adminError = null;
    });
    try {
      final base = await ApiConfig.resolveBaseUrl();
      final api = await SakinaApi.create(session: widget.session);
      Map<String, dynamic>? health;
      Map<String, dynamic>? payment;
      Map<String, dynamic>? ent;
      Map<String, dynamic>? status;
      List<Map<String, dynamic>> features = [];
      bool adminOk = false;
      String? adminErr;

      try {
        health = await api.checkHealth();
      } catch (e) {
        health = {'status': 'error', 'detail': e.toString()};
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
        status = await api.adminAppStatus();
        final f = await api.adminListFeatures();
        final list = f['features'];
        if (list is List) {
          features = list.whereType<Map<String, dynamic>>().toList();
        }
        adminOk = true;
      } catch (e) {
        adminErr = e.toString();
      }

      if (mounted) {
        setState(() {
          _api = api;
          _apiBase = base;
          _health = health;
          _payment = payment;
          _entitlements = ent;
          _appStatus = status;
          _features = features;
          _adminAuthorized = adminOk;
          _adminError = adminErr;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _adminError = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _toggleFeature(String key, String field, bool value) async {
    final api = _api;
    if (api == null || !_adminAuthorized) return;
    setState(() => _actionStatus = 'Saving…');
    try {
      await api.adminUpdateFeature(featureKey: key, patch: {field: value});
      setState(() => _actionStatus = 'Saved $key');
      await _refresh();
    } catch (e) {
      setState(() => _actionStatus = 'Save failed: $e');
    }
  }

  Future<void> _resetDefaults() async {
    final api = _api;
    if (api == null || !_adminAuthorized) return;
    setState(() => _actionStatus = 'Resetting…');
    try {
      await api.adminResetFeatures();
      setState(() => _actionStatus = 'Defaults restored');
      await FeatureService.instance.load(api);
      await _refresh();
    } catch (e) {
      setState(() => _actionStatus = 'Reset failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.session == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Admin / Owner Tools')),
        body: widget.appState != null
            ? LoginRequiredScreen(
                appState: widget.appState!,
                featureName: 'Admin Tools',
              )
            : const Center(
                child: Text('Please login with an admin account to access owner tools.'),
              ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin / Owner Tools'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
        ],
      ),
      body: _loading
          ? const SakinaLoadingState(message: 'Loading admin dashboard…')
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                LuxuryDashboardCard(
                  title: 'System status',
                  subtitle: _apiBase,
                  gradient: true,
                  badges: [
                    StatusBadge(
                      label: _appStatus?['app_mode']?.toString() ?? 'local',
                      color: SakinaColors.gold,
                    ),
                    StatusBadge(
                      label: _health?['status']?.toString() ?? 'checked',
                      color: SakinaColors.success,
                    ),
                  ],
                ),
                if (!_adminAuthorized)
                  LuxuryDashboardCard(
                    title: 'Admin permission required',
                    subtitle: _adminError ??
                        'Login with an admin/owner JWT to manage feature gates.',
                    leading: const Icon(Icons.admin_panel_settings, color: SakinaColors.error),
                  ),
                if (_appStatus != null) ...[
                  const IslamicSectionHeader(title: 'Feature summary'),
                  _statGrid(),
                ],
                if (_payment != null)
                  LuxuryDashboardCard(title: 'Payment provider', subtitle: '$_payment'),
                if (_entitlements != null)
                  LuxuryDashboardCard(title: 'Your entitlements', subtitle: '$_entitlements'),
                if (_adminAuthorized && _features.isNotEmpty) ...[
                  IslamicSectionHeader(
                    title: 'Feature gates (${_features.length})',
                    trailing: TextButton(onPressed: _resetDefaults, child: const Text('Reset')),
                  ),
                  for (final f in _features) _featureEditor(f),
                ],
                if (_actionStatus != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_actionStatus!, style: const TextStyle(color: SakinaColors.textSecondary)),
                  ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ScholarDashboardScreen(session: widget.session!),
                    ),
                  ),
                  icon: const Icon(Icons.school),
                  label: const Text('Scholar queue'),
                ),
                if (widget.appState != null) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SettingsScreen(
                          appState: widget.appState!,
                          session: widget.session,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.settings),
                    label: const Text('System diagnostics'),
                  ),
                ],
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const TermsPrivacyScreen()),
                  ),
                  icon: const Icon(Icons.policy),
                  label: const Text('Terms & privacy'),
                ),
                const SizedBox(height: 12),
                const SafeDisclaimerBanner(compact: true),
              ],
            ),
    );
  }

  Widget _statGrid() {
    final s = _appStatus!;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        StatusBadge(label: 'Total: ${s['total_features']}', icon: Icons.apps),
        StatusBadge(label: 'Enabled: ${s['enabled_features']}', color: SakinaColors.success),
        StatusBadge(label: 'Disabled: ${s['disabled_features']}', color: SakinaColors.error),
        StatusBadge(label: 'Premium: ${s['premium_features']}', color: SakinaColors.gold),
        StatusBadge(label: 'Login: ${s['login_required_features']}'),
        StatusBadge(label: 'Soon: ${s['coming_soon_features']}'),
        StatusBadge(label: 'Maint: ${s['maintenance_features']}'),
      ],
    );
  }

  Widget _featureEditor(Map<String, dynamic> f) {
    final key = f['feature_key']?.toString() ?? '';
    final title = f['title_en']?.toString() ?? key;
    final expanded = _editingKey == key;
    return Column(
      children: [
        FeatureTile(
          icon: iconForFeatureKey(key),
          title: title,
          subtitle: key,
          badge: !expanded && f['enabled'] != true
              ? const StatusBadge(label: 'Off', color: SakinaColors.error)
              : null,
          onTap: () => setState(() => _editingKey = expanded ? null : key),
        ),
        if (expanded)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Enabled'),
                    value: f['enabled'] == true,
                    onChanged: (v) => _toggleFeature(key, 'enabled', v),
                  ),
                  SwitchListTile(
                    title: const Text('Requires login'),
                    value: f['requires_login'] == true,
                    onChanged: (v) => _toggleFeature(key, 'requires_login', v),
                  ),
                  SwitchListTile(
                    title: const Text('Requires premium'),
                    value: f['requires_premium'] == true,
                    onChanged: (v) => _toggleFeature(key, 'requires_premium', v),
                  ),
                  SwitchListTile(
                    title: const Text('Coming soon'),
                    value: f['coming_soon'] == true,
                    onChanged: (v) => _toggleFeature(key, 'coming_soon', v),
                  ),
                  SwitchListTile(
                    title: const Text('Maintenance'),
                    value: f['maintenance_mode'] == true,
                    onChanged: (v) => _toggleFeature(key, 'maintenance_mode', v),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
