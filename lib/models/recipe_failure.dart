enum RecipeFailureCode {
  unauthenticated,
  permissionDenied,
  notFound,
  unavailable,
  invalidData,
  unknown,
}

class RecipeFailure {
  const RecipeFailure({required this.code, required this.message});

  final RecipeFailureCode code;
  final String message;
}
