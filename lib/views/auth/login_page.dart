import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/auth/auth_validators.dart';
import '../../widgets/auth_shell.dart';
import 'forgot_password_page.dart';
import 'register_page.dart';

const String loginRoute = '/login';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    await context.read<AuthProvider>().signIn(
      email: _emailController.text,
      password: _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final isBusy = authProvider.isLoading;

    return AuthShell(
      title: 'Welcome back',
      subtitle:
          'Sign in to manage recipes, organize your week, and keep your shopping list in sync.',
      footer: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        runSpacing: 0,
        children: <Widget>[
          const Text('New here?'),
          TextButton(
            onPressed: isBusy
                ? null
                : () => Navigator.of(context).pushNamed(registerRoute),
            child: const Text('Create account'),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
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
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: 'Password',
                hintText: 'Enter your password',
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
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: isBusy ? null : _submit,
              child: Text(isBusy ? 'Signing in...' : 'Sign in'),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: isBusy
                    ? null
                    : () =>
                          Navigator.of(context).pushNamed(forgotPasswordRoute),
                child: const Text('Forgot password?'),
              ),
            ),
            if (authProvider.failure != null) ...<Widget>[
              const SizedBox(height: 10),
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
