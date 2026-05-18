import 'package:devmob_gestionrepas/models/meal_plan_entry.dart';
import 'package:devmob_gestionrepas/models/meal_plan_week.dart';
import 'package:devmob_gestionrepas/models/recipe.dart';
import 'package:devmob_gestionrepas/models/recipe_category.dart';
import 'package:devmob_gestionrepas/models/shopping_list.dart';
import 'package:devmob_gestionrepas/models/shopping_list_item.dart';
import 'package:devmob_gestionrepas/providers/shopping_list_provider.dart';
import 'package:devmob_gestionrepas/services/recipe/recipe_service.dart';
import 'package:devmob_gestionrepas/services/shopping/local_shopping_list_state_service.dart';
import 'package:devmob_gestionrepas/services/shopping/shopping_list_generator_service.dart';
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

  test('loadForWeek surfaces persisted completed items separately', () async {
    final provider = buildProvider();
    final week = MealPlanWeek.fromAnchor(DateTime(2026, 5, 20));
    generatorService.shoppingList = _shoppingList(
      week: week,
      items: <ShoppingListItem>[
        ShoppingListItem(
          id: 'tomato__piece',
          ingredientKey: 'tomato__piece',
          canonicalName: 'tomato',
          displayName: 'Tomatoes',
          totalQuantity: 5,
          unit: 'piece',
          status: ShoppingListItemStatus.pending,
          origin: ShoppingListItemOrigin.generated,
          isNewBatch: false,
          sourceRecipeIds: <String>['recipe-1'],
          createdAt: DateTime(2026, 5, 19),
        ),
      ],
    );
    localStateService.state = ShoppingListLocalState(
      completedItems: <ShoppingListItem>[
        ShoppingListItem(
          id: 'completed_batch',
          ingredientKey: 'tomato__piece',
          canonicalName: 'tomato',
          displayName: 'Tomatoes',
          totalQuantity: 2,
          unit: 'piece',
          status: ShoppingListItemStatus.completed,
          origin: ShoppingListItemOrigin.generated,
          isNewBatch: false,
          sourceRecipeIds: <String>['recipe-1'],
          createdAt: DateTime(2026, 5, 19),
          completedAt: DateTime(2026, 5, 19, 12),
        ),
      ],
      separatePendingItems: <ShoppingListItem>[],
    );

    await provider.loadForWeek(
      uid: 'user-1',
      week: week,
      entries: const <MealPlanEntry>[],
    );

    expect(provider.status, ShoppingListProviderStatus.ready);
    expect(provider.pendingItems.single.totalQuantity, 3);
    expect(provider.completedItems.single.totalQuantity, 2);
  });

  test(
    'completePendingItem moves a generated pending row into completed',
    () async {
      final provider = buildProvider();
      final week = MealPlanWeek.fromAnchor(DateTime(2026, 5, 20));
      generatorService.shoppingList = _shoppingList(
        week: week,
        items: <ShoppingListItem>[
          ShoppingListItem(
            id: 'milk__l',
            ingredientKey: 'milk__l',
            canonicalName: 'milk',
            displayName: 'Milk',
            totalQuantity: 1,
            unit: 'L',
            status: ShoppingListItemStatus.pending,
            origin: ShoppingListItemOrigin.generated,
            isNewBatch: false,
            sourceRecipeIds: <String>['recipe-2'],
            createdAt: DateTime(2026, 5, 19),
          ),
        ],
      );

      await provider.loadForWeek(
        uid: 'user-1',
        week: week,
        entries: const <MealPlanEntry>[],
      );
      await provider.completePendingItem('milk__l');

      expect(provider.pendingItems, isEmpty);
      expect(provider.completedItems, hasLength(1));
      expect(provider.completedItems.single.displayName, 'Milk');
      expect(localStateService.lastWrittenState.completedItems, hasLength(1));
    },
  );

  test(
    'loadForWeek creates a new pending row after prior completion',
    () async {
      final provider = buildProvider();
      final week = MealPlanWeek.fromAnchor(DateTime(2026, 5, 20));
      generatorService.shoppingList = _shoppingList(
        week: week,
        items: <ShoppingListItem>[
          ShoppingListItem(
            id: 'olive__cup',
            ingredientKey: 'olive__cup',
            canonicalName: 'olive',
            displayName: 'Black Olives',
            totalQuantity: 3,
            unit: 'cup',
            status: ShoppingListItemStatus.pending,
            origin: ShoppingListItemOrigin.generated,
            isNewBatch: false,
            sourceRecipeIds: <String>['recipe-1'],
            createdAt: DateTime(2026, 5, 19),
          ),
        ],
      );
      localStateService.state = ShoppingListLocalState(
        completedItems: <ShoppingListItem>[
          ShoppingListItem(
            id: 'completed_olive_batch',
            ingredientKey: 'olive__cup',
            canonicalName: 'olive',
            displayName: 'Black Olives',
            totalQuantity: 2,
            unit: 'cup',
            status: ShoppingListItemStatus.completed,
            origin: ShoppingListItemOrigin.generated,
            isNewBatch: false,
            sourceRecipeIds: <String>['recipe-1'],
            createdAt: DateTime(2026, 5, 18),
            completedAt: DateTime(2026, 5, 18, 14),
          ),
        ],
        separatePendingItems: <ShoppingListItem>[],
      );

      await provider.loadForWeek(
        uid: 'user-1',
        week: week,
        entries: const <MealPlanEntry>[],
      );

      expect(provider.pendingItems.single.totalQuantity, 1);
      expect(provider.pendingItems.single.isNewBatch, isTrue);
      expect(provider.completedItems.single.totalQuantity, 2);
    },
  );

  test(
    'reopenCompletedItem with merge leaves one merged pending row',
    () async {
      final provider = buildProvider();
      final week = MealPlanWeek.fromAnchor(DateTime(2026, 5, 20));
      generatorService.shoppingList = _shoppingList(
        week: week,
        items: <ShoppingListItem>[
          ShoppingListItem(
            id: 'olive__cup',
            ingredientKey: 'olive__cup',
            canonicalName: 'olive',
            displayName: 'Black Olives',
            totalQuantity: 3,
            unit: 'cup',
            status: ShoppingListItemStatus.pending,
            origin: ShoppingListItemOrigin.generated,
            isNewBatch: false,
            sourceRecipeIds: <String>['recipe-1'],
            createdAt: DateTime(2026, 5, 19),
          ),
        ],
      );
      localStateService.state = ShoppingListLocalState(
        completedItems: <ShoppingListItem>[
          ShoppingListItem(
            id: 'completed_olive_batch',
            ingredientKey: 'olive__cup',
            canonicalName: 'olive',
            displayName: 'Black Olives',
            totalQuantity: 2,
            unit: 'cup',
            status: ShoppingListItemStatus.completed,
            origin: ShoppingListItemOrigin.generated,
            isNewBatch: false,
            sourceRecipeIds: <String>['recipe-1'],
            createdAt: DateTime(2026, 5, 18),
            completedAt: DateTime(2026, 5, 18, 14),
          ),
        ],
        separatePendingItems: <ShoppingListItem>[],
      );

      await provider.loadForWeek(uid: 'user-1', week: week, entries: const []);
      await provider.reopenCompletedItem(
        itemId: 'completed_olive_batch',
        mode: CompletedItemReopenMode.mergeIntoPending,
      );

      expect(provider.completedItems, isEmpty);
      expect(provider.pendingItems, hasLength(1));
      expect(provider.pendingItems.single.totalQuantity, 3);
    },
  );

  test(
    'reopenCompletedItem with separate keeps a distinct reopened batch',
    () async {
      final provider = buildProvider();
      final week = MealPlanWeek.fromAnchor(DateTime(2026, 5, 20));
      generatorService.shoppingList = _shoppingList(
        week: week,
        items: <ShoppingListItem>[
          ShoppingListItem(
            id: 'olive__cup',
            ingredientKey: 'olive__cup',
            canonicalName: 'olive',
            displayName: 'Black Olives',
            totalQuantity: 3,
            unit: 'cup',
            status: ShoppingListItemStatus.pending,
            origin: ShoppingListItemOrigin.generated,
            isNewBatch: false,
            sourceRecipeIds: <String>['recipe-1'],
            createdAt: DateTime(2026, 5, 19),
          ),
        ],
      );
      localStateService.state = ShoppingListLocalState(
        completedItems: <ShoppingListItem>[
          ShoppingListItem(
            id: 'completed_olive_batch',
            ingredientKey: 'olive__cup',
            canonicalName: 'olive',
            displayName: 'Black Olives',
            totalQuantity: 2,
            unit: 'cup',
            status: ShoppingListItemStatus.completed,
            origin: ShoppingListItemOrigin.generated,
            isNewBatch: false,
            sourceRecipeIds: <String>['recipe-1'],
            createdAt: DateTime(2026, 5, 18),
            completedAt: DateTime(2026, 5, 18, 14),
          ),
        ],
        separatePendingItems: <ShoppingListItem>[],
      );

      await provider.loadForWeek(uid: 'user-1', week: week, entries: const []);
      await provider.reopenCompletedItem(
        itemId: 'completed_olive_batch',
        mode: CompletedItemReopenMode.reopenSeparately,
      );

      expect(provider.completedItems, isEmpty);
      expect(provider.pendingItems, hasLength(2));
      expect(
        provider.pendingItems.any(
          (item) => item.origin == ShoppingListItemOrigin.reopened,
        ),
        isTrue,
      );
    },
  );

  test('loadForWeek exposes error state when generation fails', () async {
    final provider = buildProvider();
    final week = MealPlanWeek.fromAnchor(DateTime(2026, 5, 20));
    generatorService.throwOnGenerate = true;

    await provider.loadForWeek(
      uid: 'user-1',
      week: week,
      entries: const <MealPlanEntry>[],
    );

    expect(provider.status, ShoppingListProviderStatus.error);
    expect(provider.items, isEmpty);
    expect(provider.errorMessage, 'Unable to generate the shopping list.');
  });
}

