import 'dart:async';
import 'dart:typed_data';

import 'package:devmob_gestionrepas/models/app_user.dart';
import 'package:devmob_gestionrepas/models/auth_failure.dart';
import 'package:devmob_gestionrepas/models/auth_status.dart';
import 'package:devmob_gestionrepas/models/meal_plan_entry.dart';
import 'package:devmob_gestionrepas/models/processed_recipe_image.dart';
import 'package:devmob_gestionrepas/models/recipe.dart';
import 'package:devmob_gestionrepas/models/recipe_category.dart';
import 'package:devmob_gestionrepas/models/recipe_image_upload_result.dart';
import 'package:devmob_gestionrepas/providers/auth_provider.dart';
import 'package:devmob_gestionrepas/providers/meal_plan_provider.dart';
import 'package:devmob_gestionrepas/providers/recipe_provider.dart';
import 'package:devmob_gestionrepas/providers/shopping_list_provider.dart';
import 'package:devmob_gestionrepas/services/auth/auth_service.dart';
import 'package:devmob_gestionrepas/services/auth/firebase_auth_error_mapper.dart';
import 'package:devmob_gestionrepas/services/auth/user_profile_service.dart';
import 'package:devmob_gestionrepas/services/mealplan/meal_plan_service.dart';
import 'package:devmob_gestionrepas/services/recipe/recipe_image_processor.dart';
import 'package:devmob_gestionrepas/services/recipe/recipe_image_storage_service.dart';
import 'package:devmob_gestionrepas/services/recipe/recipe_service.dart';
import 'package:devmob_gestionrepas/services/shopping/local_shopping_list_state_service.dart';
import 'package:devmob_gestionrepas/services/shopping/shopping_list_generator_service.dart';
import 'package:devmob_gestionrepas/views/auth/auth_gate.dart';
import 'package:devmob_gestionrepas/views/auth/login_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  late _FakeAuthService authService;
  late _FakeUserProfileService userProfileService;
  late _FakeRecipeService recipeService;
  late _FakeMealPlanService mealPlanService;

  setUp(() {
    authService = _FakeAuthService();
    userProfileService = _FakeUserProfileService();
    recipeService = _FakeRecipeService();
    mealPlanService = _FakeMealPlanService();

    const uid = 'user-1';
    authService.signInUid = uid;
    authService.emailVerifiedValue = true;
    userProfileService.users[uid] = _user(
      uid: uid,
      email: 'user@example.com',
      displayName: 'Flow User',
      emailVerified: true,
    );
  });

  tearDown(() async {
    await authService.dispose();
    await recipeService.dispose();
    await mealPlanService.dispose();
  });

  testWidgets('auth gate swaps between dashboard and login based on auth state', (
    tester,
  ) async {
    final authProvider = AuthProvider(
      authService: authService,
      userProfileService: userProfileService,
      errorMapper: const _TestErrorMapper(),
    );
    final recipeProvider = RecipeProvider(
      recipeService: recipeService,
      mealPlanService: mealPlanService,
      recipeImageStorageService: _NoopRecipeImageStorageService(),
      recipeImageProcessor: _NoopRecipeImageProcessor(),
    );
    final mealPlanProvider = MealPlanProvider(mealPlanService: mealPlanService);
    final shoppingProvider = ShoppingListProvider(
      generatorService: ShoppingListGeneratorService(
        recipeService: recipeService,
      ),
      localStateService: _NoopLocalShoppingListStateService(),
    );

    await authProvider.signIn(
      email: 'user@example.com',
      password: 'password123',
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ChangeNotifierProvider<RecipeProvider>.value(value: recipeProvider),
          ChangeNotifierProvider<MealPlanProvider>.value(value: mealPlanProvider),
          ChangeNotifierProvider<ShoppingListProvider>.value(
            value: shoppingProvider,
          ),
        ],
        child: const MaterialApp(home: AuthGate()),
      ),
    );

    await tester.pump();
    await tester.pump();

    expect(find.text('Plan'), findsOneWidget);
    expect(find.byTooltip('Sign out'), findsOneWidget);

    await authProvider.signOut();
    await tester.pump();
    await tester.pump();

    expect(authProvider.status, AuthStatus.unauthenticated);
    expect(find.byType(LoginPage), findsOneWidget);

    shoppingProvider.dispose();
    mealPlanProvider.dispose();
    recipeProvider.dispose();
    authProvider.dispose();
  });
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
  }) async {
    throw UnimplementedError();
  }

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
    _authStateController.add(currentUserIdValue);
  }

  @override
  Future<void> signOut() async {
    currentUserIdValue = null;
    currentUserEmailValue = null;
    emailVerifiedValue = false;
    _authStateController.add(null);
  }

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
  }) async {
    final current = users[uid];
    if (current == null) {
      return;
    }
    users[uid] = AppUser(
      uid: current.uid,
      email: current.email,
      displayName: current.displayName,
      emailVerified: emailVerified,
      createdAt: current.createdAt,
      updatedAt: current.updatedAt,
      lastLoginAt: current.lastLoginAt,
      photoUrl: current.photoUrl,
      onboardingCompleted: current.onboardingCompleted,
      preferences: current.preferences,
    );
  }

  @override
  Future<void> updateLastLogin(String uid) async {}
}

