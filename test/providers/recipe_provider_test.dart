import 'dart:async';

import 'package:devmob_gestionrepas/models/ingredient.dart';
import 'package:devmob_gestionrepas/models/recipe.dart';
import 'package:devmob_gestionrepas/models/recipe_category.dart';
import 'package:devmob_gestionrepas/models/recipe_step.dart';
import 'package:devmob_gestionrepas/providers/recipe_provider.dart';
import 'package:devmob_gestionrepas/services/recipe/recipe_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _FakeRecipeService recipeService;

  setUp(() {
    recipeService = _FakeRecipeService();
  });

  tearDown(() async {
    await recipeService.dispose();
  });

  test('startWatching listens to stream and updates list state', () async {
    final provider = RecipeProvider(recipeService: recipeService);

    await provider.startWatching(uid: 'user-1');
    expect(provider.status, RecipeProviderStatus.loading);

    recipeService.emitRecipes(<Recipe>[
      _sampleRecipe(id: 'r1', ownerUid: 'user-1'),
    ]);
    await _flushAsync();

    expect(provider.status, RecipeProviderStatus.ready);
    expect(provider.recipes.length, 1);
    expect(provider.recipes.first.id, 'r1');
    provider.dispose();
  });

  test('setCategoryFilter restarts watcher with selected category', () async {
    final provider = RecipeProvider(recipeService: recipeService);

    await provider.startWatching(uid: 'user-1');
    await provider.setCategoryFilter(RecipeCategory.dinner);

    expect(recipeService.lastWatchUid, 'user-1');
    expect(recipeService.lastWatchCategory, RecipeCategory.dinner);
    provider.dispose();
  });

  test(
    'createRecipe normalizes ingredient values before persistence',
    () async {
      final provider = RecipeProvider(recipeService: recipeService);
      await provider.startWatching(uid: 'user-1');

      final errors = await provider.createRecipe(
        title: 'Tomato Soup',
        description: 'Simple soup',
        category: RecipeCategory.lunch,
        ingredients: const <Ingredient>[
          Ingredient(
            displayName: '  Tómatoes  ',
            canonicalName: '',
            quantity: 2,
            unit: '  pieces  ',
          ),
        ],
        steps: const <RecipeStep>[
          RecipeStep(order: 10, text: '  boil   water  '),
        ],
      );

      expect(errors, isEmpty);
      final created = recipeService.lastCreatedRecipe;
      expect(created, isNotNull);
      expect(created!.ingredients.first.displayName, 'Tómatoes');
      expect(created.ingredients.first.canonicalName, 'tomato');
      expect(created.ingredients.first.unit, 'pieces');
      expect(created.steps.first.order, 1);
      expect(created.steps.first.text, 'boil water');
      provider.dispose();
    },
  );

  test('createRecipe returns validation errors for invalid payload', () async {
    final provider = RecipeProvider(recipeService: recipeService);
    await provider.startWatching(uid: 'user-1');

    final errors = await provider.createRecipe(
      title: '  ',
      description: null,
      category: null,
      ingredients: const <Ingredient>[],
      steps: const <RecipeStep>[],
    );

    expect(errors, isNotEmpty);
    expect(provider.status, RecipeProviderStatus.error);
    expect(provider.errorMessage, isNotNull);
    provider.dispose();
  });

  test('toggleFavorite delegates to service', () async {
    final provider = RecipeProvider(recipeService: recipeService);
    await provider.startWatching(uid: 'user-1');

    final result = await provider.toggleFavorite(
      recipeId: 'recipe-99',
      isFavorite: true,
    );

    expect(result, isTrue);
    expect(recipeService.lastFavoriteRecipeId, 'recipe-99');
    expect(recipeService.lastFavoriteValue, isTrue);
    provider.dispose();
  });
}

Future<void> _flushAsync() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

class _FakeRecipeService implements RecipeService {
  final StreamController<List<Recipe>> _controller =
      StreamController<List<Recipe>>.broadcast();

  String? lastWatchUid;
  RecipeCategory? lastWatchCategory;
  bool? lastWatchFavoritesOnly;

  String? lastCreatedUid;
  Recipe? lastCreatedRecipe;

  String? lastUpdatedUid;
  Recipe? lastUpdatedRecipe;

  String? lastDeletedUid;
  String? lastDeletedRecipeId;

  String? lastFavoriteUid;
  String? lastFavoriteRecipeId;
  bool? lastFavoriteValue;

  List<Recipe> fetchResult = const <Recipe>[];

  @override
  Stream<List<Recipe>> watchRecipes({
    required String uid,
    RecipeCategory? category,
    bool favoritesOnly = false,
  }) {
    lastWatchUid = uid;
    lastWatchCategory = category;
    lastWatchFavoritesOnly = favoritesOnly;
    return _controller.stream;
  }

  @override
  Future<List<Recipe>> fetchRecipes({
    required String uid,
    RecipeCategory? category,
    bool favoritesOnly = false,
  }) async {
    return fetchResult;
  }

  @override
  Future<Recipe?> fetchRecipeById({
    required String uid,
    required String recipeId,
  }) async {
    return null;
  }

  @override
  Future<String> createRecipe({
    required String uid,
    required Recipe recipe,
  }) async {
    lastCreatedUid = uid;
    lastCreatedRecipe = recipe;
    return 'new-recipe-id';
  }

  @override
  Future<void> updateRecipe({
    required String uid,
    required Recipe recipe,
  }) async {
    lastUpdatedUid = uid;
    lastUpdatedRecipe = recipe;
  }

  @override
  Future<void> deleteRecipe({
    required String uid,
    required String recipeId,
  }) async {
    lastDeletedUid = uid;
    lastDeletedRecipeId = recipeId;
  }

  @override
  Future<void> setFavorite({
    required String uid,
    required String recipeId,
    required bool isFavorite,
  }) async {
    lastFavoriteUid = uid;
    lastFavoriteRecipeId = recipeId;
    lastFavoriteValue = isFavorite;
  }

  void emitRecipes(List<Recipe> recipes) {
    _controller.add(recipes);
  }

  Future<void> dispose() async {
    await _controller.close();
  }
}

Recipe _sampleRecipe({required String id, required String ownerUid}) {
  final now = DateTime.now();
  return Recipe(
    id: id,
    ownerUid: ownerUid,
    title: 'Sample',
    description: 'Sample description',
    category: RecipeCategory.breakfast,
    isFavorite: false,
    ingredients: const <Ingredient>[
      Ingredient(
        displayName: 'Eggs',
        canonicalName: 'egg',
        quantity: 2,
        unit: 'piece',
      ),
    ],
    steps: const <RecipeStep>[RecipeStep(order: 1, text: 'Cook')],
    createdAt: now,
    updatedAt: now,
  );
}
