import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/recipe_failure.dart';

abstract interface class FirebaseRecipeErrorMapper {
  RecipeFailure map(Object error);
}

class DefaultFirebaseRecipeErrorMapper implements FirebaseRecipeErrorMapper {
  @override
  RecipeFailure map(Object error) {
    if (error is FirebaseException) {
      return _mapFirebaseException(error);
    }
    if (error is ArgumentError) {
      return RecipeFailure(
        code: RecipeFailureCode.invalidData,
        message: error.message?.toString() ?? 'Invalid recipe data provided.',
      );
    }

    return const RecipeFailure(
      code: RecipeFailureCode.unknown,
      message: 'Something went wrong while processing the recipe request.',
    );
  }

  RecipeFailure _mapFirebaseException(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return const RecipeFailure(
          code: RecipeFailureCode.permissionDenied,
          message: 'You do not have permission to access this recipe.',
        );
      case 'unauthenticated':
        return const RecipeFailure(
          code: RecipeFailureCode.unauthenticated,
          message: 'You must be signed in to manage recipes.',
        );
      case 'not-found':
        return const RecipeFailure(
          code: RecipeFailureCode.notFound,
          message: 'The requested recipe could not be found.',
        );
      case 'unavailable':
        return const RecipeFailure(
          code: RecipeFailureCode.unavailable,
          message: 'The recipe service is temporarily unavailable.',
        );
      case 'invalid-argument':
        return const RecipeFailure(
          code: RecipeFailureCode.invalidData,
          message: 'The recipe data is invalid.',
        );
      default:
        return RecipeFailure(
          code: RecipeFailureCode.unknown,
          message: error.message?.trim().isNotEmpty == true
              ? error.message!.trim()
              : 'Something went wrong while processing the recipe request.',
        );
    }
  }
}
