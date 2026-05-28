import 'dart:io';

import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../config/api_config.dart';
import '../services/api_service.dart';
import 'home_shell_screen.dart';

class AccountIntroScreen extends StatefulWidget {
  const AccountIntroScreen({super.key, required this.appState});

  final AppState appState;

  @override
  State<AccountIntroScreen> createState() => _AccountIntroScreenState();
}

class _AccountIntroScreenState extends State<AccountIntroScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _messageController = TextEditingController();
  bool _submitting = false;
  String? _errorText;
  String? _successText;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submitWaitlist() async {
    final app = widget.appState;
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final message = _messageController.text.trim();

    if (name.isEmpty || email.isEmpty) {
      setState(() {
        _errorText = '${app.t('name')} / ${app.t('email')} required.';
        _successText = null;
      });
      return;
    }

    setState(() {
      _submitting = true;
      _errorText = null;
      _successText = null;
    });

    final api = ApiService(baseUrl: ApiConfig.baseUrl);
    try {
      await api.joinWaitlist(
        name: name,
        email: email,
        preferredLanguage: app.isArabic ? 'ar' : 'en',
        platform: 'android',
        message: message.isEmpty ? null : message,
      );
      if (!mounted) return;
      setState(() {
        _successText = app.t('waitlistSuccess');
      });
    } catch (e) {
      final lower = e.toString().toLowerCase();
      final offline = e is SocketException ||
          lower.contains('socketexception') ||
          lower.contains('failed host lookup') ||
          lower.contains('network');
      setState(() {
        _errorText = offline ? app.t('networkError') : e.toString();
      });
    } finally {
      api.close();
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.appState;
    return Scaffold(
      appBar: AppBar(title: Text(app.t('joinWaitlist'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              app.t('phase2Notice'),
              textAlign: app.isArabic ? TextAlign.right : TextAlign.left,
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(labelText: app.t('name')),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(labelText: app.t('email')),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _messageController,
              minLines: 3,
              maxLines: 5,
              decoration: InputDecoration(labelText: app.t('messageOptional')),
            ),
            const SizedBox(height: 16),
            if (_errorText != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(_errorText!,
                    style: const TextStyle(color: Colors.red)),
              ),
            if (_successText != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  _successText!,
                  style: const TextStyle(color: Color(0xFF1B6B5E)),
                ),
              ),
            ElevatedButton(
              onPressed: _submitting ? null : _submitWaitlist,
              child: _submitting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(app.t('submit')),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => HomeShellScreen(appState: app),
                  ),
                );
              },
              child: Text(app.t('openPreviewShell')),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: null,
              child: Text('${app.t('comingSoon')}: Dashboard'),
            ),
          ],
        ),
      ),
    );
  }
}
