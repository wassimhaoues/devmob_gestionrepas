import 'dart:async';
import 'dart:typed_data';

import 'package:devmob_gestionrepas/models/ingredient.dart';
import 'package:devmob_gestionrepas/models/processed_recipe_image.dart';
import 'package:devmob_gestionrepas/models/recipe.dart';
import 'package:devmob_gestionrepas/models/recipe_category.dart';
import 'package:devmob_gestionrepas/models/recipe_failure.dart';
import 'package:devmob_gestionrepas/models/recipe_image_upload_result.dart';
import 'package:devmob_gestionrepas/models/recipe_image_selection.dart';
import 'package:devmob_gestionrepas/models/recipe_step.dart';
import 'package:devmob_gestionrepas/providers/recipe_provider.dart';
import 'package:devmob_gestionrepas/services/recipe/recipe_exception.dart';
import 'package:devmob_gestionrepas/services/recipe/recipe_image_processor.dart';
import 'package:devmob_gestionrepas/services/recipe/recipe_image_storage_service.dart';
import 'package:devmob_gestionrepas/services/recipe/recipe_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _FakeRecipeService recipeService;
  late _FakeRecipeImageStorageService imageStorageService;
  late _FakeRecipeImageProcessor imageProcessor;

  setUp(() {
    recipeService = _FakeRecipeService();
    imageStorageService = _FakeRecipeImageStorageService();
    imageProcessor = _FakeRecipeImageProcessor();
  });

  tearDown(() async {
    await recipeService.dispose();
  });

  RecipeProvider buildProvider() {
    return RecipeProvider(
      recipeService: recipeService,
      recipeImageStorageService: imageStorageService,
      recipeImageProcessor: imageProcessor,
    );
  }

  test('startWatching listens to stream and updates list state', () async {
    final provider = buildProvider();

    await provider.startWatching(uid: 'user-1');
    expect(provider.status, RecipeProviderStatus.loading);

    recipeService.emitRecipes(<Recipe>[
      _sampleRecipe(id: 'r1', ownerUid: 'user-1'),
    ]);
    await _flushAsync();

    expect(provider.status, RecipeProviderStatus.ready);
    expect(provider.recipes.length, 1);
    expect(provider.recipes.first.id, 'r1');
    provider.dispose();
  });

  test('setCategoryFilter restarts watcher with selected category', () async {
    final provider = buildProvider();

    await provider.startWatching(uid: 'user-1');
    await provider.setCategoryFilter(RecipeCategory.dinner);

    expect(recipeService.lastWatchUid, 'user-1');
    expect(recipeService.lastWatchCategory, RecipeCategory.dinner);
    provider.dispose();
  });

  test(
    'createRecipe normalizes ingredient values before persistence',
    () async {
      final provider = buildProvider();
      await provider.startWatching(uid: 'user-1');

      final errors = await provider.createRecipe(
        title: 'Tomato Soup',
        description: 'Simple soup',
        category: RecipeCategory.lunch,
        ingredients: const <Ingredient>[
          Ingredient(
            displayName: '  Tómatoes  ',
            canonicalName: '',
            quantity: 2,
            unit: '  pieces  ',
          ),
        ],
        steps: const <RecipeStep>[
          RecipeStep(order: 10, text: '  boil   water  '),
        ],
      );

      expect(errors, isEmpty);
      final created = recipeService.lastCreatedRecipe;
      expect(created, isNotNull);
      expect(created!.ingredients.first.displayName, 'Tómatoes');
      expect(created.ingredients.first.canonicalName, 'tomato');
      expect(created.ingredients.first.unit, 'pieces');
      expect(created.steps.first.order, 1);
      expect(created.steps.first.text, 'boil water');
      provider.dispose();
    },
  );

  test('createRecipe returns validation errors for invalid payload', () async {
    final provider = buildProvider();
    await provider.startWatching(uid: 'user-1');

    final errors = await provider.createRecipe(
      title: '  ',
      description: null,
      category: null,
      ingredients: const <Ingredient>[],
      steps: const <RecipeStep>[],
    );

    expect(errors, isNotEmpty);
    expect(provider.status, RecipeProviderStatus.error);
    expect(provider.errorMessage, isNotNull);
    provider.dispose();
  });

  test('updateRecipe clears image metadata when removeImage is true', () async {
    final provider = buildProvider();
    await provider.startWatching(uid: 'user-1');
    recipeService.emitRecipes(<Recipe>[
      _sampleRecipe(id: 'recipe-1', ownerUid: 'user-1').copyWith(
        imageUrl: 'https://example.com/recipe.jpg',
        imageStoragePath: 'recipes/recipe-1.jpg',
      ),
    ]);
    await _flushAsync();

    final errors = await provider.updateRecipe(
      recipeId: 'recipe-1',
      title: 'Sample',
      description: 'Updated',
      category: RecipeCategory.breakfast,
      ingredients: const <Ingredient>[
        Ingredient(
          displayName: 'Eggs',
          canonicalName: 'egg',
          quantity: 2,
          unit: 'piece',
        ),
      ],
      steps: const <RecipeStep>[RecipeStep(order: 1, text: 'Cook')],
      removeImage: true,
    );

    expect(errors, isEmpty);
    expect(recipeService.lastUpdatedRecipe, isNotNull);
    expect(recipeService.lastUpdatedRecipe!.imageUrl, isNull);
    expect(recipeService.lastUpdatedRecipe!.imageStoragePath, isNull);
    provider.dispose();
  });

  test('toggleFavorite delegates to service', () async {
    final provider = buildProvider();
    await provider.startWatching(uid: 'user-1');

    final result = await provider.toggleFavorite(
      recipeId: 'recipe-99',
      isFavorite: true,
    );

    expect(result, isTrue);
    expect(recipeService.lastFavoriteRecipeId, 'recipe-99');
    expect(recipeService.lastFavoriteValue, isTrue);
    provider.dispose();
  });

  test('loadRecipeById fetches and caches uncached recipe detail', () async {
    final provider = buildProvider();
    await provider.startWatching(uid: 'user-1');

    recipeService.fetchRecipeByIdResult = _sampleRecipe(
      id: 'r-42',
      ownerUid: 'user-1',
    );

    final recipe = await provider.loadRecipeById('r-42');

    expect(recipe, isNotNull);
    expect(recipeService.lastFetchedRecipeId, 'r-42');
    expect(provider.selectedRecipeId, 'r-42');
    expect(provider.recipeById('r-42'), isNotNull);
    provider.dispose();
  });

  test('loadRecipeById surfaces mapped recipe errors', () async {
    final provider = buildProvider();
    await provider.startWatching(uid: 'user-1');

    recipeService.fetchRecipeByIdError = const RecipeException(
      RecipeFailure(
        code: RecipeFailureCode.permissionDenied,
        message: 'You do not have permission to access this recipe.',
      ),
    );

    final recipe = await provider.loadRecipeById('r-42', forceRefresh: true);

    expect(recipe, isNull);
    expect(provider.status, RecipeProviderStatus.error);
    expect(
      provider.errorMessage,
      'You do not have permission to access this recipe.',
    );
    provider.dispose();
  });

  test('createRecipe uploads processed image and persists metadata', () async {
    final provider = buildProvider();
    await provider.startWatching(uid: 'user-1');
    imageProcessor.result = ProcessedRecipeImage(
      bytes: Uint8List.fromList(const <int>[1, 2, 3]),
      mimeType: 'image/jpeg',
      fileName: 'recipe.jpg',
      width: 800,
      height: 600,
      sourceSizeBytes: 1024,
      outputSizeBytes: 3,
    );

    final errors = await provider.createRecipe(
      title: 'Tomato Soup',
      description: 'Simple soup',
      category: RecipeCategory.lunch,
      ingredients: const <Ingredient>[
        Ingredient(
          displayName: 'Tomatoes',
          canonicalName: 'tomato',
          quantity: 2,
          unit: 'pieces',
        ),
      ],
      steps: const <RecipeStep>[RecipeStep(order: 1, text: 'Cook')],
      imageSelection: RecipeImageSelection(
        bytes: Uint8List.fromList(const <int>[8, 9, 10]),
        fileName: 'phone.png',
        mimeType: 'image/png',
      ),
    );

    expect(errors, isEmpty);
    expect(imageStorageService.lastUploadRecipeId, 'new-recipe-id');
    expect(recipeService.lastUpdatedRecipe?.imageUrl, isNotNull);
    expect(recipeService.lastUpdatedRecipe?.imageMimeType, 'image/jpeg');
    expect(recipeService.lastUpdatedRecipe?.imageSizeBytes, 3);
    provider.dispose();
  });

  test('updateRecipe removes previous stored image when requested', () async {
    final provider = buildProvider();
    await provider.startWatching(uid: 'user-1');
    recipeService.emitRecipes(<Recipe>[
      _sampleRecipe(id: 'recipe-1', ownerUid: 'user-1').copyWith(
        imageUrl: 'https://example.com/recipe.jpg',
        imageStoragePath: 'users/user-1/recipes/recipe-1/cover_old.jpg',
        imageMimeType: 'image/jpeg',
        imageSizeBytes: 1200,
      ),
    ]);
    await _flushAsync();

    final errors = await provider.updateRecipe(
      recipeId: 'recipe-1',
      title: 'Sample',
      description: 'Updated',
      category: RecipeCategory.breakfast,
      ingredients: const <Ingredient>[
        Ingredient(
          displayName: 'Eggs',
          canonicalName: 'egg',
          quantity: 2,
          unit: 'piece',
        ),
      ],
      steps: const <RecipeStep>[RecipeStep(order: 1, text: 'Cook')],
      removeImage: true,
    );

    expect(errors, isEmpty);
    expect(
      imageStorageService.deletedPaths,
      contains('users/user-1/recipes/recipe-1/cover_old.jpg'),
    );
    expect(recipeService.lastUpdatedRecipe?.imageUrl, isNull);
    provider.dispose();
  });
}

