import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/auth_status.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_panels.dart';
import '../dashboard/dashboard_page.dart';
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
        return const DashboardPage();
    }
  }
}

class _AuthLoadingView extends StatelessWidget {
  const _AuthLoadingView();

  @override
  Widget build(BuildContext context) {
    return const AppScaffold(
      useAppBar: false,
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: AppLoadingState(
            message: 'Preparing your meal planner...',
            icon: Icons.restaurant_menu_rounded,
          ),
        ),
      ),
    );
  }
}
