import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/auth_status.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
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
    return const Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFFEAF7F0), AppColors.background],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(
                width: 64,
                height: 64,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.restaurant_menu_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
              SizedBox(height: 20),
              CircularProgressIndicator(),
              SizedBox(height: 14),
              Text('Preparing your meal planner...'),
            ],
          ),
        ),
      ),
    );
  }
}
