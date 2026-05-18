class RecipeImageProcessingException implements Exception {
  const RecipeImageProcessingException(this.message);

  final String message;

  @override
  String toString() => message;
}
