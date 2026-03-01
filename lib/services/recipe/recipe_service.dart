import '../../models/recipe.dart';
import '../../models/recipe_category.dart';

abstract interface class RecipeService {
  Stream<List<Recipe>> watchRecipes({
    required String uid,
    RecipeCategory? category,
    bool favoritesOnly = false,
  });

  Future<List<Recipe>> fetchRecipes({
    required String uid,
    RecipeCategory? category,
    bool favoritesOnly = false,
  });

  Future<Recipe?> fetchRecipeById({
    required String uid,
    required String recipeId,
  });

  Future<String> createRecipe({required String uid, required Recipe recipe});

  Future<void> updateRecipe({required String uid, required Recipe recipe});

  Future<void> deleteRecipe({required String uid, required String recipeId});

  Future<void> setFavorite({
    required String uid,
    required String recipeId,
    required bool isFavorite,
  });
}
