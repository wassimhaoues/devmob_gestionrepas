import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/ingredient.dart';
import '../models/processed_recipe_image.dart';
import '../models/recipe.dart';
import '../models/recipe_category.dart';
import '../models/recipe_failure.dart';
import '../models/recipe_image_selection.dart';
import '../models/recipe_step.dart';
import '../services/recipe/ingredient_normalizer.dart';
import '../services/mealplan/meal_plan_service.dart';
import '../services/recipe/recipe_exception.dart';
import '../services/recipe/recipe_image_processing_exception.dart';
import '../services/recipe/recipe_image_processor.dart';
import '../services/recipe/recipe_image_storage_service.dart';
import '../services/recipe/recipe_service.dart';
import '../services/recipe/recipe_validators.dart';

enum RecipeProviderStatus { initial, loading, ready, mutating, error }

class RecipeProvider extends ChangeNotifier {
  RecipeProvider({
    required RecipeService recipeService,
    required MealPlanService mealPlanService,
    required RecipeImageStorageService recipeImageStorageService,
    required RecipeImageProcessor recipeImageProcessor,
  }) : _recipeService = recipeService,
       _mealPlanService = mealPlanService,
       _recipeImageStorageService = recipeImageStorageService,
       _recipeImageProcessor = recipeImageProcessor;

  final RecipeService _recipeService;
  final MealPlanService _mealPlanService;
  final RecipeImageStorageService _recipeImageStorageService;
  final RecipeImageProcessor _recipeImageProcessor;

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
    RecipeImageSelection? imageSelection,
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

