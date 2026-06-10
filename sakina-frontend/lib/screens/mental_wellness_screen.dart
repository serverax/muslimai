import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class MentalWellnessScreen extends StatefulWidget {
  MentalWellnessScreen({
    super.key,
    ApiService? api,
    AuthSession? session,
  })  : api = api ?? ApiService(baseUrl: ApiConfig.baseUrl) {
    if (session != null) {
      this.api.setAuthToken(session.accessToken);
    }
  }

  final ApiService api;

  @override
  State<MentalWellnessScreen> createState() => _MentalWellnessScreenState();
}

class _MentalWellnessScreenState extends State<MentalWellnessScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<ChatItem> _messages = [];
  bool _sending = false;
  String _status = '';

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() {
      _messages.add(ChatItem.user(text));
      _controller.clear();
      _sending = true;
      _status = '';
    });

    try {
      final response = await widget.api.askSakina(
        message: text,
        section: 'emotional_support',
        localMemoryContext: const LocalMemoryContext(
          consent: true,
          preferredLanguage: 'auto',
        ),
      );
      
      if (!mounted) return;
      setState(() {
        _messages.add(
          ChatItem.evidence(
            response.answer,
            response.citations,
          ),
        );
        _status = 'Guidance provided via Sakina Mental Support module.';
      });
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

  String _humanizeError(Object error) {
    if (error is ApiException) {
      return error.backendMessage ?? error.message;
    }
    return 'An error occurred. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Spiritual & Mental Support'),
        backgroundColor: Colors.teal.shade50,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.teal.shade50,
            child: const Text(
              'Sakina provides Islamic emotional support grounded in Quran and Sunnah. If you are experiencing a medical emergency or self-harm thoughts, please contact professional help immediately.',
              style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
            ),
          ),
          if (_status.isNotEmpty)
            Container(
              width: double.infinity,
              color: Colors.blueGrey.shade50,
              padding: const EdgeInsets.all(8),
              child: Text(_status, style: const TextStyle(fontSize: 12)),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isUser = message.role == ChatRole.user;
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.teal.shade100 : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: isUser ? null : Border.all(color: Colors.teal.shade50),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(message.text, style: const TextStyle(fontSize: 15)),
                        if (message.evidence.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          const Divider(),
                          for (final source in message.evidence)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '• ${source.title} (${source.chapter})',
                                style: TextStyle(fontSize: 11, color: Colors.teal.shade800),
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
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Share your feelings...',
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Colors.teal,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _sending ? null : _sendMessage,
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
    widget.api.close();
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
