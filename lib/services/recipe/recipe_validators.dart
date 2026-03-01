import '../../models/ingredient.dart';
import '../../models/recipe_category.dart';
import '../../models/recipe_step.dart';

class RecipeValidators {
  static String? validateTitle(String? value) {
    final normalized = (value ?? '').trim();
    if (normalized.isEmpty) {
      return 'Title is required.';
    }
    if (normalized.length > 120) {
      return 'Title must be 120 characters or less.';
    }
    return null;
  }

  static String? validateDescription(String? value) {
    final normalized = (value ?? '').trim();
    if (normalized.length > 1500) {
      return 'Description must be 1500 characters or less.';
    }
    return null;
  }

  static String? validateCategory(RecipeCategory? category) {
    if (category == null) {
      return 'Category is required.';
    }
    return null;
  }

  static String? validateIngredientDisplayName(String? value) {
    final normalized = (value ?? '').trim();
    if (normalized.isEmpty) {
      return 'Ingredient name is required.';
    }
    return null;
  }

  static String? validateIngredientCanonicalName(String? value) {
    final normalized = (value ?? '').trim();
    if (normalized.isEmpty) {
      return 'Ingredient canonical name is required.';
    }
    return null;
  }

  static String? validateIngredientQuantity(double? value) {
    if (value == null) {
      return 'Ingredient quantity is required.';
    }
    if (value <= 0) {
      return 'Ingredient quantity must be greater than zero.';
    }
    return null;
  }

  static String? validateIngredientUnit(String? value) {
    final normalized = (value ?? '').trim();
    if (normalized.isEmpty) {
      return 'Ingredient unit is required.';
    }
    return null;
  }

  static String? validateStepText(String? value) {
    final normalized = (value ?? '').trim();
    if (normalized.isEmpty) {
      return 'Step text is required.';
    }
    return null;
  }

  static List<String> validateIngredients(List<Ingredient> ingredients) {
    if (ingredients.isEmpty) {
      return <String>['At least one ingredient is required.'];
    }

    final errors = <String>[];
    final uniqueKeys = <String>{};

    for (var index = 0; index < ingredients.length; index++) {
      final ingredient = ingredients[index];
      final row = index + 1;

      final nameError = validateIngredientDisplayName(ingredient.displayName);
      if (nameError != null) {
        errors.add('Ingredient #$row: $nameError');
      }

      final canonicalError = validateIngredientCanonicalName(
        ingredient.canonicalName,
      );
      if (canonicalError != null) {
        errors.add('Ingredient #$row: $canonicalError');
      }

      final quantityError = validateIngredientQuantity(ingredient.quantity);
      if (quantityError != null) {
        errors.add('Ingredient #$row: $quantityError');
      }

      final unitError = validateIngredientUnit(ingredient.unit);
      if (unitError != null) {
        errors.add('Ingredient #$row: $unitError');
      }

      final canonicalKey =
          '${ingredient.canonicalName.trim().toLowerCase()}::${ingredient.unit.trim().toLowerCase()}';
      if (canonicalKey != '::' && !uniqueKeys.add(canonicalKey)) {
        errors.add(
          'Ingredient #$row duplicates a previous ingredient with the same canonical name and unit.',
        );
      }
    }

    return errors;
  }

  static List<String> validateSteps(List<RecipeStep> steps) {
    if (steps.isEmpty) {
      return <String>['At least one preparation step is required.'];
    }

    final errors = <String>[];
    for (var index = 0; index < steps.length; index++) {
      final step = steps[index];
      final row = index + 1;

      final textError = validateStepText(step.text);
      if (textError != null) {
        errors.add('Step #$row: $textError');
      }
    }
    return errors;
  }

  static List<String> validateRecipeInput({
    required String title,
    required RecipeCategory? category,
    required List<Ingredient> ingredients,
    required List<RecipeStep> steps,
    String? description,
  }) {
    final errors = <String>[];

    final titleError = validateTitle(title);
    if (titleError != null) {
      errors.add(titleError);
    }

    final descriptionError = validateDescription(description);
    if (descriptionError != null) {
      errors.add(descriptionError);
    }

    final categoryError = validateCategory(category);
    if (categoryError != null) {
      errors.add(categoryError);
    }

    errors.addAll(validateIngredients(ingredients));
    errors.addAll(validateSteps(steps));
    return errors;
  }
}
