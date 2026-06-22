import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/pending_review_store.dart';

class ChatScreen extends StatefulWidget {
  ChatScreen({
    super.key,
    ApiService? api,
    String? userId,
    AuthSession? session,
  })  : api = api ?? ApiService(baseUrl: ApiConfig.baseUrl),
        userId = session?.userId ??
            userId ??
            const String.fromEnvironment('SAKINA_USER_ID') {
    if (session != null && api == null) {
      this.api.setAuthToken(session.accessToken);
    }
  }

  final ApiService api;
  final String userId;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _supportController = TextEditingController();
  final List<ChatItem> _messages = [];
  bool _sending = false;
  bool _notificationBusy = false;
  bool _supportBusy = false;
  String? _lastMessageId;
  String _status = '';
  bool _contractWarning = false;
  final PendingReviewStore _pendingReviews = PendingReviewStore();

  Future<void> _sendNotificationFlow() async {
    if (_notificationBusy) return;
    setState(() => _notificationBusy = true);
    try {
      final id = await widget.api.createNotificationTemplate(
        templateKey:
            'mobile-chat-update-${DateTime.now().millisecondsSinceEpoch}',
        subjectTemplate: 'Sakina update',
        bodyTemplate: 'A chat update is available.',
      );
      await widget.api.sendNotification(
        userId: widget.userId,
        templateId: id,
        title: 'Sakina Notification',
        body: 'Evidence-only answer ready.',
      );
      if (!mounted) return;
      setState(() {
        _status = 'Notifications endpoint wired successfully.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = _humanizeError(error));
    } finally {
      if (mounted) {
        setState(() => _notificationBusy = false);
      }
    }
  }

  Future<void> _submitSupportTicket() async {
    final body = _supportController.text.trim();
    if (body.isEmpty || _supportBusy) return;
    setState(() => _supportBusy = true);
    try {
      final ticket = await widget.api.createSupportTicket(
        userId: widget.userId,
        subject: 'Mobile support request',
        messageBody: body,
      );
      await widget.api.appendSupportMessage(
        ticketId: ticket.ticketId,
        messageBody: 'Follow-up from mobile client.',
      );
      final snapshot = await widget.api.getSupportTicket(ticket.ticketId);
      if (!mounted) return;
      setState(() {
        _status =
            'Support ticket ${snapshot.ticketId} synced (${snapshot.messages.length} messages).';
        _supportController.clear();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = _humanizeError(error));
    } finally {
      if (mounted) {
        setState(() => _supportBusy = false);
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() {
      _messages.add(ChatItem.user(text));
      _controller.clear();
      _sending = true;
      _status = '';
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
      _lastMessageId = null;
      final verifiedSources =
          response.citations.where((source) => source.isVerifiedShape).toList();
      final malformedDetected = response.citations.isNotEmpty &&
          verifiedSources.length != response.citations.length;
      if (!mounted) return;
      setState(() {
        _contractWarning = malformedDetected;
        _messages.add(
          ChatItem.evidence(
            response.answer,
            verifiedSources,
          ),
        );
        _status =
            'Trace ${response.traceId} | ${response.sourcePath['answer_source'] ?? 'unknown'} | ${response.modelProvider}';
      });
      // PHASE 1B: high-risk question escalated to a scholar — track it locally so
      // the user can return to the Reviews screen and poll for the final answer.
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
                'This question was escalated to a scholar for review. Open the Reviews tab to see the answer when it is ready.'));
          });
        }
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _messages.add(ChatItem.system(_humanizeError(error)));
      });
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  Future<void> _sendFeedback(String type) async {
    final messageId = _lastMessageId;
    if (messageId == null) {
      setState(() {
        _status = 'No message available for feedback yet.';
      });
      return;
    }
    try {
      await widget.api.sendChatFeedback(
        messageId: messageId,
        feedbackType: type,
        feedbackScore: type == 'thumbs_up' ? 5 : 1,
      );
      if (!mounted) return;
      setState(() => _status = 'Feedback submitted.');
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = _humanizeError(error));
    }
  }

  Future<void> _reportMessage() async {
    final messageId = _lastMessageId;
    if (messageId == null) {
      setState(() => _status = 'No message available to report.');
      return;
    }
    try {
      await widget.api.reportMessage(
        messageId: messageId,
        reason: 'citation_missing',
        details: 'Verified evidence could not be validated in UI.',
      );
      if (!mounted) return;
      setState(() => _status = 'Report submitted.');
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = _humanizeError(error));
    }
  }

  String _humanizeError(Object error) {
    if (error is FormatException) {
      return 'Malformed backend response. Please retry later.';
    }
    if (error is ApiException) {
      final code = error.errorCode ?? '';
      if (error.statusCode == 401 || error.statusCode == 403) {
        return 'Unauthorized request. Please sign in again.';
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
        title: const Text('Project Sakina'),
      ),
      body: Column(
        children: [
          if (_status.isNotEmpty)
            Container(
              width: double.infinity,
              color: Colors.blueGrey.shade50,
              padding: const EdgeInsets.all(8),
              child: Text(_status),
            ),
          if (_contractWarning)
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text(
                'Some backend evidence items were malformed and were safely discarded.',
                style: TextStyle(color: Colors.deepOrange),
              ),
            ),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton(
                onPressed: _notificationBusy ? null : _sendNotificationFlow,
                child: Text(_notificationBusy ? 'Sending...' : 'Notify'),
              ),
              OutlinedButton(
                onPressed: _sendFeedbackUpDownDisabled()
                    ? null
                    : () => _sendFeedback('thumbs_up'),
                child: const Text('Feedback +'),
              ),
              OutlinedButton(
                onPressed: _sendFeedbackUpDownDisabled()
                    ? null
                    : () => _sendFeedback('thumbs_down'),
                child: const Text('Feedback -'),
              ),
              OutlinedButton(
                onPressed:
                    _sendFeedbackUpDownDisabled() ? null : _reportMessage,
                child: const Text('Report'),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _supportController,
                    decoration: const InputDecoration(
                      hintText: 'Create support ticket...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _supportBusy ? null : _submitSupportTicket,
                  child: Text(_supportBusy ? '...' : 'Support'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return Align(
                  alignment: message.role == ChatRole.user
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: message.role == ChatRole.user
                          ? Colors.blue
                          : Colors.grey[300],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(message.text),
                        if (message.evidence.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          for (final source in message.evidence)
                            Text(
                              '- ${source.title} | ${source.chapter} | ${source.authenticityGrade}',
                              style: const TextStyle(fontSize: 12),
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
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    label: 'chat-message-input',
                    textField: true,
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: 'Ask your question...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Semantics(
                  button: true,
                  label: 'send-message-button',
                  child: FloatingActionButton(
                    tooltip: 'Send message',
                    onPressed: _sending ? null : _sendMessage,
                    child: const Icon(Icons.send),
                  ),
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
    _supportController.dispose();
    widget.api.close();
    super.dispose();
  }

  bool _sendFeedbackUpDownDisabled() => _lastMessageId == null;
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