class _FakeRecipeService implements RecipeService {
  final StreamController<List<Recipe>> _controller =
      StreamController<List<Recipe>>.broadcast();

  Future<void> dispose() async {
    await _controller.close();
  }

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
    return null;
  }

  @override
  Future<List<Recipe>> fetchRecipes({
    required String uid,
    RecipeCategory? category,
    bool favoritesOnly = false,
  }) async {
    return const <Recipe>[];
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
    return _controller.stream;
  }
}

class _FakeMealPlanService implements MealPlanService {
  final StreamController<List<MealPlanEntry>> _controller =
      StreamController<List<MealPlanEntry>>.broadcast();

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
  Future<bool> hasEntriesForRecipe({
    required String uid,
    required String recipeId,
  }) async {
    return false;
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

class _NoopLocalShoppingListStateService
    implements LocalShoppingListStateService {
  @override
  Future<void> clearState({
    required String uid,
    required DateTime weekStartDate,
  }) async {}

  @override
  Future<ShoppingListLocalState> readState({
    required String uid,
    required DateTime weekStartDate,
  }) async {
    return ShoppingListLocalState.empty;
  }

  @override
  Future<void> writeState({
    required String uid,
    required DateTime weekStartDate,
    required ShoppingListLocalState state,
  }) async {}
}

class _NoopRecipeImageStorageService implements RecipeImageStorageService {
  @override
  String buildStoragePath({
    required String uid,
    required String recipeId,
    String fileName = 'cover.webp',
  }) {
    return 'users/$uid/recipes/$recipeId/$fileName';
  }

  @override
  Future<void> deleteRecipeImage(String storagePath) async {}

  @override
  Future<RecipeImageUploadResult> uploadRecipeImage({
    required String uid,
    required String recipeId,
    required Uint8List bytes,
    required String mimeType,
    String fileName = 'cover.webp',
  }) async {
    return RecipeImageUploadResult(
      downloadUrl: 'https://example.com/$recipeId',
      storagePath: buildStoragePath(
        uid: uid,
        recipeId: recipeId,
        fileName: fileName,
      ),
      mimeType: mimeType,
      sizeBytes: bytes.length,
    );
  }
}

class _NoopRecipeImageProcessor implements RecipeImageProcessor {
  @override
  Future<ProcessedRecipeImage> processImage({
    required Uint8List bytes,
    required String originalFileName,
    String? mimeType,
  }) async {
    return ProcessedRecipeImage(
      bytes: bytes,
      mimeType: mimeType ?? 'image/webp',
      fileName: originalFileName,
      width: 1,
      height: 1,
      sourceSizeBytes: bytes.length,
      outputSizeBytes: bytes.length,
    );
  }
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
