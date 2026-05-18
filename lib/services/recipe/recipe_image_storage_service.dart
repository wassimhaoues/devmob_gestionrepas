import 'dart:typed_data';

import '../../models/recipe_image_upload_result.dart';

abstract interface class RecipeImageStorageService {
  String buildStoragePath({
    required String uid,
    required String recipeId,
    String fileName = 'cover.webp',
  });

  Future<RecipeImageUploadResult> uploadRecipeImage({
    required String uid,
    required String recipeId,
    required Uint8List bytes,
    required String mimeType,
    String fileName = 'cover.webp',
  });

  Future<void> deleteRecipeImage(String storagePath);
}
