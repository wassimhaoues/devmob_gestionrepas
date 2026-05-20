import 'package:devmob_gestionrepas/models/shopping_list.dart';
import 'package:devmob_gestionrepas/models/shopping_list_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ShoppingList.toMap and ShoppingList.fromMap preserve items', () {
    final shoppingList = ShoppingList(
      ownerUid: 'user-1',
      weekStartDate: DateTime(2026, 5, 18),
      generatedAt: DateTime(2026, 5, 19, 9, 30),
      items: <ShoppingListItem>[
        ShoppingListItem(
          id: 'tomato__piece',
          ingredientKey: 'tomato__piece',
          canonicalName: 'tomato',
          displayName: 'Tomatoes',
          totalQuantity: 5,
          unit: 'piece',
          status: ShoppingListItemStatus.completed,
          origin: ShoppingListItemOrigin.generated,
          isNewBatch: false,
          sourceRecipeIds: <String>['recipe-1', 'recipe-2'],
          createdAt: DateTime(2026, 5, 19, 9, 30),
          completedAt: DateTime(2026, 5, 19, 10),
        ),
      ],
    );

    final restored = ShoppingList.fromMap(shoppingList.toMap());

    expect(restored.ownerUid, shoppingList.ownerUid);
    expect(restored.weekStartDate, shoppingList.weekStartDate);
    expect(restored.generatedAt, shoppingList.generatedAt);
    expect(restored.items, hasLength(1));
    expect(restored.items.first.id, 'tomato__piece');
    expect(restored.items.first.ingredientKey, 'tomato__piece');
    expect(restored.items.first.isChecked, isTrue);
    expect(restored.items.first.sourceRecipeIds, <String>[
      'recipe-1',
      'recipe-2',
    ]);
  });
}
