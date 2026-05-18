import 'meal_slot_type.dart';

class MealPlanAssignmentArgs {
  const MealPlanAssignmentArgs({
    required this.date,
    required this.slotType,
  });

  final DateTime date;
  final MealSlotType slotType;
}
