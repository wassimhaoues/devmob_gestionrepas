import 'dart:typed_data';

class RecipeImageSelection {
  const RecipeImageSelection({
    required this.bytes,
    required this.fileName,
    this.mimeType,
  });

  final Uint8List bytes;
  final String fileName;
  final String? mimeType;
}
