import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/sakina_api.dart';

class ScholarDashboardScreen extends StatefulWidget {
  const ScholarDashboardScreen({super.key, required this.session});

  final AuthSession session;

  @override
  State<ScholarDashboardScreen> createState() => _ScholarDashboardScreenState();
}

class _ScholarDashboardScreenState extends State<ScholarDashboardScreen> {
  ApiService? _api;
  List<dynamic> _queue = [];
  String? _error;
  bool _loading = true;
  bool _resolveAvailable = false;
  final _answerController = TextEditingController();
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = await SakinaApi.create(session: widget.session);
      List<dynamic> items = [];
      bool canResolve = false;
      try {
        items = await api.scholarQueue();
        canResolve = true;
      } on ApiException catch (e) {
        if (e.statusCode == 403) {
          _error =
              'Scholar review backend is partially implemented. Pending queue/status is available for users; scholar resolution requires a scholar account.';
        } else {
          rethrow;
        }
      }
      if (mounted) {
        setState(() {
          _api = api;
          _queue = items;
          _resolveAvailable = canResolve;
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

  Future<void> _resolve() async {
    final api = _api;
    final id = _selectedId;
    final answer = _answerController.text.trim();
    if (api == null || id == null || answer.isEmpty) return;
    try {
      await api.resolveScholarReview(queueId: id, finalAnswer: answer);
      _answerController.clear();
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Review resolved.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Resolve unavailable: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scholar Dashboard'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _queue.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Icon(Icons.info_outline, size: 48),
                      const SizedBox(height: 12),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      OutlinedButton(onPressed: _load, child: const Text('Refresh queue')),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    if (!_resolveAvailable)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: Text(
                            'Scholar review backend is partially implemented. Pending queue/status is available; resolution action is not available yet for this account.',
                          ),
                        ),
                      ),
                    ..._queue.map((item) {
                      final m = item as Map<String, dynamic>;
                      final id = m['id']?.toString() ?? m['scholar_review_queue_id']?.toString() ?? '';
                      final question = m['question']?.toString() ?? m['user_question']?.toString() ?? 'Question';
                      final status = m['status']?.toString() ?? 'pending';
                      return Card(
                        child: ListTile(
                          title: Text(question),
                          subtitle: Text('Status: $status · ID: $id'),
                          onTap: () => setState(() => _selectedId = id),
                          trailing: _selectedId == id ? const Icon(Icons.check_circle) : null,
                        ),
                      );
                    }),
                    if (_resolveAvailable && _selectedId != null) ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: _answerController,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Scholar answer / resolution',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      FilledButton(onPressed: _resolve, child: const Text('Submit review')),
                    ],
                  ],
                ),
    );
  }
}
