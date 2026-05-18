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

    final itemsByKey = <String, _ShoppingAggregation>{};
    for (final recipe in recipes.whereType<Recipe>()) {
      for (final ingredient in recipe.ingredients) {
        final canonicalName = ingredient.canonicalName.trim();
        final unit = ingredient.unit.trim();
        if (canonicalName.isEmpty || unit.isEmpty) {
          continue;
        }

        final itemId = ShoppingListItem.buildId(
          canonicalName: canonicalName,
          unit: unit,
        );
        final current = itemsByKey[itemId];
        if (current == null) {
          itemsByKey[itemId] = _ShoppingAggregation(
            id: itemId,
            canonicalName: canonicalName,
            displayName: ingredient.displayName.trim().isEmpty
                ? canonicalName
                : ingredient.displayName.trim(),
            totalQuantity: ingredient.quantity,
            unit: unit,
            sourceRecipeIds: <String>[recipe.id],
          );
          continue;
        }

        current.totalQuantity += ingredient.quantity;
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
                canonicalName: item.canonicalName,
                displayName: item.displayName,
                totalQuantity: item.totalQuantity,
                unit: item.unit,
                isChecked: false,
                sourceRecipeIds: item.sourceRecipeIds,
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
