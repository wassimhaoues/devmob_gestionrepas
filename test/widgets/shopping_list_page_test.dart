import 'dart:async';

import 'package:devmob_gestionrepas/models/app_user.dart';
import 'package:devmob_gestionrepas/models/auth_failure.dart';
import 'package:devmob_gestionrepas/models/ingredient.dart';
import 'package:devmob_gestionrepas/models/meal_plan_entry.dart';
import 'package:devmob_gestionrepas/models/meal_slot_type.dart';
import 'package:devmob_gestionrepas/models/recipe.dart';
import 'package:devmob_gestionrepas/models/recipe_category.dart';
import 'package:devmob_gestionrepas/providers/auth_provider.dart';
import 'package:devmob_gestionrepas/providers/meal_plan_provider.dart';
import 'package:devmob_gestionrepas/providers/shopping_list_provider.dart';
import 'package:devmob_gestionrepas/services/auth/auth_service.dart';
import 'package:devmob_gestionrepas/services/auth/firebase_auth_error_mapper.dart';
import 'package:devmob_gestionrepas/services/auth/user_profile_service.dart';
import 'package:devmob_gestionrepas/services/mealplan/meal_plan_service.dart';
import 'package:devmob_gestionrepas/services/recipe/recipe_service.dart';
import 'package:devmob_gestionrepas/services/shopping/local_shopping_list_state_service.dart';
import 'package:devmob_gestionrepas/services/shopping/shopping_list_generator_service.dart';
import 'package:devmob_gestionrepas/views/shopping/shopping_list_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  late _FakeAuthService authService;
  late _FakeUserProfileService userProfileService;
  late _FakeMealPlanService mealPlanService;
  late _FakeRecipeService recipeService;
  late _FakeLocalShoppingListStateService localStateService;

  setUp(() {
    authService = _FakeAuthService();
    userProfileService = _FakeUserProfileService();
    mealPlanService = _FakeMealPlanService();
    recipeService = _FakeRecipeService();
    localStateService = _FakeLocalShoppingListStateService();

    const uid = 'user-1';
    authService.signInUid = uid;
    authService.emailVerifiedValue = true;
    userProfileService.users[uid] = _user(
      uid: uid,
      email: 'user@example.com',
      displayName: 'Shop User',
      emailVerified: true,
    );
  });

  tearDown(() async {
    await authService.dispose();
    await mealPlanService.dispose();
  });

  testWidgets('shows empty-state guidance when no meals are planned', (
    tester,
  ) async {
    final authProvider = await _buildAuthProvider(
      authService: authService,
      userProfileService: userProfileService,
    );
    final mealPlanProvider = MealPlanProvider(mealPlanService: mealPlanService);
    final shoppingProvider = ShoppingListProvider(
      generatorService: ShoppingListGeneratorService(
        recipeService: recipeService,
      ),
      localStateService: localStateService,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ChangeNotifierProvider<MealPlanProvider>.value(
            value: mealPlanProvider,
          ),
          ChangeNotifierProvider<ShoppingListProvider>.value(
            value: shoppingProvider,
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: ShoppingListPage())),
      ),
    );

    mealPlanService.emitEntries(const <MealPlanEntry>[]);
    await tester.pumpAndSettle();

    expect(find.text('No planned meals for this week'), findsOneWidget);
    expect(find.textContaining('Plan at least one recipe'), findsOneWidget);

    shoppingProvider.dispose();
    mealPlanProvider.dispose();
    authProvider.dispose();
  });

  testWidgets('renders generated items and keeps checkbox state in sync', (
    tester,
  ) async {
    final authProvider = await _buildAuthProvider(
      authService: authService,
      userProfileService: userProfileService,
    );
    final mealPlanProvider = MealPlanProvider(mealPlanService: mealPlanService);
    final shoppingProvider = ShoppingListProvider(
      generatorService: ShoppingListGeneratorService(
        recipeService: recipeService,
      ),
      localStateService: localStateService,
    );

    recipeService.recipesById['recipe-1'] = _recipe(
      id: 'recipe-1',
      ingredients: const <Ingredient>[
        Ingredient(
          displayName: 'Tomatoes',
          canonicalName: 'tomato',
          quantity: 5,
          unit: 'piece',
        ),
      ],
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ChangeNotifierProvider<MealPlanProvider>.value(
            value: mealPlanProvider,
          ),
          ChangeNotifierProvider<ShoppingListProvider>.value(
            value: shoppingProvider,
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: ShoppingListPage())),
      ),
    );

    mealPlanService.emitEntries(<MealPlanEntry>[_entry(recipeId: 'recipe-1')]);
    await tester.pumpAndSettle();

    expect(find.text('Tomatoes'), findsOneWidget);
    expect(find.text('5 piece'), findsOneWidget);
    expect(find.text('Tap when added to cart'), findsOneWidget);

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();

    expect(shoppingProvider.items.single.isChecked, isTrue);
    expect(localStateService.checkedIds, <String>{'tomato__piece'});
    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('Hide completed'), findsOneWidget);

    await tester.tap(find.text('Hide completed'));
    await tester.pumpAndSettle();

    expect(find.text('Everything is checked off'), findsOneWidget);
    expect(find.text('Tomatoes'), findsNothing);

    shoppingProvider.dispose();
    mealPlanProvider.dispose();
    authProvider.dispose();
  });
}

