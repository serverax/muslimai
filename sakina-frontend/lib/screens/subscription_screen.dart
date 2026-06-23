import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

/// PHASE 5 — subscription screen: plans, current tier, upgrade CTA.
/// Honest payment status (no fake success). Free features are not gated here.
class SubscriptionScreen extends StatefulWidget {
  SubscriptionScreen({super.key, ApiService? api, this.session})
      : api = api ?? ApiService(baseUrl: ApiConfig.baseUrl) {
    if (session != null) this.api.setAuthToken(session!.accessToken);
  }

  final ApiService api;
  final AuthSession? session;

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  List<dynamic> _plans = [];
  Map<String, dynamic>? _me;
  Map<String, dynamic>? _provider;
  bool _loading = true;
  String? _error;
  String? _checkoutMsg;

  bool get _loggedIn => widget.session != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final plans = await widget.api.subscriptionPlans();
      final provider = await widget.api.paymentProviderStatus();
      Map<String, dynamic>? me;
      if (_loggedIn) {
        me = await widget.api.subscriptionMe();
      }
      if (mounted) {
        setState(() {
          _plans = (plans['plans'] as List<dynamic>?) ?? [];
          _provider = provider;
          _me = me;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load subscription info: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _upgrade() async {
    if (!_loggedIn) {
      setState(() => _checkoutMsg = 'Please log in to upgrade.');
      return;
    }
    try {
      final r = await widget.api.createCheckoutSession();
      final status = r['status']?.toString() ?? '';
      setState(() {
        _checkoutMsg = status == 'provider_not_configured'
            ? 'Payments are not enabled yet. No charge was made.'
            : (r['checkout_url']?.toString() ?? 'Checkout pending setup.');
      });
    } catch (e) {
      setState(() => _checkoutMsg = 'Upgrade unavailable: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final premium = _me?['premium'] == true;
    final tier = _me?['tier']?.toString() ?? (_loggedIn ? 'free' : 'not signed in');
    final providerStatus = _provider?['status']?.toString() ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('Subscription')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : ListView(padding: const EdgeInsets.all(16), children: [
                  Card(
                    color: premium ? Colors.green.shade50 : null,
                    child: ListTile(
                      leading: Icon(premium ? Icons.workspace_premium : Icons.person),
                      title: Text('Current plan: ${premium ? 'Premium' : tier}'),
                      subtitle: Text(_loggedIn
                          ? (premium ? 'Premium features unlocked.' : 'Free tier.')
                          : 'Sign in to see your plan.'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('Plans', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  ..._plans.map((p) {
                    final price = (p['price_cents'] as int? ?? 0) / 100.0;
                    return Card(
                      child: ListTile(
                        title: Text(p['plan_name'].toString()),
                        subtitle: Text(price == 0
                            ? 'Free'
                            : '${p['currency']} ${price.toStringAsFixed(2)} / ${p['billing_interval']}'),
                        trailing: p['plan_key'] == 'free'
                            ? const Chip(label: Text('Free'))
                            : (premium
                                ? const Chip(label: Text('Active'))
                                : FilledButton(onPressed: _upgrade, child: const Text('Upgrade'))),
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                  Text('Payment provider: $providerStatus',
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  if (_checkoutMsg != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Card(
                        color: Colors.amber.shade50,
                        child: Padding(padding: const EdgeInsets.all(12), child: Text(_checkoutMsg!)),
                      ),
                    ),
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Text(
                      'Free features (Quran, prayer times, guides, calculators) never require payment.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                ]),
    );
  }
}
