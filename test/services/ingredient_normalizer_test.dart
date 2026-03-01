import 'package:devmob_gestionrepas/services/recipe/ingredient_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IngredientNormalizer.normalizeDisplayName', () {
    test('trims and collapses whitespace', () {
      expect(
        IngredientNormalizer.normalizeDisplayName('  Fresh   Tomatoes  '),
        'Fresh Tomatoes',
      );
    });
  });

  group('IngredientNormalizer.normalizeCanonicalName', () {
    test('trims, lowercases, and collapses whitespace', () {
      expect(
        IngredientNormalizer.normalizeCanonicalName('  Fresh   Tomatoes  '),
        'fresh tomato',
      );
    });

    test('removes accents and ligatures', () {
      expect(
        IngredientNormalizer.normalizeCanonicalName('Crème brûlée'),
        'creme brulee',
      );
      expect(IngredientNormalizer.normalizeCanonicalName('Œufs'), 'oeuf');
    });

    test('applies simple plural reduction', () {
      expect(IngredientNormalizer.normalizeCanonicalName('potatoes'), 'potato');
      expect(IngredientNormalizer.normalizeCanonicalName('eggs'), 'egg');
      expect(IngredientNormalizer.normalizeCanonicalName('rice'), 'rice');
    });

    test('can disable plural reduction', () {
      expect(
        IngredientNormalizer.normalizeCanonicalName(
          'Tomatoes',
          enablePluralReduction: false,
        ),
        'tomatoes',
      );
    });

    test('returns empty string for empty input', () {
      expect(IngredientNormalizer.normalizeCanonicalName('   '), '');
    });
  });
}
