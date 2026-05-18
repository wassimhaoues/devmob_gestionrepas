import 'dart:typed_data';

import '../../models/processed_recipe_image.dart';

abstract interface class RecipeImageProcessor {
  Future<ProcessedRecipeImage> processImage({
    required Uint8List bytes,
    required String originalFileName,
    String? mimeType,
  });
}
