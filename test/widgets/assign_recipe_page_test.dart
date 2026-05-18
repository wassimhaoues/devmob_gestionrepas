import 'dart:async';

import 'package:devmob_gestionrepas/models/app_user.dart';
import 'package:devmob_gestionrepas/models/auth_failure.dart';
import 'package:devmob_gestionrepas/models/ingredient.dart';
import 'package:devmob_gestionrepas/models/meal_plan_assignment_args.dart';
import 'package:devmob_gestionrepas/models/meal_plan_entry.dart';
import 'package:devmob_gestionrepas/models/meal_slot_type.dart';
import 'package:devmob_gestionrepas/models/recipe.dart';
import 'package:devmob_gestionrepas/models/recipe_category.dart';
import 'package:devmob_gestionrepas/models/recipe_step.dart';
import 'package:devmob_gestionrepas/providers/auth_provider.dart';
import 'package:devmob_gestionrepas/providers/meal_plan_provider.dart';
import 'package:devmob_gestionrepas/services/auth/auth_service.dart';
import 'package:devmob_gestionrepas/services/auth/firebase_auth_error_mapper.dart';
import 'package:devmob_gestionrepas/services/auth/user_profile_service.dart';
import 'package:devmob_gestionrepas/services/mealplan/meal_plan_service.dart';
import 'package:devmob_gestionrepas/services/recipe/recipe_service.dart';
import 'package:devmob_gestionrepas/views/mealplan/assign_recipe_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  late _FakeAuthService authService;
  late _FakeUserProfileService userProfileService;
  late _FakeMealPlanService mealPlanService;
  late _FakeRecipeService recipeService;

  setUp(() {
    authService = _FakeAuthService();
    userProfileService = _FakeUserProfileService();
    mealPlanService = _FakeMealPlanService();
    recipeService = _FakeRecipeService();

    const uid = 'user-1';
    authService.signInUid = uid;
    authService.emailVerifiedValue = true;
    userProfileService.users[uid] = _user(
      uid: uid,
      email: 'user@example.com',
      displayName: 'Meal User',
      emailVerified: true,
    );
  });

  tearDown(() async {
    await authService.dispose();
  });

  testWidgets('filters recipes by search and favorites', (tester) async {
    final authProvider = AuthProvider(
      authService: authService,
      userProfileService: userProfileService,
      errorMapper: const _TestErrorMapper(),
    );
    await authProvider.signIn(email: 'user@example.com', password: 'password123');

    recipeService.recipes = <Recipe>[
      _recipe(id: '1', title: 'Tomato Soup', isFavorite: false),
      _recipe(id: '2', title: 'Favorite Pasta', isFavorite: true),
    ];

    final mealPlanProvider = MealPlanProvider(mealPlanService: mealPlanService);
    await mealPlanProvider.startWatchingWeek(
      uid: 'user-1',
      anchorDate: DateTime(2026, 5, 19),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<RecipeService>.value(value: recipeService),
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ChangeNotifierProvider<MealPlanProvider>.value(value: mealPlanProvider),
        ],
        child: MaterialApp(
          home: AssignRecipePage(
            args: MealPlanAssignmentArgs(
              date: DateTime(2026, 5, 19),
              slotType: MealSlotType.lunch,
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Tomato Soup'), findsOneWidget);
    expect(find.text('Favorite Pasta'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'favorite');
    await tester.pump();
    expect(find.text('Tomato Soup'), findsNothing);
    expect(find.text('Favorite Pasta'), findsOneWidget);

    await tester.tap(find.byType(FilterChip));
    await tester.pump();
    expect(find.text('Favorite Pasta'), findsOneWidget);

    mealPlanProvider.dispose();
    authProvider.dispose();
  });

  testWidgets('assigns a tapped recipe to the selected slot', (tester) async {
    final authProvider = AuthProvider(
      authService: authService,
      userProfileService: userProfileService,
      errorMapper: const _TestErrorMapper(),
    );
    await authProvider.signIn(email: 'user@example.com', password: 'password123');

    recipeService.recipes = <Recipe>[
      _recipe(id: '1', title: 'Tomato Soup', isFavorite: false),
    ];

    final mealPlanProvider = MealPlanProvider(mealPlanService: mealPlanService);
    await mealPlanProvider.startWatchingWeek(
      uid: 'user-1',
      anchorDate: DateTime(2026, 5, 19),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<RecipeService>.value(value: recipeService),
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ChangeNotifierProvider<MealPlanProvider>.value(value: mealPlanProvider),
        ],
        child: MaterialApp(
          home: AssignRecipePage(
            args: MealPlanAssignmentArgs(
              date: DateTime(2026, 5, 19),
              slotType: MealSlotType.dinner,
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('Tomato Soup'));
    await tester.pump();

    expect(mealPlanProvider.entryFor(
      date: DateTime(2026, 5, 19),
      slotType: MealSlotType.dinner,
    )?.recipeTitle, 'Tomato Soup');

    mealPlanProvider.dispose();
    authProvider.dispose();
  });
}

Recipe _recipe({
  required String id,
  required String title,
  required bool isFavorite,
}) {
  return Recipe(
    id: id,
    ownerUid: 'user-1',
    title: title,
    description: 'Recipe description',
    category: RecipeCategory.lunch,
    isFavorite: isFavorite,
    ingredients: const <Ingredient>[
      Ingredient(
        displayName: 'Tomato',
        canonicalName: 'tomato',
        quantity: 1,
        unit: 'piece',
      ),
    ],
    steps: const <RecipeStep>[RecipeStep(order: 1, text: 'Cook')],
    createdAt: DateTime(2026, 5, 1),
    updatedAt: DateTime(2026, 5, 2),
  );
}

class _FakeRecipeService implements RecipeService {
  List<Recipe> recipes = const <Recipe>[];

  @override
  Future<String> createRecipe({
    required String uid,
    required Recipe recipe,
  }) async => 'unused';

  @override
  Future<void> deleteRecipe({
    required String uid,
    required String recipeId,
  }) async {}

  @override
  Future<Recipe?> fetchRecipeById({
    required String uid,
    required String recipeId,
  }) async => null;

  @override
  Future<List<Recipe>> fetchRecipes({
    required String uid,
    RecipeCategory? category,
    bool favoritesOnly = false,
  }) async => recipes;

  @override
  Future<void> setFavorite({
    required String uid,
    required String recipeId,
    required bool isFavorite,
  }) async {}

  @override
  Future<void> updateRecipe({
    required String uid,
    required Recipe recipe,
  }) async {}

  @override
  Stream<List<Recipe>> watchRecipes({
    required String uid,
    RecipeCategory? category,
    bool favoritesOnly = false,
  }) => const Stream<List<Recipe>>.empty();
}

class _FakeMealPlanService implements MealPlanService {
  @override
  Future<void> deleteEntry({
    required String uid,
    required String entryId,
  }) async {}

  @override
  Future<List<MealPlanEntry>> fetchEntries({
    required String uid,
    required DateTime startDate,
    required DateTime endDate,
  }) async => const <MealPlanEntry>[];

  @override
  Future<void> upsertEntry({
    required String uid,
    required MealPlanEntry entry,
  }) async {}

  @override
  Stream<List<MealPlanEntry>> watchEntries({
    required String uid,
    required DateTime startDate,
    required DateTime endDate,
  }) => const Stream<List<MealPlanEntry>>.empty();
}

class _FakeAuthService implements AuthService {
  final StreamController<String?> _authStateController =
      StreamController<String?>.broadcast();

  String? currentUserIdValue;
  String? currentUserEmailValue;
  bool emailVerifiedValue = false;
  String signInUid = 'user-1';

  @override
  Stream<String?> authStateChanges() => _authStateController.stream;

  @override
  String? get currentUserDisplayName => null;

  @override
  String? get currentUserEmail => currentUserEmailValue;

  @override
  String? get currentUserId => currentUserIdValue;

  @override
  bool get isEmailVerified => emailVerifiedValue;

  @override
  Future<String> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async => 'unused';

  @override
  Future<void> reloadCurrentUser() async {}

  @override
  Future<void> sendEmailVerification() async {}

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    currentUserIdValue = signInUid;
    currentUserEmailValue = email.trim().toLowerCase();
  }

  @override
  Future<void> signOut() async {}

  Future<void> dispose() async {
    await _authStateController.close();
  }
}

class _FakeUserProfileService implements UserProfileService {
  final Map<String, AppUser> users = <String, AppUser>{};

  @override
  Future<void> createInitialProfile({
    required String uid,
    required String email,
    required String displayName,
  }) async {}

  @override
  Future<AppUser?> fetchUserById(String uid) async => users[uid];

  @override
  Future<void> updateEmailVerificationStatus({
    required String uid,
    required bool emailVerified,
  }) async {}

  @override
  Future<void> updateLastLogin(String uid) async {}
}

class _TestErrorMapper implements FirebaseAuthErrorMapper {
  const _TestErrorMapper();

  @override
  AuthFailure map(Object exception) {
    return const AuthFailure(
      code: AuthFailureCode.unknown,
      message: 'Unexpected error.',
    );
  }
}

AppUser _user({
  required String uid,
  required String email,
  required String displayName,
  required bool emailVerified,
}) {
  final now = DateTime.now();
  return AppUser(
    uid: uid,
    email: email,
    displayName: displayName,
    emailVerified: emailVerified,
    createdAt: now,
    updatedAt: now,
    lastLoginAt: now,
    onboardingCompleted: false,
    preferences: const <String, dynamic>{},
    photoUrl: null,
  );
}