    ProcessedRecipeImage? processedImage;
    try {
      processedImage = await _processImageSelection(imageSelection);
    } on RecipeImageProcessingException catch (error) {
      _applyMessageFailure(
        RecipeFailure(
          code: RecipeFailureCode.invalidData,
          message: error.message,
        ),
      );
      return <String>[error.message];
    }

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
      imageUrl: null,
      imageStoragePath: null,
      imageMimeType: null,
      imageSizeBytes: null,
    );

    String? createdId;
    String? uploadedStoragePath;
    try {
      createdId = await _recipeService.createRecipe(
        uid: currentUid,
        recipe: payload,
      );
      var createdRecipe = payload.copyWith(id: createdId);

      if (processedImage != null) {
        final uploadResult = await _recipeImageStorageService.uploadRecipeImage(
          uid: currentUid,
          recipeId: createdId,
          bytes: processedImage.bytes,
          mimeType: processedImage.mimeType,
          fileName: _buildStoredImageFileName(processedImage.fileName),
        );
        uploadedStoragePath = uploadResult.storagePath;
        createdRecipe = createdRecipe.copyWith(
          imageUrl: uploadResult.downloadUrl,
          imageStoragePath: uploadResult.storagePath,
          imageMimeType: uploadResult.mimeType,
          imageSizeBytes: uploadResult.sizeBytes,
          updatedAt: DateTime.now(),
        );
        await _recipeService.updateRecipe(
          uid: currentUid,
          recipe: createdRecipe,
        );
      }

      _selectedRecipeId = createdId;
      _upsertRecipe(createdRecipe);
      _status = RecipeProviderStatus.ready;
      _failure = null;
      _safeNotify();
      return const <String>[];
    } catch (error) {
      if (uploadedStoragePath != null) {
        await _deleteStoredImageQuietly(uploadedStoragePath);
      }
      if (createdId != null) {
        try {
          await _recipeService.deleteRecipe(
            uid: currentUid,
            recipeId: createdId,
          );
        } catch (_) {}
      }
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
    RecipeImageSelection? imageSelection,
    bool removeImage = false,
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

    ProcessedRecipeImage? processedImage;
    try {
      processedImage = await _processImageSelection(imageSelection);
    } on RecipeImageProcessingException catch (error) {
      _applyMessageFailure(
        RecipeFailure(
          code: RecipeFailureCode.invalidData,
          message: error.message,
        ),
      );
      return <String>[error.message];
    }

    final existingRecipe = _findRecipeById(recipeId);
    final now = DateTime.now();
    String? nextImageUrl = existingRecipe?.imageUrl;
    String? nextImageStoragePath = existingRecipe?.imageStoragePath;
    String? nextImageMimeType = existingRecipe?.imageMimeType;
    int? nextImageSizeBytes = existingRecipe?.imageSizeBytes;

    if (removeImage) {
      nextImageUrl = null;
      nextImageStoragePath = null;
      nextImageMimeType = null;
      nextImageSizeBytes = null;
    }

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
      imageUrl: nextImageUrl,
      imageStoragePath: nextImageStoragePath,
      imageMimeType: nextImageMimeType,
      imageSizeBytes: nextImageSizeBytes,
    );

    _status = RecipeProviderStatus.mutating;
    _errorMessage = null;
    _failure = null;
    _safeNotify();

    String? uploadedStoragePath;
    Recipe updatedPayload = payload;
    try {
      if (processedImage != null) {
        final uploadResult = await _recipeImageStorageService.uploadRecipeImage(
          uid: currentUid,
          recipeId: payload.id,
          bytes: processedImage.bytes,
          mimeType: processedImage.mimeType,
          fileName: _buildStoredImageFileName(processedImage.fileName),
        );
        uploadedStoragePath = uploadResult.storagePath;
        updatedPayload = payload.copyWith(
          imageUrl: uploadResult.downloadUrl,
          imageStoragePath: uploadResult.storagePath,
          imageMimeType: uploadResult.mimeType,
          imageSizeBytes: uploadResult.sizeBytes,
        );
      }

      await _recipeService.updateRecipe(
        uid: currentUid,
        recipe: updatedPayload,
      );
      _selectedRecipeId = updatedPayload.id;
      _upsertRecipe(updatedPayload);

      final previousStoragePath = existingRecipe?.imageStoragePath;
      final nextStoragePath = updatedPayload.imageStoragePath;
      final shouldDeletePreviousImage =
          previousStoragePath != null &&
          previousStoragePath.isNotEmpty &&
          (removeImage ||
              (uploadedStoragePath != null &&
                  previousStoragePath != nextStoragePath));
      if (shouldDeletePreviousImage) {
        await _deleteStoredImageQuietly(previousStoragePath);
      }

      _status = RecipeProviderStatus.ready;
      _failure = null;
      _safeNotify();
      return const <String>[];
    } catch (error) {
      if (uploadedStoragePath != null) {
        await _deleteStoredImageQuietly(uploadedStoragePath);
      }
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
      final hasPlannedMeals = await _mealPlanService.hasEntriesForRecipe(
        uid: currentUid,
        recipeId: recipeId,
      );
      if (hasPlannedMeals) {
        _applyMessageFailure(
          const RecipeFailure(
            code: RecipeFailureCode.dependencyConflict,
            message:
                'This recipe is still used in your meal plan. Remove those planned meals before deleting it.',
          ),
        );
        return false;
      }

      await _recipeService.deleteRecipe(uid: currentUid, recipeId: recipeId);
      final imageStoragePath = _findRecipeById(recipeId)?.imageStoragePath;
      if (imageStoragePath != null && imageStoragePath.isNotEmpty) {
        await _deleteStoredImageQuietly(imageStoragePath);
      }
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

  Future<ProcessedRecipeImage?> _processImageSelection(
    RecipeImageSelection? imageSelection,
  ) async {
    if (imageSelection == null) {
      return null;
    }

    return _recipeImageProcessor.processImage(
      bytes: imageSelection.bytes,
      originalFileName: imageSelection.fileName,
      mimeType: imageSelection.mimeType,
    );
  }

  String _buildStoredImageFileName(String sourceFileName) {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    return 'cover_$timestamp.jpg';
  }

  Future<void> _deleteStoredImageQuietly(String storagePath) async {
    try {
      await _recipeImageStorageService.deleteRecipeImage(storagePath);
    } catch (_) {}
  }

  @override
  void dispose() {
    _disposed = true;
    _recipesSubscription?.cancel();
    super.dispose();
  }
}
