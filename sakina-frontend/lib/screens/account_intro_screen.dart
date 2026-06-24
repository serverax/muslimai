import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../services/auth_service.dart';
import 'home_shell_screen.dart';

class AccountIntroScreen extends StatefulWidget {
  const AccountIntroScreen({
    super.key,
    required this.appState,
    this.initialLoginMode = false,
    this.onAuthenticated,
    this.returnSessionOnSuccess = false,
  });

  final AppState appState;
  final bool initialLoginMode;
  final void Function(AuthSession session)? onAuthenticated;
  /// When true (e.g. opened from LoginRequiredScreen), pop with session instead of replacing stack.
  final bool returnSessionOnSuccess;

  @override
  State<AccountIntroScreen> createState() => _AccountIntroScreenState();
}

class _AccountIntroScreenState extends State<AccountIntroScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _submitting = false;
  late bool _loginMode;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _loginMode = widget.initialLoginMode;
  }

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
      widget.onAuthenticated?.call(session);
      if (widget.returnSessionOnSuccess) {
        Navigator.of(context).pop(session);
        return;
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => HomeShellScreen(appState: app, session: session),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorText = _friendlyError(error));
    } finally {
      auth.close();
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  String _friendlyError(Object error) {
    final text = error.toString();
    if (text.contains('401') || text.contains('403')) {
      return 'Invalid email or password. Please try again.';
    }
    if (text.contains('409') || text.toLowerCase().contains('exists')) {
      return 'An account with this email already exists. Try signing in.';
    }
    return 'Could not complete sign-in. Please check your details and try again.';
  }

  void _continueAsGuest() {
    if (widget.returnSessionOnSuccess) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => HomeShellScreen(appState: widget.appState),
      ),
    );
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
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_errorText!),
                ),
              ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _submitting ? null : _submitAuth,
              child: _submitting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_loginMode ? 'Login' : 'Register'),
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
              onPressed: _submitting ? null : _continueAsGuest,
              child: const Text('Continue as guest'),
            ),
          ],
        ),
      ),
    );
  }
}
