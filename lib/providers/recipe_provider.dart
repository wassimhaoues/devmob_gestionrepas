import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/ingredient.dart';
import '../models/recipe.dart';
import '../models/recipe_category.dart';
import '../models/recipe_step.dart';
import '../services/recipe/ingredient_normalizer.dart';
import '../services/recipe/recipe_service.dart';
import '../services/recipe/recipe_validators.dart';

enum RecipeProviderStatus { initial, loading, ready, mutating, error }

class RecipeProvider extends ChangeNotifier {
  RecipeProvider({required RecipeService recipeService})
    : _recipeService = recipeService;

  final RecipeService _recipeService;

  StreamSubscription<List<Recipe>>? _recipesSubscription;
  bool _disposed = false;

  String? _uid;
  List<Recipe> _recipes = const <Recipe>[];
  RecipeCategory? _activeCategory;
  bool _favoritesOnly = false;
  RecipeProviderStatus _status = RecipeProviderStatus.initial;
  String? _errorMessage;

  List<Recipe> get recipes => _recipes;
  RecipeCategory? get activeCategory => _activeCategory;
  bool get favoritesOnly => _favoritesOnly;
  RecipeProviderStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isLoading =>
      _status == RecipeProviderStatus.loading ||
      _status == RecipeProviderStatus.mutating;
  String? get uid => _uid;

  Future<void> startWatching({required String uid}) async {
    _uid = uid;
    _status = RecipeProviderStatus.loading;
    _errorMessage = null;
    _safeNotify();

    await _recipesSubscription?.cancel();
    _recipesSubscription = _recipeService
        .watchRecipes(
          uid: uid,
          category: _activeCategory,
          favoritesOnly: _favoritesOnly,
        )
        .listen(
          (recipes) {
            _recipes = recipes;
            _status = RecipeProviderStatus.ready;
            _errorMessage = null;
            _safeNotify();
          },
          onError: (Object error, StackTrace _) {
            _status = RecipeProviderStatus.error;
            _errorMessage = error.toString();
            _safeNotify();
          },
        );
  }

  Future<void> refresh() async {
    final currentUid = _uid;
    if (currentUid == null) {
      return;
    }

    _status = RecipeProviderStatus.loading;
    _errorMessage = null;
    _safeNotify();

    try {
      final recipes = await _recipeService.fetchRecipes(
        uid: currentUid,
        category: _activeCategory,
        favoritesOnly: _favoritesOnly,
      );
      _recipes = recipes;
      _status = RecipeProviderStatus.ready;
      _safeNotify();
    } catch (error) {
      _status = RecipeProviderStatus.error;
      _errorMessage = error.toString();
      _safeNotify();
    }
  }

  Future<void> setCategoryFilter(RecipeCategory? category) async {
    _activeCategory = category;
    final currentUid = _uid;
    if (currentUid == null) {
      _safeNotify();
      return;
    }
    await startWatching(uid: currentUid);
  }

  Future<void> setFavoritesOnly(bool favoritesOnly) async {
    _favoritesOnly = favoritesOnly;
    final currentUid = _uid;
    if (currentUid == null) {
      _safeNotify();
      return;
    }
    await startWatching(uid: currentUid);
  }

  Future<void> stopWatching() async {
    await _recipesSubscription?.cancel();
    _recipesSubscription = null;
    _uid = null;
    _recipes = const <Recipe>[];
    _activeCategory = null;
    _favoritesOnly = false;
    _status = RecipeProviderStatus.initial;
    _errorMessage = null;
    _safeNotify();
  }

  Future<List<String>> createRecipe({
    required String title,
    required String? description,
    required RecipeCategory? category,
    required List<Ingredient> ingredients,
    required List<RecipeStep> steps,
    bool isFavorite = false,
    String? imageUrl,
    String? imageStoragePath,
  }) async {
    final currentUid = _uid;
    if (currentUid == null) {
      const errors = <String>['Authenticated user is required.'];
      _status = RecipeProviderStatus.error;
      _errorMessage = errors.first;
      _safeNotify();
      return errors;
    }

    final normalizedIngredients = _normalizeIngredients(ingredients);
    final normalizedSteps = _normalizeSteps(steps);

    final errors = RecipeValidators.validateRecipeInput(
      title: title,
      description: description,
      category: category,
      ingredients: normalizedIngredients,
      steps: normalizedSteps,
    );
    if (errors.isNotEmpty) {
      _status = RecipeProviderStatus.error;
      _errorMessage = errors.first;
      _safeNotify();
      return errors;
    }

    _status = RecipeProviderStatus.mutating;
    _errorMessage = null;
    _safeNotify();

    final now = DateTime.now();
    final payload = Recipe(
      id: '',
      ownerUid: currentUid,
      title: title.trim(),
      description: (description ?? '').trim(),
      category: category!,
      isFavorite: isFavorite,
      ingredients: normalizedIngredients,
      steps: normalizedSteps,
      createdAt: now,
      updatedAt: now,
      imageUrl: _normalizeOptionalText(imageUrl),
      imageStoragePath: _normalizeOptionalText(imageStoragePath),
    );

    try {
      await _recipeService.createRecipe(uid: currentUid, recipe: payload);
      _status = RecipeProviderStatus.ready;
      _safeNotify();
      return const <String>[];
    } catch (error) {
      _status = RecipeProviderStatus.error;
      _errorMessage = error.toString();
      _safeNotify();
      return <String>[_errorMessage!];
    }
  }

