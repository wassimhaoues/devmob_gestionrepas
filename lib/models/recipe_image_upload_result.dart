class RecipeImageUploadResult {
  const RecipeImageUploadResult({
    required this.downloadUrl,
    required this.storagePath,
    required this.mimeType,
    required this.sizeBytes,
  });

  final String downloadUrl;
  final String storagePath;
  final String mimeType;
  final int sizeBytes;
}
