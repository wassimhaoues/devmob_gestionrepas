import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/recipe_provider.dart';
import 'services/auth/auth_service.dart';
import 'services/auth/firebase_auth_service.dart';
import 'services/auth/firestore_user_profile_service.dart';
import 'services/auth/user_profile_service.dart';
import 'services/recipe/firestore_recipe_service.dart';
import 'services/recipe/recipe_service.dart';
import 'views/auth/auth_gate.dart';
import 'views/auth/forgot_password_page.dart';
import 'views/auth/login_page.dart';
import 'views/auth/register_page.dart';
import 'views/auth/verify_email_page.dart';
import 'views/dashboard/dashboard_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(
    MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => FirebaseAuthService()),
        Provider<UserProfileService>(
          create: (_) => FirestoreUserProfileService(),
        ),
        Provider<RecipeService>(create: (_) => FirestoreRecipeService()),
        ChangeNotifierProvider<AuthProvider>(
          create: (context) => AuthProvider(
            authService: context.read<AuthService>(),
            userProfileService: context.read<UserProfileService>(),
          )..initialize(),
        ),
        ChangeNotifierProvider<RecipeProvider>(
          create: (context) =>
              RecipeProvider(recipeService: context.read<RecipeService>()),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DEVMOB-GestionRepas',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      routes: {
        authGateRoute: (_) => const AuthGate(),
        loginRoute: (_) => const LoginPage(),
        registerRoute: (_) => const RegisterPage(),
        forgotPasswordRoute: (_) => const ForgotPasswordPage(),
        verifyEmailRoute: (_) => const VerifyEmailPage(),
        dashboardRoute: (_) => const DashboardPage(),
      },
      home: const AuthGate(),
    );
  }
}
