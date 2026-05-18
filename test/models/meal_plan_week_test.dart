import 'package:devmob_gestionrepas/models/meal_plan_week.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('MealPlanWeek.fromAnchor creates a Monday-start week', () {
    final week = MealPlanWeek.fromAnchor(DateTime(2026, 5, 20));

    expect(week.startDate, DateTime(2026, 5, 18));
    expect(week.endDate, DateTime(2026, 5, 24));
    expect(week.days, hasLength(7));
    expect(week.days.first.weekday, DateTime.monday);
    expect(week.days.last.weekday, DateTime.sunday);
  });
}
