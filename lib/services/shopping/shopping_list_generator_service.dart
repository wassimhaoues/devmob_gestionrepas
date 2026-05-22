import '../../models/ingredient_unit.dart';
import '../../models/meal_plan_entry.dart';
import '../../models/recipe.dart';
import '../../models/shopping_list.dart';
import '../../models/shopping_list_item.dart';
import '../recipe/recipe_service.dart';

class ShoppingListGeneratorService {
  ShoppingListGeneratorService({required RecipeService recipeService})
    : _recipeService = recipeService;

  final RecipeService _recipeService;

  Future<ShoppingList> generateForWeek({
    required String uid,
    required DateTime weekStartDate,
    required List<MealPlanEntry> entries,
  }) async {
    final recipeIds =
        entries
            .map((entry) => entry.recipeId.trim())
            .where((recipeId) => recipeId.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    final recipes = await Future.wait<Recipe?>(
      recipeIds.map(
        (recipeId) =>
            _recipeService.fetchRecipeById(uid: uid, recipeId: recipeId),
      ),
    );
    final recipesById = <String, Recipe>{
      for (final recipe in recipes.whereType<Recipe>()) recipe.id: recipe,
    };

    final itemsByKey = <String, _ShoppingAggregation>{};
    for (final entry in entries) {
      final recipe = recipesById[entry.recipeId.trim()];
      if (recipe == null) {
        continue;
      }

      for (final ingredient in recipe.ingredients) {
        final canonicalName = ingredient.canonicalName.trim();
        if (canonicalName.isEmpty) {
          continue;
        }

        final baseUnit = _baseUnit(ingredient.unit);
        final baseQuantity = _toBaseQuantity(ingredient.quantity, ingredient.unit);

        final itemId = ShoppingListItem.buildId(
          canonicalName: canonicalName,
          unit: baseUnit,
        );
        final current = itemsByKey[itemId];
        if (current == null) {
          itemsByKey[itemId] = _ShoppingAggregation(
            id: itemId,
            canonicalName: canonicalName,
            displayName: ingredient.displayName.trim().isEmpty
                ? canonicalName
                : ingredient.displayName.trim(),
            totalQuantity: baseQuantity,
            unit: baseUnit,
            sourceRecipeIds: <String>[recipe.id],
          );
          continue;
        }

        current.totalQuantity += baseQuantity;
        final recipeId = recipe.id.trim();
        if (recipeId.isNotEmpty &&
            !current.sourceRecipeIds.contains(recipeId)) {
          current.sourceRecipeIds.add(recipeId);
        }
      }
    }

    final items =
        itemsByKey.values
            .map(
              (item) => ShoppingListItem(
                id: item.id,
                ingredientKey: item.id,
                canonicalName: item.canonicalName,
                displayName: item.displayName,
                totalQuantity: item.totalQuantity,
                unit: item.unit,
                status: ShoppingListItemStatus.pending,
                origin: ShoppingListItemOrigin.generated,
                isNewBatch: false,
                sourceRecipeIds: item.sourceRecipeIds,
                createdAt: DateTime.now(),
              ),
            )
            .toList()
          ..sort(
            (a, b) => a.displayName.toLowerCase().compareTo(
              b.displayName.toLowerCase(),
            ),
          );

    return ShoppingList(
      ownerUid: uid,
      weekStartDate: DateTime(
        weekStartDate.year,
        weekStartDate.month,
        weekStartDate.day,
      ),
      generatedAt: DateTime.now(),
      items: items,
    );
  }

  static String _baseUnit(IngredientUnit unit) {
    switch (unit) {
      case IngredientUnit.g:
      case IngredientUnit.kg:
      case IngredientUnit.mg:
        return 'g';
      case IngredientUnit.ml:
      case IngredientUnit.l:
      case IngredientUnit.cl:
      case IngredientUnit.tsp:
      case IngredientUnit.tbsp:
      case IngredientUnit.cup:
        return 'ml';
      case IngredientUnit.piece:
      case IngredientUnit.pinch:
      case IngredientUnit.bunch:
      case IngredientUnit.slice:
      case IngredientUnit.can:
      case IngredientUnit.toTaste:
        return unit.value;
    }
  }

  static double _toBaseQuantity(double quantity, IngredientUnit unit) {
    switch (unit) {
      case IngredientUnit.kg:
        return quantity * 1000;
      case IngredientUnit.mg:
        return quantity / 1000;
      case IngredientUnit.l:
        return quantity * 1000;
      case IngredientUnit.cl:
        return quantity * 10;
      case IngredientUnit.tsp:
        return quantity * 4.92892;
      case IngredientUnit.tbsp:
        return quantity * 14.7868;
      case IngredientUnit.cup:
        return quantity * 240;
      default:
        return quantity;
    }
  }
}

class _ShoppingAggregation {
  _ShoppingAggregation({
    required this.id,
    required this.canonicalName,
    required this.displayName,
    required this.totalQuantity,
    required this.unit,
    required this.sourceRecipeIds,
  });

  final String id;
  final String canonicalName;
  final String displayName;
  double totalQuantity;
  final String unit;
  final List<String> sourceRecipeIds;
}
