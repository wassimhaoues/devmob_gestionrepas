import 'package:devmob_gestionrepas/models/meal_plan_entry.dart';
import 'package:devmob_gestionrepas/models/meal_slot_type.dart';
import 'package:devmob_gestionrepas/models/recipe_category.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('MealPlanEntry toMap/fromMap preserves denormalized recipe fields', () {
    final entry = MealPlanEntry(
      id: '20260519_breakfast',
      ownerUid: 'user-1',
      date: DateTime(2026, 5, 19, 15, 30),
      slotType: MealSlotType.breakfast,
      recipeId: 'recipe-1',
      recipeTitle: 'Overnight Oats',
      recipeImageUrl: 'https://example.com/oats.jpg',
      recipeCategory: RecipeCategory.breakfast,
      createdAt: DateTime(2026, 5, 1),
      updatedAt: DateTime(2026, 5, 2),
    );

    final restored = MealPlanEntry.fromMap(
      id: entry.id,
      ownerUid: entry.ownerUid,
      data: entry.toMap(),
    );

    expect(restored.id, entry.id);
    expect(restored.ownerUid, entry.ownerUid);
    expect(restored.date, DateTime(2026, 5, 19));
    expect(restored.slotType, MealSlotType.breakfast);
    expect(restored.recipeId, entry.recipeId);
    expect(restored.recipeTitle, entry.recipeTitle);
    expect(restored.recipeImageUrl, entry.recipeImageUrl);
    expect(restored.recipeCategory, RecipeCategory.breakfast);
  });
}
