import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/auth_status.dart';
import '../../providers/auth_provider.dart';
import 'login_page.dart';
import 'verify_email_page.dart';

const String authGateRoute = '/auth-gate';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    switch (authProvider.status) {
      case AuthStatus.initial:
      case AuthStatus.checkingSession:
      case AuthStatus.authenticating:
        return const _AuthLoadingView();
      case AuthStatus.unauthenticated:
      case AuthStatus.error:
        return const LoginPage();
      case AuthStatus.emailVerificationRequired:
        return const VerifyEmailPage();
      case AuthStatus.authenticated:
        return const _AuthenticatedPlaceholderPage();
    }
  }
}

class _AuthLoadingView extends StatelessWidget {
  const _AuthLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _AuthenticatedPlaceholderPage extends StatelessWidget {
  const _AuthenticatedPlaceholderPage();

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final userName = authProvider.currentUser?.displayName;
    final greeting = (userName != null && userName.isNotEmpty)
        ? 'Welcome, $userName'
        : 'Welcome';

    return Scaffold(
      appBar: AppBar(title: const Text('DEVMOB-GestionRepas')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(greeting),
              const SizedBox(height: 12),
              const Text(
                'Authentication is connected. Recipe and meal planning modules come next.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: authProvider.isLoading
                    ? null
                    : () => authProvider.signOut(),
                child: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
