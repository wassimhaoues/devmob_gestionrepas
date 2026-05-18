import '../../models/meal_plan_failure.dart';

class MealPlanException implements Exception {
  const MealPlanException(this.failure);

  final MealPlanFailure failure;
}
