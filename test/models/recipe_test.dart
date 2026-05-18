import 'package:devmob_gestionrepas/models/ingredient.dart';
import 'package:devmob_gestionrepas/models/recipe.dart';
import 'package:devmob_gestionrepas/models/recipe_category.dart';
import 'package:devmob_gestionrepas/models/recipe_step.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Recipe.toMap and Recipe.fromMap preserve image metadata', () {
    final now = DateTime.now();
    final recipe = Recipe(
      id: 'recipe-1',
      ownerUid: 'user-1',
      title: 'Pasta',
      description: 'Simple pasta',
      category: RecipeCategory.dinner,
      isFavorite: true,
      ingredients: <Ingredient>[
        Ingredient(
          displayName: 'Tomatoes',
          canonicalName: 'tomato',
          quantity: 2,
          unit: 'piece',
        ),
      ],
      steps: <RecipeStep>[RecipeStep(order: 1, text: 'Cook')],
      imageUrl: 'https://example.com/pasta.webp',
      imageStoragePath: 'users/user-1/recipes/recipe-1/cover.webp',
      imageMimeType: 'image/webp',
      imageSizeBytes: 2048,
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 1, 2),
    );

    final map = recipe.toMap();
    final restored = Recipe.fromMap(
      id: 'recipe-1',
      ownerUid: 'user-1',
      data: <String, dynamic>{
        ...map,
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      },
    );

    expect(restored.imageUrl, recipe.imageUrl);
    expect(restored.imageStoragePath, recipe.imageStoragePath);
    expect(restored.imageMimeType, recipe.imageMimeType);
    expect(restored.imageSizeBytes, recipe.imageSizeBytes);
  });
}
