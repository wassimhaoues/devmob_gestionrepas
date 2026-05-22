import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/auth_status.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth/auth_validators.dart';
import '../../widgets/auth_shell.dart';

const String registerRoute = '/register';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _displayNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authProvider = context.read<AuthProvider>();
    await authProvider.register(
      email: _emailController.text,
      password: _passwordController.text,
      displayName: _displayNameController.text,
    );

    if (!mounted) {
      return;
    }

    if (authProvider.failure == null &&
        (authProvider.status == AuthStatus.emailVerificationRequired ||
            authProvider.status == AuthStatus.authenticated)) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final isBusy = authProvider.isLoading;

    return AuthShell(
      title: 'Create your account',
      subtitle:
          'Set up your cooking workspace so recipes, meal plans, and shopping lists stay connected.',
      topBadgeIcon: Icons.auto_awesome_rounded,
      footer: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        runSpacing: 0,
        children: <Widget>[
          const Text('Already have an account?'),
          TextButton(
            onPressed: isBusy ? null : () => Navigator.of(context).pop(),
            child: const Text('Sign in'),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TextFormField(
              controller: _displayNameController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Display name',
                hintText: 'How should we call you?',
              ),
              validator: AuthValidators.validateDisplayName,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'you@example.com',
              ),
              validator: AuthValidators.validateEmail,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Password',
                hintText: 'Choose a secure password',
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                  icon: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                  ),
                ),
              ),
              validator: AuthValidators.validatePassword,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirmPassword,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: 'Confirm password',
                hintText: 'Repeat your password',
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(
                      () => _obscureConfirmPassword = !_obscureConfirmPassword,
                    );
                  },
                  icon: Icon(
                    _obscureConfirmPassword
                        ? Icons.visibility
                        : Icons.visibility_off,
                  ),
                ),
              ),
              validator: (String? value) =>
                  AuthValidators.validateConfirmPassword(
                    password: _passwordController.text,
                    confirmPassword: value ?? '',
                  ),
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: isBusy ? null : _submit,
              child: Text(isBusy ? 'Creating account...' : 'Create account'),
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
