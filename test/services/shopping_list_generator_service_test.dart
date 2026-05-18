import 'package:devmob_gestionrepas/models/ingredient.dart';
import 'package:devmob_gestionrepas/models/meal_plan_entry.dart';
import 'package:devmob_gestionrepas/models/meal_slot_type.dart';
import 'package:devmob_gestionrepas/models/recipe.dart';
import 'package:devmob_gestionrepas/models/recipe_category.dart';
import 'package:devmob_gestionrepas/services/recipe/recipe_service.dart';
import 'package:devmob_gestionrepas/services/shopping/shopping_list_generator_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _FakeRecipeService recipeService;
  late ShoppingListGeneratorService generatorService;

  setUp(() {
    recipeService = _FakeRecipeService();
    generatorService = ShoppingListGeneratorService(
      recipeService: recipeService,
    );
  });

  test(
    'merges duplicate ingredients when canonical name and unit match',
    () async {
      recipeService.recipesById['recipe-1'] = _recipe(
        id: 'recipe-1',
        ingredients: const <Ingredient>[
          Ingredient(
            displayName: 'Tomatoes',
            canonicalName: 'tomato',
            quantity: 2,
            unit: 'piece',
          ),
        ],
      );
      recipeService.recipesById['recipe-2'] = _recipe(
        id: 'recipe-2',
        ingredients: const <Ingredient>[
          Ingredient(
            displayName: 'Tomato',
            canonicalName: 'tomato',
            quantity: 3,
            unit: 'piece',
          ),
        ],
      );

      final shoppingList = await generatorService.generateForWeek(
        uid: 'user-1',
        weekStartDate: DateTime(2026, 5, 18),
        entries: <MealPlanEntry>[
          _entry(recipeId: 'recipe-1'),
          _entry(recipeId: 'recipe-2', slotType: MealSlotType.lunch),
        ],
      );

      expect(shoppingList.items, hasLength(1));
      expect(shoppingList.items.first.totalQuantity, 5);
      expect(shoppingList.items.first.unit, 'piece');
      expect(shoppingList.items.first.sourceRecipeIds, <String>[
        'recipe-1',
        'recipe-2',
      ]);
    },
  );

  test('keeps rows separate when units differ', () async {
    recipeService.recipesById['recipe-1'] = _recipe(
      id: 'recipe-1',
      ingredients: const <Ingredient>[
        Ingredient(
          displayName: 'Rice',
          canonicalName: 'rice',
          quantity: 1,
          unit: 'kg',
        ),
      ],
    );
    recipeService.recipesById['recipe-2'] = _recipe(
      id: 'recipe-2',
      ingredients: const <Ingredient>[
        Ingredient(
          displayName: 'Rice',
          canonicalName: 'rice',
          quantity: 500,
          unit: 'g',
        ),
      ],
    );

    final shoppingList = await generatorService.generateForWeek(
      uid: 'user-1',
      weekStartDate: DateTime(2026, 5, 18),
      entries: <MealPlanEntry>[
        _entry(recipeId: 'recipe-1'),
        _entry(recipeId: 'recipe-2', slotType: MealSlotType.lunch),
      ],
    );

    expect(shoppingList.items, hasLength(2));
    expect(
      shoppingList.items.map((item) => item.unit),
      containsAll(<String>['kg', 'g']),
    );
  });

  test('counts the same planned recipe once per meal-plan entry', () async {
    recipeService.recipesById['recipe-1'] = _recipe(
      id: 'recipe-1',
      ingredients: const <Ingredient>[
        Ingredient(
          displayName: 'Eggs',
          canonicalName: 'egg',
          quantity: 2,
          unit: 'piece',
        ),
      ],
    );

    final shoppingList = await generatorService.generateForWeek(
      uid: 'user-1',
      weekStartDate: DateTime(2026, 5, 18),
      entries: <MealPlanEntry>[
        _entry(recipeId: 'recipe-1', slotType: MealSlotType.breakfast),
        _entry(recipeId: 'recipe-1', slotType: MealSlotType.lunch),
        _entry(recipeId: 'recipe-1', slotType: MealSlotType.dinner),
      ],
    );

    expect(shoppingList.items, hasLength(1));
    expect(shoppingList.items.first.totalQuantity, 6);
    expect(shoppingList.items.first.sourceRecipeIds, <String>['recipe-1']);
  });
}

MealPlanEntry _entry({
  required String recipeId,
  MealSlotType slotType = MealSlotType.breakfast,
}) {
  return MealPlanEntry(
    id: MealPlanEntry.buildId(date: DateTime(2026, 5, 18), slotType: slotType),
    ownerUid: 'user-1',
    date: DateTime(2026, 5, 18),
    slotType: slotType,
    recipeId: recipeId,
    recipeTitle: 'Recipe $recipeId',
    recipeImageUrl: null,
    recipeCategory: RecipeCategory.dinner,
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
