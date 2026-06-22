import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Locally tracks ask-traces that were escalated to a scholar so the user can
/// return later and poll their status. Per-device only; the authoritative
/// status + final answer come from the backend (GET /api/sakina/review-status).
class PendingReview {
  PendingReview({
    required this.traceId,
    required this.question,
    required this.createdAt,
    this.status = 'pending_scholar_review',
    this.finalAnswer,
  });

  final String traceId;
  final String question;
  final String createdAt;
  String status;
  String? finalAnswer;

  Map<String, dynamic> toJson() => {
        'trace_id': traceId,
        'question': question,
        'created_at': createdAt,
        'status': status,
        'final_answer': finalAnswer,
      };

  static PendingReview fromJson(Map<String, dynamic> j) => PendingReview(
        traceId: j['trace_id']?.toString() ?? '',
        question: j['question']?.toString() ?? '',
        createdAt: j['created_at']?.toString() ?? '',
        status: j['status']?.toString() ?? 'pending_scholar_review',
        finalAnswer: j['final_answer']?.toString(),
      );
}

class PendingReviewStore {
  static const _key = 'sakina_pending_scholar_reviews';

  Future<List<PendingReview>> list() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((e) => PendingReview.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _save(List<PendingReview> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(items.map((e) => e.toJson()).toList()));
  }

  Future<void> add(PendingReview review) async {
    final items = await list();
    if (items.any((r) => r.traceId == review.traceId)) return;
    items.insert(0, review);
    await _save(items);
  }

  Future<void> updateStatus(String traceId, String status, String? finalAnswer) async {
    final items = await list();
    for (final r in items) {
      if (r.traceId == traceId) {
        r.status = status;
        if (finalAnswer != null) r.finalAnswer = finalAnswer;
      }
    }
    await _save(items);
  }

  Future<void> remove(String traceId) async {
    final items = await list();
    items.removeWhere((r) => r.traceId == traceId);
    await _save(items);
  }

  Future<int> answeredCount() async {
    final items = await list();
    return items.where((r) => r.status == 'scholar_answered').length;
  }
}
