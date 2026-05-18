import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:mime/mime.dart';
import 'package:path/path.dart' as path;

import '../../models/processed_recipe_image.dart';
import 'recipe_image_processing_exception.dart';
import 'recipe_image_processor.dart';

class DefaultRecipeImageProcessor implements RecipeImageProcessor {
  static const int maxSourceSizeBytes = 10 * 1024 * 1024;
  static const int maxDimension = 1600;
  static const int outputJpegQuality = 82;
  static const Set<String> supportedMimeTypes = <String>{
    'image/jpeg',
    'image/png',
    'image/webp',
  };

  @override
  Future<ProcessedRecipeImage> processImage({
    required Uint8List bytes,
    required String originalFileName,
    String? mimeType,
  }) async {
    final sourceSizeBytes = bytes.lengthInBytes;
    if (sourceSizeBytes > maxSourceSizeBytes) {
      throw const RecipeImageProcessingException(
        'Selected image must be 10 MB or smaller.',
      );
    }

    final normalizedFileName = _normalizeFileName(originalFileName);
    final resolvedMimeType = _resolveMimeType(
      bytes: bytes,
      fileName: normalizedFileName,
      providedMimeType: mimeType,
    );

    if (!supportedMimeTypes.contains(resolvedMimeType)) {
      throw const RecipeImageProcessingException(
        'Only JPG, PNG, and WEBP images are supported.',
      );
    }

    final decodedImage = img.decodeImage(bytes);
    if (decodedImage == null) {
      throw const RecipeImageProcessingException(
        'The selected image could not be decoded safely.',
      );
    }

    final resizedImage = _resizeIfNeeded(decodedImage);
    final encodedBytes = img.encodeJpg(
      resizedImage,
      quality: outputJpegQuality,
    );
    final outputFileName =
        '${path.basenameWithoutExtension(normalizedFileName)}.jpg';

    return ProcessedRecipeImage(
      bytes: encodedBytes,
      mimeType: 'image/jpeg',
      fileName: outputFileName,
      width: resizedImage.width,
      height: resizedImage.height,
      sourceSizeBytes: sourceSizeBytes,
      outputSizeBytes: encodedBytes.lengthInBytes,
    );
  }

  String _resolveMimeType({
    required Uint8List bytes,
    required String fileName,
    required String? providedMimeType,
  }) {
    final detectedMimeType = lookupMimeType(fileName, headerBytes: bytes);
    final normalizedProvidedMimeType = providedMimeType?.trim().toLowerCase();

    if (detectedMimeType != null) {
      return detectedMimeType;
    }
    if (normalizedProvidedMimeType != null &&
        normalizedProvidedMimeType.isNotEmpty) {
      return normalizedProvidedMimeType;
    }

    throw const RecipeImageProcessingException(
      'The selected file is not a recognized image format.',
    );
  }

  String _normalizeFileName(String originalFileName) {
    final trimmed = originalFileName.trim();
    if (trimmed.isEmpty) {
      return 'recipe_image.jpg';
    }

    final basename = path.basename(trimmed);
    if (path.extension(basename).isEmpty) {
      return '$basename.jpg';
    }
    return basename;
  }

  img.Image _resizeIfNeeded(img.Image sourceImage) {
    final width = sourceImage.width;
    final height = sourceImage.height;
    final longestEdge = width > height ? width : height;
    if (longestEdge <= maxDimension) {
      return sourceImage;
    }

    if (width >= height) {
      return img.copyResize(
        sourceImage,
        width: maxDimension,
        interpolation: img.Interpolation.average,
      );
    }

    return img.copyResize(
      sourceImage,
      height: maxDimension,
      interpolation: img.Interpolation.average,
    );
  }
}
