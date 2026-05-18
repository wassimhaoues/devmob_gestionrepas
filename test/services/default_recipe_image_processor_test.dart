import 'dart:typed_data';

import 'package:devmob_gestionrepas/services/recipe/default_recipe_image_processor.dart';
import 'package:devmob_gestionrepas/services/recipe/recipe_image_processing_exception.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  final processor = DefaultRecipeImageProcessor();

  test('rejects images larger than 10 MB', () async {
    final oversizedBytes = Uint8List(
      DefaultRecipeImageProcessor.maxSourceSizeBytes + 1,
    );

    expect(
      () => processor.processImage(
        bytes: oversizedBytes,
        originalFileName: 'large.jpg',
        mimeType: 'image/jpeg',
      ),
      throwsA(isA<RecipeImageProcessingException>()),
    );
  });

  test('rejects unsupported file types', () async {
    final invalidBytes = Uint8List.fromList('not-an-image'.codeUnits);

    expect(
      () => processor.processImage(
        bytes: invalidBytes,
        originalFileName: 'payload.txt',
        mimeType: 'text/plain',
      ),
      throwsA(isA<RecipeImageProcessingException>()),
    );
  });

  test('resizes oversized images and converts them to jpeg output', () async {
    final sourceImage = img.Image(width: 2400, height: 1200);
    img.fill(sourceImage, color: img.ColorRgb8(255, 120, 0));
    final sourceBytes = img.encodePng(sourceImage);

    final processed = await processor.processImage(
      bytes: sourceBytes,
      originalFileName: 'recipe.png',
      mimeType: 'image/png',
    );

    expect(processed.mimeType, 'image/jpeg');
    expect(processed.fileName, 'recipe.jpg');
    expect(processed.width, DefaultRecipeImageProcessor.maxDimension);
    expect(processed.height, 800);
    expect(processed.outputSizeBytes, equals(processed.bytes.lengthInBytes));
    expect(processed.bytes, isNotEmpty);
  });

  test(
    'rejects malformed image payloads even when mime type looks valid',
    () async {
      final invalidImageBytes = Uint8List.fromList('broken-image'.codeUnits);

      expect(
        () => processor.processImage(
          bytes: invalidImageBytes,
          originalFileName: 'broken.png',
          mimeType: 'image/png',
        ),
        throwsA(isA<RecipeImageProcessingException>()),
      );
    },
  );
}