Future<void> _flushAsync() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

class _FakeRecipeService implements RecipeService {
  final StreamController<List<Recipe>> _controller =
      StreamController<List<Recipe>>.broadcast();

  String? lastWatchUid;
  RecipeCategory? lastWatchCategory;
  bool? lastWatchFavoritesOnly;

  String? lastCreatedUid;
  Recipe? lastCreatedRecipe;

  String? lastUpdatedUid;
  Recipe? lastUpdatedRecipe;

  String? lastDeletedUid;
  String? lastDeletedRecipeId;

  String? lastFavoriteUid;
  String? lastFavoriteRecipeId;
  bool? lastFavoriteValue;

  List<Recipe> fetchResult = const <Recipe>[];
  Recipe? fetchRecipeByIdResult;
  Object? fetchRecipeByIdError;
  String? lastFetchedRecipeId;

  @override
  Stream<List<Recipe>> watchRecipes({
    required String uid,
    RecipeCategory? category,
    bool favoritesOnly = false,
  }) {
    lastWatchUid = uid;
    lastWatchCategory = category;
    lastWatchFavoritesOnly = favoritesOnly;
    return _controller.stream;
  }

  @override
  Future<List<Recipe>> fetchRecipes({
    required String uid,
    RecipeCategory? category,
    bool favoritesOnly = false,
  }) async {
    return fetchResult;
  }

