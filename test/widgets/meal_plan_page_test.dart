import 'dart:async';

import 'package:devmob_gestionrepas/models/app_user.dart';
import 'package:devmob_gestionrepas/models/auth_failure.dart';
import 'package:devmob_gestionrepas/models/meal_plan_entry.dart';
import 'package:devmob_gestionrepas/models/meal_slot_type.dart';
import 'package:devmob_gestionrepas/models/recipe_category.dart';
import 'package:devmob_gestionrepas/providers/auth_provider.dart';
import 'package:devmob_gestionrepas/providers/meal_plan_provider.dart';
import 'package:devmob_gestionrepas/services/auth/auth_service.dart';
import 'package:devmob_gestionrepas/services/auth/firebase_auth_error_mapper.dart';
import 'package:devmob_gestionrepas/services/auth/user_profile_service.dart';
import 'package:devmob_gestionrepas/services/mealplan/meal_plan_service.dart';
import 'package:devmob_gestionrepas/views/mealplan/meal_plan_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  late _FakeAuthService authService;
  late _FakeUserProfileService userProfileService;
  late _FakeMealPlanService mealPlanService;

  setUp(() {
    authService = _FakeAuthService();
    userProfileService = _FakeUserProfileService();
    mealPlanService = _FakeMealPlanService();

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
    await mealPlanService.dispose();
  });

  testWidgets('shows empty-week guidance and slot prompts', (tester) async {
    final authProvider = AuthProvider(
      authService: authService,
      userProfileService: userProfileService,
      errorMapper: const _TestErrorMapper(),
    );
    await authProvider.signIn(email: 'user@example.com', password: 'password123');

    final mealPlanProvider = MealPlanProvider(mealPlanService: mealPlanService);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ChangeNotifierProvider<MealPlanProvider>.value(value: mealPlanProvider),
        ],
        child: const MaterialApp(home: Scaffold(body: MealPlanPage())),
      ),
    );

    await tester.pump();
    await tester.pump();
    mealPlanService.emitEntries(const <MealPlanEntry>[]);
    await tester.pumpAndSettle();

    expect(find.text('Your week is empty'), findsOneWidget);
    expect(find.text('Tap to assign a recipe'), findsNWidgets(3));

    mealPlanProvider.dispose();
    authProvider.dispose();
  });

  testWidgets('renders assigned meals from provider stream', (tester) async {
    final authProvider = AuthProvider(
      authService: authService,
      userProfileService: userProfileService,
      errorMapper: const _TestErrorMapper(),
    );
    await authProvider.signIn(email: 'user@example.com', password: 'password123');

    final mealPlanProvider = MealPlanProvider(mealPlanService: mealPlanService);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ChangeNotifierProvider<MealPlanProvider>.value(value: mealPlanProvider),
        ],
        child: const MaterialApp(home: Scaffold(body: MealPlanPage())),
      ),
    );

    await tester.pump();
    await tester.pump();
    mealPlanService.emitEntries(<MealPlanEntry>[
      _sampleEntry(
        date: DateTime.now(),
        slotType: MealSlotType.breakfast,
        recipeTitle: 'Overnight Oats',
      ),
    ]);
    await tester.pumpAndSettle();

    expect(find.text('Overnight Oats'), findsOneWidget);
    expect(find.text('Tap to assign a recipe'), findsNWidgets(2));

    mealPlanProvider.dispose();
    authProvider.dispose();
  });
}

MealPlanEntry _sampleEntry({
  required DateTime date,
  required MealSlotType slotType,
  required String recipeTitle,
}) {
  return MealPlanEntry(
    id: MealPlanEntry.buildId(date: date, slotType: slotType, recipeId: 'recipe-1'),
    ownerUid: 'user-1',
    date: date,
    slotType: slotType,
    recipeId: 'recipe-1',
    recipeTitle: recipeTitle,
    recipeImageUrl: null,
    recipeCategory: RecipeCategory.breakfast,
    createdAt: DateTime(2026, 5, 1),
    updatedAt: DateTime(2026, 5, 2),
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
