class MealPlanWeek {
  const MealPlanWeek({
    required this.startDate,
    required this.endDate,
    required this.days,
  });

  final DateTime startDate;
  final DateTime endDate;
  final List<DateTime> days;

  factory MealPlanWeek.fromAnchor(DateTime anchorDate) {
    final normalized = DateTime(anchorDate.year, anchorDate.month, anchorDate.day);
    final startDate = normalized.subtract(Duration(days: normalized.weekday - 1));
    final days = List<DateTime>.generate(
      7,
      (index) => DateTime(
        startDate.year,
        startDate.month,
        startDate.day + index,
      ),
    );
    final endDate = days.last;

    return MealPlanWeek(startDate: startDate, endDate: endDate, days: days);
  }

  MealPlanWeek previousWeek() =>
      MealPlanWeek.fromAnchor(startDate.subtract(const Duration(days: 1)));

  MealPlanWeek nextWeek() =>
      MealPlanWeek.fromAnchor(endDate.add(const Duration(days: 1)));
}
