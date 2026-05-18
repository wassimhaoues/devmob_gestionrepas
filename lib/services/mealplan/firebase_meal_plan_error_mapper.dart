import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/meal_plan_failure.dart';

abstract interface class FirebaseMealPlanErrorMapper {
  MealPlanFailure map(Object error);
}

class DefaultFirebaseMealPlanErrorMapper
    implements FirebaseMealPlanErrorMapper {
  @override
  MealPlanFailure map(Object error) {
    if (error is FirebaseException) {
      return _mapFirebaseException(error);
    }
    if (error is ArgumentError) {
      return MealPlanFailure(
        code: MealPlanFailureCode.invalidData,
        message:
            error.message?.toString() ?? 'Invalid meal plan data provided.',
      );
    }

    return const MealPlanFailure(
      code: MealPlanFailureCode.unknown,
      message:
          'Something went wrong while processing the meal plan request.',
    );
  }

  MealPlanFailure _mapFirebaseException(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return const MealPlanFailure(
          code: MealPlanFailureCode.permissionDenied,
          message: 'You do not have permission to access this meal plan.',
        );
      case 'unauthenticated':
        return const MealPlanFailure(
          code: MealPlanFailureCode.unauthenticated,
          message: 'You must be signed in to manage your meal plan.',
        );
      case 'not-found':
        return const MealPlanFailure(
          code: MealPlanFailureCode.notFound,
          message: 'The requested meal plan entry could not be found.',
        );
      case 'unavailable':
        return const MealPlanFailure(
          code: MealPlanFailureCode.unavailable,
          message: 'The meal plan service is temporarily unavailable.',
        );
      case 'invalid-argument':
        return const MealPlanFailure(
          code: MealPlanFailureCode.invalidData,
          message: 'The meal plan data is invalid.',
        );
      default:
        return MealPlanFailure(
          code: MealPlanFailureCode.unknown,
          message: error.message?.trim().isNotEmpty == true
              ? error.message!.trim()
              : 'Something went wrong while processing the meal plan request.',
        );
    }
  }
}
