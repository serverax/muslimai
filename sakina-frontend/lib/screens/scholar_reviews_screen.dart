import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/pending_review_store.dart';

/// Shows the user's escalated questions and polls the backend
/// (GET /api/sakina/review-status/{trace}) for the scholar's final answer.
/// Requires login (the endpoint enforces ownership; user B cannot see user A).
class ScholarReviewsScreen extends StatefulWidget {
  ScholarReviewsScreen({super.key, ApiService? api, AuthSession? session})
      : api = api ?? ApiService(baseUrl: ApiConfig.baseUrl) {
    if (session != null) {
      this.api.setAuthToken(session.accessToken);
    }
  }

  final ApiService api;

  @override
  State<ScholarReviewsScreen> createState() => _ScholarReviewsScreenState();
}

class _ScholarReviewsScreenState extends State<ScholarReviewsScreen> {
  final PendingReviewStore _store = PendingReviewStore();
  List<PendingReview> _items = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _store.list();
      // Poll backend status for any not-yet-answered review.
      for (final r in items) {
        if (r.status != 'scholar_answered') {
          try {
            final s = await widget.api.reviewStatus(r.traceId);
            final status = s['status']?.toString() ?? r.status;
            final answer = s['final_answer']?.toString();
            await _store.updateStatus(r.traceId, status, answer);
          } catch (_) {
            // Leave as-is on transient errors; honest, no fabricated status.
          }
        }
      }
      final refreshed = await _store.list();
      if (!mounted) return;
      setState(() => _items = refreshed);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not load reviews: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _statusColor(String s) =>
      s == 'scholar_answered' ? Colors.green : Colors.orange;

  String _statusLabel(String s) {
    switch (s) {
      case 'scholar_answered':
        return 'Scholar answered';
      case 'pending_scholar_review':
        return 'Pending scholar review';
      case 'no_review':
        return 'No review found';
      default:
        return s;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scholar Reviews'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _refresh,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _error != null
            ? ListView(children: [
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_error!, style: const TextStyle(color: Colors.red)),
                )
              ])
            : _items.isEmpty
                ? ListView(children: const [
                    Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No scholar reviews yet. When you ask a high-risk question '
                        'that needs a scholar, it will appear here with its status.',
                      ),
                    )
                  ])
                : ListView.builder(
                    itemCount: _items.length,
                    itemBuilder: (context, i) {
                      final r = _items[i];
                      final answered = r.status == 'scholar_answered';
                      return Card(
                        margin:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: ExpansionTile(
                          leading: Icon(
                            answered ? Icons.verified : Icons.hourglass_top,
                            color: _statusColor(r.status),
                          ),
                          title: Text(
                            r.question,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            _statusLabel(r.status),
                            style: TextStyle(color: _statusColor(r.status)),
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Trace: ${r.traceId}',
                                      style: const TextStyle(
                                          fontSize: 11, color: Colors.grey)),
                                  const SizedBox(height: 8),
                                  if (answered && r.finalAnswer != null)
                                    Text(r.finalAnswer!)
                                  else
                                    const Text(
                                      'A qualified scholar is reviewing this. '
                                      'Pull to refresh to check for an answer.',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
