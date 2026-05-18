import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:devmob_gestionrepas/models/recipe_failure.dart';
import 'package:devmob_gestionrepas/services/recipe/firebase_recipe_error_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DefaultFirebaseRecipeErrorMapper', () {
    final mapper = DefaultFirebaseRecipeErrorMapper();

    test('maps permission denied errors to a friendly recipe failure', () {
      final failure = mapper.map(
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
      );

      expect(failure.code, RecipeFailureCode.permissionDenied);
      expect(
        failure.message,
        'You do not have permission to access this recipe.',
      );
    });

    test('maps argument errors to invalid data failure', () {
      final failure = mapper.map(ArgumentError('Recipe id is required.'));

      expect(failure.code, RecipeFailureCode.invalidData);
      expect(failure.message, 'Recipe id is required.');
    });

    test('falls back to unknown failure for unsupported errors', () {
      final failure = mapper.map(Exception('unexpected'));

      expect(failure.code, RecipeFailureCode.unknown);
      expect(
        failure.message,
        'Something went wrong while processing the recipe request.',
      );
    });
  });
}