  @override
  Future<Recipe?> fetchRecipeById({
    required String uid,
    required String recipeId,
  }) async {
    lastFetchedRecipeId = recipeId;
    if (fetchRecipeByIdError != null) {
      throw fetchRecipeByIdError!;
    }
    return fetchRecipeByIdResult;
  }

  @override
  Future<String> createRecipe({
    required String uid,
    required Recipe recipe,
  }) async {
    lastCreatedUid = uid;
    lastCreatedRecipe = recipe;
    return 'new-recipe-id';
  }

  @override
  Future<void> updateRecipe({
    required String uid,
    required Recipe recipe,
  }) async {
    lastUpdatedUid = uid;
    lastUpdatedRecipe = recipe;
  }

  @override
  Future<void> deleteRecipe({
    required String uid,
    required String recipeId,
  }) async {
    lastDeletedUid = uid;
    lastDeletedRecipeId = recipeId;
  }

  @override
  Future<void> setFavorite({
    required String uid,
    required String recipeId,
    required bool isFavorite,
  }) async {
    lastFavoriteUid = uid;
    lastFavoriteRecipeId = recipeId;
    lastFavoriteValue = isFavorite;
  }

  void emitRecipes(List<Recipe> recipes) {
    _controller.add(recipes);
  }

  Future<void> dispose() async {
    await _controller.close();
  }
}

class _FakeRecipeImageStorageService implements RecipeImageStorageService {
  String? lastUploadUid;
  String? lastUploadRecipeId;
  String? lastUploadMimeType;
  String? lastUploadFileName;
  Uint8List? lastUploadBytes;
  final List<String> deletedPaths = <String>[];

  @override
  String buildStoragePath({
    required String uid,
    required String recipeId,
    String fileName = 'cover.webp',
  }) {
    return 'users/$uid/recipes/$recipeId/$fileName';
  }

  @override
  Future<void> deleteRecipeImage(String storagePath) async {
    deletedPaths.add(storagePath);
  }

  @override
  Future<RecipeImageUploadResult> uploadRecipeImage({
    required String uid,
    required String recipeId,
    required Uint8List bytes,
    required String mimeType,
    String fileName = 'cover.webp',
  }) async {
    lastUploadUid = uid;
    lastUploadRecipeId = recipeId;
    lastUploadMimeType = mimeType;
    lastUploadFileName = fileName;
    lastUploadBytes = bytes;
    return RecipeImageUploadResult(
      downloadUrl: 'https://example.com/$recipeId.jpg',
      storagePath: 'users/$uid/recipes/$recipeId/$fileName',
      mimeType: mimeType,
      sizeBytes: bytes.lengthInBytes,
    );
  }
}

class _FakeRecipeImageProcessor implements RecipeImageProcessor {
  ProcessedRecipeImage? result;

  @override
  Future<ProcessedRecipeImage> processImage({
    required Uint8List bytes,
    required String originalFileName,
    String? mimeType,
  }) async {
    return result ??
        ProcessedRecipeImage(
          bytes: bytes,
          mimeType: mimeType ?? 'image/jpeg',
          fileName: originalFileName,
          width: 100,
          height: 100,
          sourceSizeBytes: bytes.lengthInBytes,
          outputSizeBytes: bytes.lengthInBytes,
        );
  }
}

Recipe _sampleRecipe({required String id, required String ownerUid}) {
  final now = DateTime.now();
  return Recipe(
    id: id,
    ownerUid: ownerUid,
    title: 'Sample',
    description: 'Sample description',
    category: RecipeCategory.breakfast,
    isFavorite: false,
    ingredients: const <Ingredient>[
      Ingredient(
        displayName: 'Eggs',
        canonicalName: 'egg',
        quantity: 2,
        unit: 'piece',
      ),
    ],
    steps: const <RecipeStep>[RecipeStep(order: 1, text: 'Cook')],
    createdAt: now,
    updatedAt: now,
  );
}
