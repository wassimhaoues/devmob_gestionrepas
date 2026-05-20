import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/meal_plan_provider.dart';
import 'providers/recipe_provider.dart';
import 'providers/shopping_list_provider.dart';
import 'services/auth/auth_service.dart';
import 'services/auth/firebase_auth_service.dart';
import 'services/auth/firestore_user_profile_service.dart';
import 'services/auth/user_profile_service.dart';
import 'services/mealplan/firestore_meal_plan_service.dart';
import 'services/mealplan/meal_plan_service.dart';
import 'services/recipe/default_recipe_image_processor.dart';
import 'services/recipe/firebase_recipe_image_storage_service.dart';
import 'services/recipe/firestore_recipe_service.dart';
import 'services/recipe/recipe_image_processor.dart';
import 'services/recipe/recipe_image_storage_service.dart';
import 'services/recipe/recipe_service.dart';
import 'services/shopping/local_shopping_list_state_service.dart';
import 'services/shopping/shared_prefs_shopping_list_state_service.dart';
import 'services/shopping/shopping_list_generator_service.dart';
import 'theme/app_theme.dart';
import 'views/auth/auth_gate.dart';
import 'views/auth/forgot_password_page.dart';
import 'views/auth/login_page.dart';
import 'views/auth/register_page.dart';
import 'views/auth/verify_email_page.dart';
import 'views/dashboard/dashboard_page.dart';
import 'views/mealplan/assign_recipe_page.dart';
import 'views/mealplan/meal_plan_page.dart';
import 'views/recipe/add_recipe_page.dart';
import 'views/recipe/edit_recipe_page.dart';
import 'views/recipe/recipe_detail_page.dart';
import 'views/recipe/recipe_list_page.dart';
import 'views/shopping/shopping_list_page.dart';

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
        Provider<MealPlanService>(create: (_) => FirestoreMealPlanService()),
        Provider<RecipeService>(create: (_) => FirestoreRecipeService()),
        Provider<LocalShoppingListStateService>(
          create: (_) => SharedPrefsShoppingListStateService(),
        ),
        Provider<RecipeImageStorageService>(
          create: (_) => FirebaseRecipeImageStorageService(),
        ),
        Provider<RecipeImageProcessor>(
          create: (_) => DefaultRecipeImageProcessor(),
        ),
        Provider<ShoppingListGeneratorService>(
          create: (BuildContext context) => ShoppingListGeneratorService(
            recipeService: context.read<RecipeService>(),
          ),
        ),
        ChangeNotifierProvider<AuthProvider>(
          create: (BuildContext context) => AuthProvider(
            authService: context.read<AuthService>(),
            userProfileService: context.read<UserProfileService>(),
          )..initialize(),
        ),
        ChangeNotifierProvider<RecipeProvider>(
          create: (BuildContext context) => RecipeProvider(
            recipeService: context.read<RecipeService>(),
            mealPlanService: context.read<MealPlanService>(),
            recipeImageStorageService: context
                .read<RecipeImageStorageService>(),
            recipeImageProcessor: context.read<RecipeImageProcessor>(),
          ),
        ),
        ChangeNotifierProvider<MealPlanProvider>(
          create: (BuildContext context) => MealPlanProvider(
            mealPlanService: context.read<MealPlanService>(),
          ),
        ),
        ChangeNotifierProvider<ShoppingListProvider>(
          create: (BuildContext context) => ShoppingListProvider(
            generatorService: context.read<ShoppingListGeneratorService>(),
            localStateService: context.read<LocalShoppingListStateService>(),
          ),
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
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routes: <String, WidgetBuilder>{
        authGateRoute: (_) => const AuthGate(),
        loginRoute: (_) => const LoginPage(),
        registerRoute: (_) => const RegisterPage(),
        forgotPasswordRoute: (_) => const ForgotPasswordPage(),
        verifyEmailRoute: (_) => const VerifyEmailPage(),
        dashboardRoute: (_) => const DashboardPage(),
        recipeListRoute: (_) => const RecipeListPage(),
        favoriteRecipesRoute: (_) => const RecipeListPage(
          pageTitle: 'Favorite Recipes',
          favoritesOnlyView: true,
        ),
        mealPlanRoute: (_) => const MealPlanPage(),
        assignRecipeRoute: (_) => const AssignRecipePage(),
        shoppingListRoute: (_) => const ShoppingListPage(),
        addRecipeRoute: (_) => const AddRecipePage(),
        recipeDetailRoute: (_) => const RecipeDetailPage(),
        editRecipeRoute: (_) => const EditRecipePage(),
      },
      home: const AuthGate(),
    );
  }
}
