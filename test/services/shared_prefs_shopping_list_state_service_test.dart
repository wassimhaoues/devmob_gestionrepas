import 'package:devmob_gestionrepas/models/shopping_list_item.dart';
import 'package:devmob_gestionrepas/services/shopping/local_shopping_list_state_service.dart';
import 'package:devmob_gestionrepas/services/shopping/shared_prefs_shopping_list_state_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPrefsShoppingListStateService service;
  final weekStartDate = DateTime(2026, 5, 18);

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    service = SharedPrefsShoppingListStateService();
  });

  test(
    'writes and reads local shopping state for the same user and week',
    () async {
      await service.writeState(
        uid: 'user-1',
        weekStartDate: weekStartDate,
        state: ShoppingListLocalState(
          completedItems: <ShoppingListItem>[
            ShoppingListItem(
              id: 'completed_batch',
              ingredientKey: 'milk__l',
              canonicalName: 'milk',
              displayName: 'Milk',
              totalQuantity: 1,
              unit: 'L',
              status: ShoppingListItemStatus.completed,
              origin: ShoppingListItemOrigin.generated,
              isNewBatch: false,
              sourceRecipeIds: <String>[],
              createdAt: DateTime(2026, 5, 19),
              completedAt: DateTime(2026, 5, 19, 12),
            ),
          ],
          separatePendingItems: <ShoppingListItem>[
            ShoppingListItem(
              id: 'pending_batch',
              ingredientKey: 'tomato__piece',
              canonicalName: 'tomato',
              displayName: 'Tomatoes',
              totalQuantity: 2,
              unit: 'piece',
              status: ShoppingListItemStatus.pending,
              origin: ShoppingListItemOrigin.reopened,
              isNewBatch: true,
              sourceRecipeIds: <String>[],
              createdAt: DateTime(2026, 5, 19, 13),
            ),
          ],
        ),
      );

      final restored = await service.readState(
        uid: 'user-1',
        weekStartDate: weekStartDate,
      );

      expect(restored.completedItems, hasLength(1));
      expect(restored.separatePendingItems, hasLength(1));
      expect(restored.completedItems.single.ingredientKey, 'milk__l');
      expect(
        restored.separatePendingItems.single.origin,
        ShoppingListItemOrigin.reopened,
      );
    },
  );

  test('keeps persisted state isolated by week and user', () async {
    await service.writeState(
      uid: 'user-1',
      weekStartDate: weekStartDate,
      state: ShoppingListLocalState(
        completedItems: <ShoppingListItem>[
          ShoppingListItem(
            id: 'completed_batch',
            ingredientKey: 'milk__l',
            canonicalName: 'milk',
            displayName: 'Milk',
            totalQuantity: 1,
            unit: 'L',
            status: ShoppingListItemStatus.completed,
            origin: ShoppingListItemOrigin.generated,
            isNewBatch: false,
            sourceRecipeIds: <String>[],
            createdAt: DateTime(2026, 5, 19),
            completedAt: DateTime(2026, 5, 19, 12),
          ),
        ],
        separatePendingItems: <ShoppingListItem>[],
      ),
    );
    await service.writeState(
      uid: 'user-2',
      weekStartDate: weekStartDate,
      state: ShoppingListLocalState(
        completedItems: <ShoppingListItem>[],
        separatePendingItems: <ShoppingListItem>[
          ShoppingListItem(
            id: 'pending_batch',
            ingredientKey: 'olive__cup',
            canonicalName: 'olive',
            displayName: 'Black Olives',
            totalQuantity: 2,
            unit: 'cup',
            status: ShoppingListItemStatus.pending,
            origin: ShoppingListItemOrigin.reopened,
            isNewBatch: true,
            sourceRecipeIds: <String>[],
            createdAt: DateTime(2026, 5, 19, 13),
          ),
        ],
      ),
    );

    expect(
      (await service.readState(
        uid: 'user-1',
        weekStartDate: weekStartDate,
      )).completedItems,
      hasLength(1),
    );
    expect(
      (await service.readState(
        uid: 'user-2',
        weekStartDate: weekStartDate,
      )).separatePendingItems,
      hasLength(1),
    );
  });

  test('clear removes shopping state for the selected user and week', () async {
    await service.writeState(
      uid: 'user-1',
      weekStartDate: weekStartDate,
      state: ShoppingListLocalState(
        completedItems: <ShoppingListItem>[
          ShoppingListItem(
            id: 'completed_batch',
            ingredientKey: 'milk__l',
            canonicalName: 'milk',
            displayName: 'Milk',
            totalQuantity: 1,
            unit: 'L',
            status: ShoppingListItemStatus.completed,
            origin: ShoppingListItemOrigin.generated,
            isNewBatch: false,
            sourceRecipeIds: <String>[],
            createdAt: DateTime(2026, 5, 19),
            completedAt: DateTime(2026, 5, 19, 12),
          ),
        ],
        separatePendingItems: <ShoppingListItem>[],
      ),
    );

    await service.clearState(uid: 'user-1', weekStartDate: weekStartDate);

    final restored = await service.readState(
      uid: 'user-1',
      weekStartDate: weekStartDate,
    );
    expect(restored.completedItems, isEmpty);
    expect(restored.separatePendingItems, isEmpty);
  });
}