  Future<List<String>> updateRecipe({
    required String recipeId,
    required String title,
    required String? description,
    required RecipeCategory? category,
    required List<Ingredient> ingredients,
    required List<RecipeStep> steps,
    bool? isFavorite,
    String? imageUrl,
    String? imageStoragePath,
  }) async {
    final currentUid = _uid;
    if (currentUid == null) {
      const errors = <String>['Authenticated user is required.'];
      _status = RecipeProviderStatus.error;
      _errorMessage = errors.first;
      _safeNotify();
      return errors;
    }

    final normalizedIngredients = _normalizeIngredients(ingredients);
    final normalizedSteps = _normalizeSteps(steps);
    final errors = RecipeValidators.validateRecipeInput(
      title: title,
      description: description,
      category: category,
      ingredients: normalizedIngredients,
      steps: normalizedSteps,
    );
    if (errors.isNotEmpty) {
      _status = RecipeProviderStatus.error;
      _errorMessage = errors.first;
      _safeNotify();
      return errors;
    }

    final existingRecipe = _findRecipeById(recipeId);
    final now = DateTime.now();
    final payload = Recipe(
      id: recipeId.trim(),
      ownerUid: currentUid,
      title: title.trim(),
      description: (description ?? '').trim(),
      category: category!,
      isFavorite: isFavorite ?? existingRecipe?.isFavorite ?? false,
      ingredients: normalizedIngredients,
      steps: normalizedSteps,
      createdAt: existingRecipe?.createdAt ?? now,
      updatedAt: now,
      imageUrl: _normalizeOptionalText(imageUrl) ?? existingRecipe?.imageUrl,
      imageStoragePath:
          _normalizeOptionalText(imageStoragePath) ??
          existingRecipe?.imageStoragePath,
    );

    _status = RecipeProviderStatus.mutating;
    _errorMessage = null;
    _safeNotify();

    try {
      await _recipeService.updateRecipe(uid: currentUid, recipe: payload);
      _status = RecipeProviderStatus.ready;
      _safeNotify();
      return const <String>[];
    } catch (error) {
      _status = RecipeProviderStatus.error;
      _errorMessage = error.toString();
      _safeNotify();
      return <String>[_errorMessage!];
    }
  }

  Future<bool> deleteRecipe(String recipeId) async {
    final currentUid = _uid;
    if (currentUid == null) {
      _status = RecipeProviderStatus.error;
      _errorMessage = 'Authenticated user is required.';
      _safeNotify();
      return false;
    }

    _status = RecipeProviderStatus.mutating;
    _errorMessage = null;
    _safeNotify();

    try {
      await _recipeService.deleteRecipe(uid: currentUid, recipeId: recipeId);
      _status = RecipeProviderStatus.ready;
      _safeNotify();
      return true;
    } catch (error) {
      _status = RecipeProviderStatus.error;
      _errorMessage = error.toString();
      _safeNotify();
      return false;
    }
  }

  Future<bool> toggleFavorite({
    required String recipeId,
    required bool isFavorite,
  }) async {
    final currentUid = _uid;
    if (currentUid == null) {
      _status = RecipeProviderStatus.error;
      _errorMessage = 'Authenticated user is required.';
      _safeNotify();
      return false;
    }

    _status = RecipeProviderStatus.mutating;
    _errorMessage = null;
    _safeNotify();

    try {
      await _recipeService.setFavorite(
        uid: currentUid,
        recipeId: recipeId,
        isFavorite: isFavorite,
      );
      _status = RecipeProviderStatus.ready;
      _safeNotify();
      return true;
    } catch (error) {
      _status = RecipeProviderStatus.error;
      _errorMessage = error.toString();
      _safeNotify();
      return false;
    }
  }

  List<Ingredient> _normalizeIngredients(List<Ingredient> ingredients) {
    return ingredients.map((ingredient) {
      final normalizedDisplayName = IngredientNormalizer.normalizeDisplayName(
        ingredient.displayName,
      );
      final canonicalSource = normalizedDisplayName.isNotEmpty
          ? normalizedDisplayName
          : ingredient.canonicalName;

      return ingredient.copyWith(
        displayName: normalizedDisplayName,
        canonicalName: IngredientNormalizer.normalizeCanonicalName(
          canonicalSource,
        ),
        unit: IngredientNormalizer.normalizeDisplayName(ingredient.unit),
      );
    }).toList();
  }

  List<RecipeStep> _normalizeSteps(List<RecipeStep> steps) {
    return steps.asMap().entries.map((entry) {
      final order = entry.key + 1;
      final step = entry.value;
      final normalizedText = step.text.trim().replaceAll(RegExp(r'\s+'), ' ');
      return step.copyWith(order: order, text: normalizedText);
    }).toList();
  }

  Recipe? _findRecipeById(String recipeId) {
    for (final recipe in _recipes) {
      if (recipe.id == recipeId) {
        return recipe;
      }
    }
    return null;
  }

  String? _normalizeOptionalText(String? value) {
    final normalized = (value ?? '').trim();
    if (normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  void _safeNotify() {
    if (_disposed) {
      return;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _recipesSubscription?.cancel();
    super.dispose();
  }
}
