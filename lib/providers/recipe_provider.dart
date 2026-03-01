import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/recipe.dart';
import '../models/recipe_category.dart';
import '../services/recipe/recipe_service.dart';

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
