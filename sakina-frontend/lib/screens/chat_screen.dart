import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../config/brand_config.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/pending_review_store.dart';
import 'scholar_reviews_screen.dart';

class ChatScreen extends StatefulWidget {
  ChatScreen({
    super.key,
    ApiService? api,
    String? userId,
    this.session,
  })  : api = api ?? ApiService(baseUrl: ApiConfig.baseUrl),
        userId = session?.userId ??
            userId ??
            const String.fromEnvironment('SAKINA_USER_ID') {
    if (session != null) {
      this.api.setAuthToken(session!.accessToken);
    }
  }

  final ApiService api;
  final String userId;
  final AuthSession? session;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<ChatItem> _messages = [];
  bool _sending = false;
  String _status = '';
  bool _contractWarning = false;
  String? _lastSafetyState;
  final PendingReviewStore _pendingReviews = PendingReviewStore();

  void _clearChat() {
    setState(() {
      _messages.clear();
      _status = '';
      _contractWarning = false;
      _lastSafetyState = null;
    });
  }

  void _viewCitations() {
    ChatItem? last;
    for (final m in _messages.reversed) {
      if (m.evidence.isNotEmpty) {
        last = m;
        break;
      }
    }
    if (last == null) {
      setState(() => _status = 'No citations in the latest answer yet.');
      return;
    }
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const Text('Citations', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            for (final source in last!.evidence)
              ListTile(
                title: Text(source.title),
                subtitle: Text('${source.chapter} · ${source.authenticityGrade}'),
              ),
          ],
        ),
      ),
    );
  }

  void _viewReviewStatus() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ScholarReviewsScreen(session: widget.session),
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() {
      _messages.add(ChatItem.user(text));
      _controller.clear();
      _sending = true;
      _status = 'Asking with guardrails…';
      _contractWarning = false;
    });

    try {
      final response = await widget.api.askSakina(
        message: text,
        section: 'ask_sakina',
        localMemoryContext: const LocalMemoryContext(
          consent: true,
          preferredLanguage: 'auto',
        ),
      );
      final verifiedSources =
          response.citations.where((source) => source.isVerifiedShape).toList();
      final malformedDetected = response.citations.isNotEmpty &&
          verifiedSources.length != response.citations.length;
      if (!mounted) return;
      setState(() {
        _contractWarning = malformedDetected;
        _lastSafetyState = response.safetyState;
        _messages.add(ChatItem.evidence(response.answer, verifiedSources));
        _status = response.safetyState == 'ESCALATED_TO_HUMAN'
            ? 'Escalated to scholar review — safe general guidance shown.'
            : 'Answered with guardrails · ${response.modelProvider}';
      });
      if (response.safetyState == 'ESCALATED_TO_HUMAN' &&
          response.traceId.isNotEmpty) {
        await _pendingReviews.add(PendingReview(
          traceId: response.traceId,
          question: text,
          createdAt: DateTime.now().toIso8601String(),
        ));
        if (mounted) {
          setState(() {
            _messages.add(ChatItem.system(
              'This question was escalated to a scholar for review. Tap "View review status" to follow progress.',
            ));
          });
        }
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _messages.add(ChatItem.system(_humanizeError(error)));
        _status = '';
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _humanizeError(Object error) {
    if (error is FormatException) {
      return 'Malformed backend response. Please retry later.';
    }
    if (error is ApiException) {
      final code = error.errorCode ?? '';
      if (error.statusCode == 401 || error.statusCode == 403) {
        return 'Please sign in to use Ask AI Shaikh with your account.';
      }
      if (error.statusCode == 402 || code == 'subscription_required') {
        return 'Premium entitlement required for this action.';
      }
      if (code == 'feature_disabled') {
        return 'This feature is currently disabled by backend policy.';
      }
      return error.backendMessage ?? error.message;
    }
    return 'Unexpected error occurred. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ask AI Shaikh'),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined),
            tooltip: 'Back home',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_status.isNotEmpty)
            Container(
              width: double.infinity,
              color: const Color(SakinaBrand.colorAccent),
              padding: const EdgeInsets.all(8),
              child: Text(_status),
            ),
          if (_contractWarning)
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text(
                'Some citations could not be verified and were safely discarded.',
                style: TextStyle(color: Colors.deepOrange),
              ),
            ),
          if (_lastSafetyState == 'ESCALATED_TO_HUMAN')
            Padding(
              padding: const EdgeInsets.all(8),
              child: OutlinedButton.icon(
                onPressed: _viewReviewStatus,
                icon: const Icon(Icons.gavel),
                label: const Text('View scholar review status'),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Wrap(
              spacing: 8,
              children: [
                FilledButton(
                  onPressed: _sending ? null : _sendMessage,
                  child: Text(_sending ? 'Asking…' : 'Ask'),
                ),
                OutlinedButton(onPressed: _clearChat, child: const Text('Clear')),
                OutlinedButton(onPressed: _viewCitations, child: const Text('View citations')),
                OutlinedButton(onPressed: _viewReviewStatus, child: const Text('Review status')),
              ],
            ),
          ),
          Expanded(
            child: _messages.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Ask a question such as "How do I make wudu?" for grounded guidance with citations.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isUser = message.role == ChatRole.user;
                      return Align(
                        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.all(8),
                          padding: const EdgeInsets.all(12),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.85,
                          ),
                          decoration: BoxDecoration(
                            color: isUser
                                ? const Color(SakinaBrand.colorPrimary)
                                : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                message.text,
                                style: TextStyle(color: isUser ? Colors.white : Colors.black87),
                              ),
                              if (message.evidence.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                for (final source in message.evidence)
                                  Text(
                                    '• ${source.title} (${source.authenticityGrade})',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isUser ? Colors.white70 : Colors.black54,
                                    ),
                                  ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Type your question…',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  onPressed: _sending ? null : _sendMessage,
                  child: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

enum ChatRole { user, system, evidence }

class ChatItem {
  final ChatRole role;
  final String text;
  final List<Citation> evidence;

  const ChatItem._({
    required this.role,
    required this.text,
    required this.evidence,
  });

  factory ChatItem.user(String text) =>
      ChatItem._(role: ChatRole.user, text: text, evidence: const []);

  factory ChatItem.system(String text) =>
      ChatItem._(role: ChatRole.system, text: text, evidence: const []);

  factory ChatItem.evidence(String text, List<Citation> evidence) =>
      ChatItem._(role: ChatRole.evidence, text: text, evidence: evidence);
}
