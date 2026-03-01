import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';

const String verifyEmailRoute = '/verify-email';

class VerifyEmailPage extends StatelessWidget {
  const VerifyEmailPage({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final isBusy = authProvider.isLoading;
    final email = authProvider.currentUser?.email ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Verify email')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  email.isEmpty
                      ? 'Please verify your email to continue.'
                      : 'Please verify $email to continue.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: isBusy
                      ? null
                      : () => context
                            .read<AuthProvider>()
                            .refreshVerificationStatus(),
                  child: const Text("I've verified my email"),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: isBusy
                      ? null
                      : () => context
                            .read<AuthProvider>()
                            .resendVerificationEmail(),
                  child: const Text('Resend verification email'),
                ),
                TextButton(
                  onPressed: isBusy
                      ? null
                      : () => context.read<AuthProvider>().signOut(),
                  child: const Text('Sign out'),
                ),
                if (authProvider.failure != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    authProvider.failure!.message,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
