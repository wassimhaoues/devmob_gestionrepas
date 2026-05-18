import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:devmob_gestionrepas/models/meal_plan_failure.dart';
import 'package:devmob_gestionrepas/services/mealplan/firebase_meal_plan_error_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DefaultFirebaseMealPlanErrorMapper', () {
    final mapper = DefaultFirebaseMealPlanErrorMapper();

    test('maps permission denied errors to a friendly meal plan failure', () {
      final failure = mapper.map(
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
      );

      expect(failure.code, MealPlanFailureCode.permissionDenied);
      expect(
        failure.message,
        'You do not have permission to access this meal plan.',
      );
    });

    test('maps argument errors to invalid data failure', () {
      final failure = mapper.map(ArgumentError('Meal plan entry id is required.'));

      expect(failure.code, MealPlanFailureCode.invalidData);
      expect(failure.message, 'Meal plan entry id is required.');
    });
  });
}
