enum IngredientUnit {
  g('g', 'Grams'),
  kg('kg', 'Kilograms'),
  mg('mg', 'Milligrams'),
  ml('ml', 'Milliliters'),
  l('l', 'Liters'),
  cl('cl', 'Centiliters'),
  tsp('tsp', 'Teaspoon'),
  tbsp('tbsp', 'Tablespoon'),
  cup('cup', 'Cup'),
  piece('piece', 'Piece'),
  pinch('pinch', 'Pinch'),
  bunch('bunch', 'Bunch'),
  slice('slice', 'Slice'),
  can('can', 'Can'),
  toTaste('to_taste', 'To taste');

  const IngredientUnit(this.value, this.label);

  final String value;
  final String label;

  String get displayLabel => '$value — $label';

  static IngredientUnit fromValue(String raw) {
    final normalized = raw.trim().toLowerCase();
    for (final unit in IngredientUnit.values) {
      if (unit.value == normalized) {
        return unit;
      }
    }
    switch (normalized) {
      case 'gram':
      case 'grams':
        return g;
      case 'kilogram':
      case 'kilograms':
        return kg;
      case 'milligram':
      case 'milligrams':
        return mg;
      case 'milliliter':
      case 'milliliters':
        return ml;
      case 'liter':
      case 'liters':
        return l;
      case 'centiliter':
      case 'centiliters':
        return cl;
      case 'teaspoon':
      case 'teaspoons':
      case 'ts':
        return tsp;
      case 'tablespoon':
      case 'tablespoons':
      case 'tbs':
        return tbsp;
      case 'cups':
        return cup;
      case 'pieces':
      case 'unit':
      case 'units':
      case 'clove':
      case 'cloves':
      case 'whole':
        return piece;
      case 'pinches':
        return pinch;
      case 'bunches':
        return bunch;
      case 'slices':
        return slice;
      case 'cans':
        return can;
      case 'taste':
      case 'to taste':
      case 'totaste':
      case 'to_taste':
        return toTaste;
      default:
        return piece;
    }
  }
}
