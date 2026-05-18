import '../../models/recipe_failure.dart';

class RecipeException implements Exception {
  const RecipeException(this.failure);

  final RecipeFailure failure;

  @override
  String toString() => failure.message;
}
