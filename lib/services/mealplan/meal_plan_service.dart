import '../../models/meal_plan_entry.dart';

abstract interface class MealPlanService {
  Stream<List<MealPlanEntry>> watchEntries({
    required String uid,
    required DateTime startDate,
    required DateTime endDate,
  });

  Future<List<MealPlanEntry>> fetchEntries({
    required String uid,
    required DateTime startDate,
    required DateTime endDate,
  });

  Future<void> upsertEntry({
    required String uid,
    required MealPlanEntry entry,
  });

  Future<void> deleteEntry({
    required String uid,
    required String entryId,
  });
}
