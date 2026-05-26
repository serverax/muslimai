import 'package:flutter/material.dart';

import '../chat/chat_controller.dart';
import '../design/tokens.dart';
import '../l10n/app_localizations.dart';
import '../widgets/citation_widget.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, this.controller});

  final ChatController? controller;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final ChatController _chatController;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _chatController = widget.controller ??
        ChatController(
          backend: ApiChatBackend(),
          historyStore: LocalDbChatHistoryStore(),
        );
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    await _chatController.initialize();
    if (mounted) setState(() {});
  }

  Future<void> _sendMessage() async {
    final message = _controller.text;
    if (message.trim().isEmpty || _chatController.isSending) return;

    setState(() {
      _controller.clear();
    });

    final send = _chatController.send(message);
    setState(() {});
    await send;
    if (mounted) {
      setState(() {});
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.chatTitle),
      ),
      body: Column(
        children: [
          Expanded(
            child: _ChatMessageList(
              controller: _chatController,
              emptyMessage: l10n.askFirstQuestion,
              scrollController: _scrollController,
            ),
          ),
          if (_chatController.errorType case final errorType?)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                SakinaSpacing.md,
                0,
                SakinaSpacing.md,
                SakinaSpacing.sm,
              ),
              child: Text(
                _localizedError(l10n, errorType),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: l10n.askQuestionHint,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  onPressed: _chatController.isSending ? null : _sendMessage,
                  child: _chatController.isSending
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _localizedError(AppLocalizations l10n, ChatErrorType errorType) {
    switch (errorType) {
      case ChatErrorType.historyUnavailable:
        return l10n.chatHistoryUnavailable;
      case ChatErrorType.authFailed:
        return l10n.chatAuthFailed;
      case ChatErrorType.rateLimited:
        return l10n.chatRateLimited;
      case ChatErrorType.serviceUnavailable:
        return l10n.chatServiceUnavailable;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    if (_ownsController) {
      _chatController.close();
    }
    super.dispose();
  }
}

class _ChatMessageList extends StatelessWidget {
  const _ChatMessageList({
    required this.controller,
    required this.emptyMessage,
    required this.scrollController,
  });

  final ChatController controller;
  final String emptyMessage;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final messages = controller.messages;
    if (messages.isEmpty) {
      return Center(
        child: Text(emptyMessage),
      );
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(SakinaSpacing.sm),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        return _ChatBubble(message: messages[index]);
      },
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = message.isUser
        ? theme.colorScheme.primary
        : theme.colorScheme.surfaceContainerHighest;
    final foreground = message.isUser
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurface;

    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Container(
          margin: const EdgeInsets.all(SakinaSpacing.sm),
          padding: const EdgeInsets.all(SakinaSpacing.md),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(SakinaRadius.md),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message.content,
                style: theme.textTheme.bodyMedium?.copyWith(color: foreground),
              ),
              if (message.sources.isNotEmpty) ...[
                const SizedBox(height: SakinaSpacing.sm),
                Wrap(
                  spacing: SakinaSpacing.sm,
                  runSpacing: SakinaSpacing.sm,
                  children: [
                    for (final citation in message.sources)
                      CitationBadge(source: citation),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
