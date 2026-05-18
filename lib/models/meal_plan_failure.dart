enum MealPlanFailureCode {
  unauthenticated,
  permissionDenied,
  notFound,
  unavailable,
  invalidData,
  unknown,
}

class MealPlanFailure {
  const MealPlanFailure({required this.code, required this.message});

  final MealPlanFailureCode code;
  final String message;
}
