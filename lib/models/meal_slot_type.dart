enum MealSlotType {
  breakfast('breakfast', 'Breakfast'),
  lunch('lunch', 'Lunch'),
  dinner('dinner', 'Dinner'),
  dessert('dessert', 'Dessert');

  const MealSlotType(this.value, this.label);

  final String value;
  final String label;

  static MealSlotType fromValue(String value) {
    final normalized = value.trim().toLowerCase();
    for (final slot in MealSlotType.values) {
      if (slot.value == normalized) {
        return slot;
      }
    }

    throw FormatException('Unsupported meal slot type: $value');
  }
}
