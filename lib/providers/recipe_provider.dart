import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/ingredient.dart';
import '../models/recipe.dart';
import '../models/recipe_category.dart';
import '../models/recipe_failure.dart';
import '../models/recipe_step.dart';
import '../services/recipe/ingredient_normalizer.dart';
import '../services/recipe/recipe_exception.dart';
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
  String? _selectedRecipeId;
  String? _errorMessage;
  RecipeFailure? _failure;

  List<Recipe> get recipes => _recipes;
  RecipeCategory? get activeCategory => _activeCategory;
  bool get favoritesOnly => _favoritesOnly;
  RecipeProviderStatus get status => _status;
  String? get selectedRecipeId => _selectedRecipeId;
  Recipe? get selectedRecipe =>
      _selectedRecipeId == null ? null : _findRecipeById(_selectedRecipeId!);
  String? get errorMessage => _errorMessage;
  RecipeFailure? get failure => _failure;
  bool get isLoading =>
      _status == RecipeProviderStatus.loading ||
      _status == RecipeProviderStatus.mutating;
  String? get uid => _uid;
  Recipe? recipeById(String recipeId) => _findRecipeById(recipeId);

  Future<void> startWatching({required String uid}) async {
    _uid = uid;
    _status = RecipeProviderStatus.loading;
    _errorMessage = null;
    _failure = null;
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
            _failure = null;
            _safeNotify();
          },
          onError: (Object error, StackTrace _) {
            _applyServiceError(error);
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
    _failure = null;
    _safeNotify();

    try {
      final recipes = await _recipeService.fetchRecipes(
        uid: currentUid,
        category: _activeCategory,
        favoritesOnly: _favoritesOnly,
      );
      _recipes = recipes;
      _status = RecipeProviderStatus.ready;
      _failure = null;
      _safeNotify();
    } catch (error) {
      _applyServiceError(error);
    }
  }

  Future<Recipe?> loadRecipeById(
    String recipeId, {
    bool forceRefresh = false,
  }) async {
    final normalizedId = recipeId.trim();
    if (normalizedId.isEmpty) {
      _applyMessageFailure(
        const RecipeFailure(
          code: RecipeFailureCode.invalidData,
          message: 'Recipe id is required.',
        ),
      );
      return null;
    }

    _selectedRecipeId = normalizedId;
    final currentUid = _uid;
    if (currentUid == null) {
      _applyMessageFailure(
        const RecipeFailure(
          code: RecipeFailureCode.unauthenticated,
          message: 'Authenticated user is required.',
        ),
      );
      return null;
    }

    final cachedRecipe = _findRecipeById(normalizedId);
    if (!forceRefresh && cachedRecipe != null) {
      _status = RecipeProviderStatus.ready;
      _errorMessage = null;
      _failure = null;
      _safeNotify();
      return cachedRecipe;
    }

    _status = RecipeProviderStatus.loading;
    _errorMessage = null;
    _failure = null;
    _safeNotify();

    try {
      final recipe = await _recipeService.fetchRecipeById(
        uid: currentUid,
        recipeId: normalizedId,
      );
      if (recipe == null) {
        _applyMessageFailure(
          const RecipeFailure(
            code: RecipeFailureCode.notFound,
            message: 'Recipe not found.',
          ),
        );
        return null;
      }

      _upsertRecipe(recipe);
      _status = RecipeProviderStatus.ready;
      _errorMessage = null;
      _failure = null;
      _safeNotify();
      return recipe;
    } catch (error) {
      _applyServiceError(error);
      return null;
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
    _selectedRecipeId = null;
    _errorMessage = null;
    _failure = null;
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
      _failure = const RecipeFailure(
        code: RecipeFailureCode.unauthenticated,
        message: 'Authenticated user is required.',
      );
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
      imageUrl: imageUrl,
      imageStoragePath: imageStoragePath,
    );
    if (errors.isNotEmpty) {
      _status = RecipeProviderStatus.error;
      _errorMessage = errors.first;
      _failure = RecipeFailure(
        code: RecipeFailureCode.invalidData,
        message: errors.first,
      );
      _safeNotify();
      return errors;
    }

    _status = RecipeProviderStatus.mutating;
    _errorMessage = null;
    _failure = null;
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
      final createdId = await _recipeService.createRecipe(
        uid: currentUid,
        recipe: payload,
      );
      _selectedRecipeId = createdId;
      _status = RecipeProviderStatus.ready;
      _failure = null;
      _safeNotify();
      return const <String>[];
    } catch (error) {
      _applyServiceError(error);
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
      _failure = const RecipeFailure(
        code: RecipeFailureCode.unauthenticated,
        message: 'Authenticated user is required.',
      );
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
      imageUrl: imageUrl,
      imageStoragePath: imageStoragePath,
    );
    if (errors.isNotEmpty) {
      _status = RecipeProviderStatus.error;
      _errorMessage = errors.first;
      _failure = RecipeFailure(
        code: RecipeFailureCode.invalidData,
        message: errors.first,
      );
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
      imageUrl: _normalizeOptionalText(imageUrl),
      imageStoragePath: _normalizeOptionalText(imageStoragePath),
    );

    _status = RecipeProviderStatus.mutating;
    _errorMessage = null;
    _failure = null;
    _safeNotify();

    try {
      await _recipeService.updateRecipe(uid: currentUid, recipe: payload);
      _selectedRecipeId = payload.id;
      _upsertRecipe(payload);
      _status = RecipeProviderStatus.ready;
      _failure = null;
      _safeNotify();
      return const <String>[];
    } catch (error) {
      _applyServiceError(error);
      return <String>[_errorMessage!];
    }
  }

  Future<bool> deleteRecipe(String recipeId) async {
    final currentUid = _uid;
    if (currentUid == null) {
      _applyMessageFailure(
        const RecipeFailure(
          code: RecipeFailureCode.unauthenticated,
          message: 'Authenticated user is required.',
        ),
      );
      return false;
    }

    _status = RecipeProviderStatus.mutating;
    _errorMessage = null;
    _failure = null;
    _safeNotify();

    try {
      await _recipeService.deleteRecipe(uid: currentUid, recipeId: recipeId);
      _recipes = _recipes.where((recipe) => recipe.id != recipeId).toList();
      if (_selectedRecipeId == recipeId) {
        _selectedRecipeId = null;
      }
      _status = RecipeProviderStatus.ready;
      _failure = null;
      _safeNotify();
      return true;
    } catch (error) {
      _applyServiceError(error);
      return false;
    }
  }

  Future<bool> toggleFavorite({
    required String recipeId,
    required bool isFavorite,
  }) async {
    final currentUid = _uid;
    if (currentUid == null) {
      _applyMessageFailure(
        const RecipeFailure(
          code: RecipeFailureCode.unauthenticated,
          message: 'Authenticated user is required.',
        ),
      );
      return false;
    }

    _status = RecipeProviderStatus.mutating;
    _errorMessage = null;
    _failure = null;
    _safeNotify();

    try {
      await _recipeService.setFavorite(
        uid: currentUid,
        recipeId: recipeId,
        isFavorite: isFavorite,
      );
      final recipe = _findRecipeById(recipeId);
      if (recipe != null) {
        _upsertRecipe(
          recipe.copyWith(isFavorite: isFavorite, updatedAt: DateTime.now()),
        );
      }
      _status = RecipeProviderStatus.ready;
      _failure = null;
      _safeNotify();
      return true;
    } catch (error) {
      _applyServiceError(error);
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

  void _upsertRecipe(Recipe recipe) {
    final updatedRecipes = List<Recipe>.from(_recipes);
    final index = updatedRecipes.indexWhere((item) => item.id == recipe.id);
    if (index >= 0) {
      updatedRecipes[index] = recipe;
    } else {
      updatedRecipes.add(recipe);
      updatedRecipes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    }
    _recipes = updatedRecipes;
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

  void _applyServiceError(Object error) {
    if (error is RecipeException) {
      _applyMessageFailure(error.failure);
      return;
    }

    _applyMessageFailure(
      RecipeFailure(code: RecipeFailureCode.unknown, message: error.toString()),
    );
  }

  void _applyMessageFailure(RecipeFailure failure) {
    _failure = failure;
    _status = RecipeProviderStatus.error;
    _errorMessage = failure.message;
    _safeNotify();
  }

  @override
  void dispose() {
    _disposed = true;
    _recipesSubscription?.cancel();
    super.dispose();
  }
}
