import 'dart:typed_data';

class ProcessedRecipeImage {
  const ProcessedRecipeImage({
    required this.bytes,
    required this.mimeType,
    required this.fileName,
    required this.width,
    required this.height,
    required this.sourceSizeBytes,
    required this.outputSizeBytes,
  });

  final Uint8List bytes;
  final String mimeType;
  final String fileName;
  final int width;
  final int height;
  final int sourceSizeBytes;
  final int outputSizeBytes;
}
