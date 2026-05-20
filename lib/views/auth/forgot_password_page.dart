import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/auth/auth_validators.dart';
import '../../widgets/auth_shell.dart';

const String forgotPasswordRoute = '/forgot-password';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authProvider = context.read<AuthProvider>();
    await authProvider.sendPasswordReset(_emailController.text);

    if (!mounted) {
      return;
    }

    if (authProvider.failure == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'If an account exists for this email, a reset message has been sent.',
          ),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final isBusy = authProvider.isLoading;

    return AuthShell(
      title: 'Reset your password',
      subtitle:
          'Enter the email address linked to your account and we will send you a recovery link.',
      topBadgeIcon: Icons.lock_reset_rounded,
      footer: Center(
        child: TextButton(
          onPressed: isBusy ? null : () => Navigator.of(context).pop(),
          child: const Text('Back to sign in'),
        ),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'you@example.com',
              ),
              validator: AuthValidators.validateEmail,
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: isBusy ? null : _submit,
              child: Text(isBusy ? 'Sending link...' : 'Send reset link'),
            ),
            if (authProvider.failure != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                authProvider.failure!.message,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
