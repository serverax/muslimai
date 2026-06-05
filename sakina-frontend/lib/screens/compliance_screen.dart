import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class ComplianceScreen extends StatefulWidget {
  const ComplianceScreen({super.key, this.session});

  final AuthSession? session;

  @override
  State<ComplianceScreen> createState() => _ComplianceScreenState();
}

class _ComplianceScreenState extends State<ComplianceScreen> {
  bool _submittingDeletion = false;
  String? _status;
  String? _error;

  Future<void> _requestDeletion() async {
    final session = widget.session;
    if (session == null) {
      setState(() {
        _status = null;
        _error = 'Sign in before requesting account deletion.';
      });
      return;
    }
    setState(() {
      _submittingDeletion = true;
      _status = null;
      _error = null;
    });
    final api =
        ApiService(baseUrl: ApiConfig.baseUrl, apiToken: session.accessToken);
    try {
      final response = await api.requestAccountDeletion();
      if (!mounted) return;
      setState(() {
        _status = 'Deletion request queued: ${response.requestId}';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      api.close();
      if (mounted) {
        setState(() => _submittingDeletion = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Privacy Policy', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        const Text(
          'Sakina stores account, profile, chat, memory, upload, and audit data only for authenticated product use. Private data is user-scoped and protected by backend authorization and database row-level security.',
        ),
        const SizedBox(height: 18),
        Text('Terms', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        const Text(
          'Sakina is an Islamic companion app for education, reflection, and daily assistance. It is not a replacement for qualified scholars, emergency services, medical care, legal advice, or financial advice.',
        ),
        const SizedBox(height: 18),
        Text('Islamic Advisory Disclaimer',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        const Text(
          'Religious answers must be source-backed where possible. Sensitive fatwa-style, family, medical, legal, crisis, or sectarian questions may be caveated, refused, or escalated to qualified human review.',
        ),
        const SizedBox(height: 18),
        Text('Data Export and Deletion',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        const Text(
          'You can request data export or account deletion. Deletion requests are authenticated, audited, queued, and processed against user-owned profile, chat, memory, upload, session, and related private records.',
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _submittingDeletion ? null : _requestDeletion,
          icon: const Icon(Icons.delete_outline),
          label: Text(_submittingDeletion
              ? 'Requesting deletion...'
              : 'Request account deletion'),
        ),
        if (_status != null) ...[
          const SizedBox(height: 12),
          Text(_status!, style: const TextStyle(color: Colors.green)),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: Colors.red)),
        ],
      ],
    );
  }
}
