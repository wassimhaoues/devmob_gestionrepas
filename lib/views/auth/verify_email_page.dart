import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../widgets/auth_shell.dart';

const String verifyEmailRoute = '/verify-email';

class VerifyEmailPage extends StatelessWidget {
  const VerifyEmailPage({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final isBusy = authProvider.isLoading;
    final email = authProvider.currentUser?.email ?? '';

    return AuthShell(
      title: 'Verify your email',
      subtitle: email.isEmpty
          ? 'Open the verification message we sent you, then come back here to continue.'
          : 'We sent a verification link to $email. Confirm it, then refresh your access.',
      topBadgeIcon: Icons.mark_email_read_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ElevatedButton(
            onPressed: isBusy
                ? null
                : () =>
                      context.read<AuthProvider>().refreshVerificationStatus(),
            child: Text(
              isBusy ? 'Checking verification...' : 'I have verified my email',
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: isBusy
                ? null
                : () => context.read<AuthProvider>().resendVerificationEmail(),
            child: const Text('Resend verification email'),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: isBusy
                ? null
                : () => context.read<AuthProvider>().signOut(),
            child: const Text('Sign out'),
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
    );
  }
}