ShoppingList _shoppingList({
  required MealPlanWeek week,
  required List<ShoppingListItem> items,
}) {
  return ShoppingList(
    ownerUid: 'user-1',
    weekStartDate: week.startDate,
    generatedAt: DateTime(2026, 5, 19),
    items: items,
  );
}

class _FakeShoppingListGeneratorService extends ShoppingListGeneratorService {
  _FakeShoppingListGeneratorService()
    : super(recipeService: _NoopRecipeService());

  late ShoppingList shoppingList;
  bool throwOnGenerate = false;

  @override
  Future<ShoppingList> generateForWeek({
    required String uid,
    required DateTime weekStartDate,
    required List<MealPlanEntry> entries,
  }) async {
    if (throwOnGenerate) {
      throw Exception('generation failed');
    }
    return shoppingList;
  }
}

class _FakeLocalShoppingListStateService
    implements LocalShoppingListStateService {
  ShoppingListLocalState state = ShoppingListLocalState.empty;
  ShoppingListLocalState lastWrittenState = ShoppingListLocalState.empty;

  @override
  Future<void> clearState({
    required String uid,
    required DateTime weekStartDate,
  }) async {
    state = ShoppingListLocalState.empty;
  }

  @override
  Future<ShoppingListLocalState> readState({
    required String uid,
    required DateTime weekStartDate,
  }) async {
    return state;
  }

  @override
  Future<void> writeState({
    required String uid,
    required DateTime weekStartDate,
    required ShoppingListLocalState state,
  }) async {
    lastWrittenState = state;
    this.state = state;
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
