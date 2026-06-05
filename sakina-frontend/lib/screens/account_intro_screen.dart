import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../services/auth_service.dart';
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
  final _passwordController = TextEditingController();
  bool _submitting = false;
  bool _loginMode = false;
  String? _errorText;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitAuth() async {
    final app = widget.appState;
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if ((!_loginMode && name.isEmpty) || email.isEmpty || password.isEmpty) {
      setState(() {
        _errorText = _loginMode
            ? '${app.t('email')} / password required.'
            : '${app.t('name')} / ${app.t('email')} / password required.';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _errorText = null;
    });

    final auth = AuthService();
    try {
      final session = _loginMode
          ? await auth.login(email: email, password: password)
          : await auth.register(email: email, password: password, name: name);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => HomeShellScreen(appState: app, session: session),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorText = error.toString());
    } finally {
      auth.close();
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.appState;
    return Scaffold(
      appBar: AppBar(title: Text(_loginMode ? 'Sign in' : 'Create account')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _loginMode
                  ? 'Sign in to Sakina AI.'
                  : 'Create your Sakina AI account.',
              textAlign: app.isArabic ? TextAlign.right : TextAlign.left,
            ),
            const SizedBox(height: 18),
            if (!_loginMode) ...[
              TextField(
                controller: _nameController,
                decoration: InputDecoration(labelText: app.t('name')),
              ),
              const SizedBox(height: 10),
            ],
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(labelText: app.t('email')),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            const SizedBox(height: 16),
            if (_errorText != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  _errorText!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ElevatedButton(
              onPressed: _submitting ? null : _submitAuth,
              child: _submitting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_loginMode ? 'Sign in' : 'Create account'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _submitting
                  ? null
                  : () => setState(() => _loginMode = !_loginMode),
              child: Text(
                  _loginMode ? 'Create account' : 'I already have an account'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => HomeShellScreen(appState: app),
                  ),
                );
              },
              child: const Text('Continue without private sync'),
            ),
          ],
        ),
      ),
    );
  }
}