Future<AuthProvider> _buildAuthProvider({
  required _FakeAuthService authService,
  required _FakeUserProfileService userProfileService,
}) async {
  final authProvider = AuthProvider(
    authService: authService,
    userProfileService: userProfileService,
    errorMapper: const _TestErrorMapper(),
  );
  await authProvider.signIn(email: 'user@example.com', password: 'password123');
  return authProvider;
}

MealPlanEntry _entry({required String recipeId}) {
  return MealPlanEntry(
    id: MealPlanEntry.buildId(
      date: DateTime(2026, 5, 18),
      slotType: MealSlotType.breakfast,
    ),
    ownerUid: 'user-1',
    date: DateTime(2026, 5, 18),
    slotType: MealSlotType.breakfast,
    recipeId: recipeId,
    recipeTitle: 'Recipe $recipeId',
    recipeImageUrl: null,
    recipeCategory: RecipeCategory.breakfast,
    createdAt: DateTime(2026, 5, 1),
    updatedAt: DateTime(2026, 5, 2),
  );
}

Recipe _recipe({required String id, required List<Ingredient> ingredients}) {
  return Recipe(
    id: id,
    ownerUid: 'user-1',
    title: 'Recipe $id',
    description: 'Description',
    category: RecipeCategory.dinner,
    isFavorite: false,
    ingredients: ingredients,
    steps: const [],
    createdAt: DateTime(2026, 5, 1),
    updatedAt: DateTime(2026, 5, 2),
  );
}

AppUser _user({
  required String uid,
  required String email,
  required String displayName,
  required bool emailVerified,
}) {
  return AppUser(
    uid: uid,
    email: email,
    displayName: displayName,
    emailVerified: emailVerified,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

class _FakeMealPlanService implements MealPlanService {
  final StreamController<List<MealPlanEntry>> _controller =
      StreamController<List<MealPlanEntry>>.broadcast();

  void emitEntries(List<MealPlanEntry> entries) {
    _controller.add(entries);
  }

  Future<void> dispose() async {
    await _controller.close();
  }

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
  }) async {
    return const <MealPlanEntry>[];
  }

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
  }) {
    return _controller.stream;
  }
}

class _FakeRecipeService implements RecipeService {
  final Map<String, Recipe> recipesById = <String, Recipe>{};

  @override
  Future<String> createRecipe({
    required String uid,
    required Recipe recipe,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteRecipe({
    required String uid,
    required String recipeId,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<Recipe?> fetchRecipeById({
    required String uid,
    required String recipeId,
  }) async {
    return recipesById[recipeId];
  }

  @override
  Future<List<Recipe>> fetchRecipes({
    required String uid,
    RecipeCategory? category,
    bool favoritesOnly = false,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> setFavorite({
    required String uid,
    required String recipeId,
    required bool isFavorite,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> updateRecipe({
    required String uid,
    required Recipe recipe,
  }) async {
    throw UnimplementedError();
  }

  @override
  Stream<List<Recipe>> watchRecipes({
    required String uid,
    RecipeCategory? category,
    bool favoritesOnly = false,
  }) {
    throw UnimplementedError();
  }
}

class _FakeLocalShoppingListStateService
    implements LocalShoppingListStateService {
  Set<String> checkedIds = <String>{};

  @override
  Future<void> clearCheckedItemIds({
    required String uid,
    required DateTime weekStartDate,
  }) async {
    checkedIds = <String>{};
  }

  @override
  Future<Set<String>> readCheckedItemIds({
    required String uid,
    required DateTime weekStartDate,
  }) async {
    return checkedIds;
  }

  @override
  Future<void> writeCheckedItemIds({
    required String uid,
    required DateTime weekStartDate,
    required Set<String> itemIds,
  }) async {
    checkedIds = itemIds;
  }
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
