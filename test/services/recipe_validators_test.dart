import 'package:devmob_gestionrepas/models/ingredient.dart';
import 'package:devmob_gestionrepas/models/recipe_category.dart';
import 'package:devmob_gestionrepas/models/recipe_step.dart';
import 'package:devmob_gestionrepas/services/recipe/recipe_validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RecipeValidators.validateRecipeInput', () {
    test('returns no errors for valid payload', () {
      final errors = RecipeValidators.validateRecipeInput(
        title: 'Tomato Pasta',
        description: 'Simple pasta recipe.',
        category: RecipeCategory.dinner,
        ingredients: <Ingredient>[
          const Ingredient(
            displayName: 'Tomatoes',
            canonicalName: 'tomato',
            quantity: 3,
            unit: 'piece',
          ),
        ],
        steps: const <RecipeStep>[RecipeStep(order: 1, text: 'Cut tomatoes.')],
      );

      expect(errors, isEmpty);
    });

    test('returns error when title is missing', () {
      final errors = RecipeValidators.validateRecipeInput(
        title: '   ',
        description: null,
        category: RecipeCategory.lunch,
        ingredients: const <Ingredient>[
          Ingredient(
            displayName: 'Rice',
            canonicalName: 'rice',
            quantity: 1,
            unit: 'cup',
          ),
        ],
        steps: const <RecipeStep>[RecipeStep(order: 1, text: 'Boil water.')],
      );

      expect(errors, contains('Title is required.'));
    });

    test('returns error when category is missing', () {
      final errors = RecipeValidators.validateRecipeInput(
        title: 'Rice Bowl',
        description: null,
        category: null,
        ingredients: const <Ingredient>[
          Ingredient(
            displayName: 'Rice',
            canonicalName: 'rice',
            quantity: 1,
            unit: 'cup',
          ),
        ],
        steps: const <RecipeStep>[RecipeStep(order: 1, text: 'Cook rice.')],
      );

      expect(errors, contains('Category is required.'));
    });

    test('returns error when ingredients list is empty', () {
      final errors = RecipeValidators.validateRecipeInput(
        title: 'Omelette',
        description: null,
        category: RecipeCategory.breakfast,
        ingredients: const <Ingredient>[],
        steps: const <RecipeStep>[RecipeStep(order: 1, text: 'Beat eggs.')],
      );

      expect(errors, contains('At least one ingredient is required.'));
    });

    test(
      'returns duplicate ingredient error for same canonical name and unit',
      () {
        final errors = RecipeValidators.validateRecipeInput(
          title: 'Fruit Salad',
          description: null,
          category: RecipeCategory.dessert,
          ingredients: const <Ingredient>[
            Ingredient(
              displayName: 'Apples',
              canonicalName: 'apple',
              quantity: 1,
              unit: 'piece',
            ),
            Ingredient(
              displayName: 'Apple',
              canonicalName: 'apple',
              quantity: 2,
              unit: 'piece',
            ),
          ],
          steps: const <RecipeStep>[RecipeStep(order: 1, text: 'Cut fruits.')],
        );

        expect(
          errors.any(
            (error) => error.contains('duplicates a previous ingredient'),
          ),
          isTrue,
        );
      },
    );

    test('returns error when steps list is empty', () {
      final errors = RecipeValidators.validateRecipeInput(
        title: 'Salad',
        description: null,
        category: RecipeCategory.lunch,
        ingredients: const <Ingredient>[
          Ingredient(
            displayName: 'Lettuce',
            canonicalName: 'lettuce',
            quantity: 1,
            unit: 'head',
          ),
        ],
        steps: const <RecipeStep>[],
      );

      expect(errors, contains('At least one preparation step is required.'));
    });
  });
}
