import 'package:devmob_gestionrepas/models/meal_plan_entry.dart';
import 'package:devmob_gestionrepas/models/meal_plan_week.dart';
import 'package:devmob_gestionrepas/models/recipe.dart';
import 'package:devmob_gestionrepas/models/recipe_category.dart';
import 'package:devmob_gestionrepas/models/shopping_list.dart';
import 'package:devmob_gestionrepas/models/shopping_list_item.dart';
import 'package:devmob_gestionrepas/providers/shopping_list_provider.dart';
import 'package:devmob_gestionrepas/services/shopping/local_shopping_list_state_service.dart';
import 'package:devmob_gestionrepas/services/shopping/shopping_list_generator_service.dart';
import 'package:devmob_gestionrepas/services/recipe/recipe_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _FakeShoppingListGeneratorService generatorService;
  late _FakeLocalShoppingListStateService localStateService;

  setUp(() {
    generatorService = _FakeShoppingListGeneratorService();
    localStateService = _FakeLocalShoppingListStateService();
  });

  ShoppingListProvider buildProvider() {
    return ShoppingListProvider(
      generatorService: generatorService,
      localStateService: localStateService,
    );
  }

  test('loadForWeek applies stored checked state', () async {
    final provider = buildProvider();
    final week = MealPlanWeek.fromAnchor(DateTime(2026, 5, 20));
    generatorService.shoppingList = ShoppingList(
      ownerUid: 'user-1',
      weekStartDate: week.startDate,
      generatedAt: DateTime(2026, 5, 19),
      items: const <ShoppingListItem>[
        ShoppingListItem(
          id: 'tomato__piece',
          canonicalName: 'tomato',
          displayName: 'Tomatoes',
          totalQuantity: 5,
          unit: 'piece',
          isChecked: false,
          sourceRecipeIds: <String>['recipe-1'],
        ),
      ],
    );
    localStateService.checkedIds = <String>{'tomato__piece'};

    await provider.loadForWeek(
      uid: 'user-1',
      week: week,
      entries: const <MealPlanEntry>[],
    );

    expect(provider.status, ShoppingListProviderStatus.ready);
    expect(provider.items.single.isChecked, isTrue);
  });

  test('toggleItem persists the updated checked ids', () async {
    final provider = buildProvider();
    final week = MealPlanWeek.fromAnchor(DateTime(2026, 5, 20));
    generatorService.shoppingList = ShoppingList(
      ownerUid: 'user-1',
      weekStartDate: week.startDate,
      generatedAt: DateTime(2026, 5, 19),
      items: const <ShoppingListItem>[
        ShoppingListItem(
          id: 'milk__l',
          canonicalName: 'milk',
          displayName: 'Milk',
          totalQuantity: 1,
          unit: 'L',
          isChecked: false,
          sourceRecipeIds: <String>['recipe-2'],
        ),
      ],
    );

    await provider.loadForWeek(
      uid: 'user-1',
      week: week,
      entries: const <MealPlanEntry>[],
    );
    await provider.toggleItem('milk__l');

    expect(provider.items.single.isChecked, isTrue);
    expect(localStateService.lastWrittenIds, <String>{'milk__l'});
  });
}

class _FakeShoppingListGeneratorService extends ShoppingListGeneratorService {
  _FakeShoppingListGeneratorService()
    : super(recipeService: _NoopRecipeService());

  late ShoppingList shoppingList;

  @override
  Future<ShoppingList> generateForWeek({
    required String uid,
    required DateTime weekStartDate,
    required List<MealPlanEntry> entries,
  }) async {
    return shoppingList;
  }
}

class _FakeLocalShoppingListStateService
    implements LocalShoppingListStateService {
  Set<String> checkedIds = <String>{};
  Set<String>? lastWrittenIds;

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
    lastWrittenIds = itemIds;
    checkedIds = itemIds;
  }
}

class _NoopRecipeService implements RecipeService {
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
    throw UnimplementedError();
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
