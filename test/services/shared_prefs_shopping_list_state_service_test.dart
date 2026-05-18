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

  test('writes and reads checked states for the same user and week', () async {
    await service.writeCheckedItemStates(
      uid: 'user-1',
      weekStartDate: weekStartDate,
      itemStates: <String, CheckedShoppingItemState>{
        'milk__l': const CheckedShoppingItemState(
          itemId: 'milk__l',
          totalQuantity: 1,
        ),
        'tomato__piece': const CheckedShoppingItemState(
          itemId: 'tomato__piece',
          totalQuantity: 5,
        ),
      },
    );

    final checkedStates = await service.readCheckedItemStates(
      uid: 'user-1',
      weekStartDate: weekStartDate,
    );

    expect(checkedStates.keys, <String>{'milk__l', 'tomato__piece'});
    expect(checkedStates['milk__l']?.totalQuantity, 1);
    expect(checkedStates['tomato__piece']?.totalQuantity, 5);
  });

  test('keeps persisted state isolated by week and user', () async {
    await service.writeCheckedItemStates(
      uid: 'user-1',
      weekStartDate: weekStartDate,
      itemStates: <String, CheckedShoppingItemState>{
        'milk__l': const CheckedShoppingItemState(
          itemId: 'milk__l',
          totalQuantity: 1,
        ),
      },
    );
    await service.writeCheckedItemStates(
      uid: 'user-2',
      weekStartDate: weekStartDate,
      itemStates: <String, CheckedShoppingItemState>{
        'tomato__piece': const CheckedShoppingItemState(
          itemId: 'tomato__piece',
          totalQuantity: 5,
        ),
      },
    );
    await service.writeCheckedItemStates(
      uid: 'user-1',
      weekStartDate: DateTime(2026, 5, 25),
      itemStates: <String, CheckedShoppingItemState>{
        'rice__kg': const CheckedShoppingItemState(
          itemId: 'rice__kg',
          totalQuantity: 2,
        ),
      },
    );

    expect(
      (await service.readCheckedItemStates(
        uid: 'user-1',
        weekStartDate: weekStartDate,
      ))['milk__l']?.totalQuantity,
      1,
    );
    expect(
      (await service.readCheckedItemStates(
        uid: 'user-2',
        weekStartDate: weekStartDate,
      ))['tomato__piece']?.totalQuantity,
      5,
    );
    expect(
      (await service.readCheckedItemStates(
        uid: 'user-1',
        weekStartDate: DateTime(2026, 5, 25),
      ))['rice__kg']?.totalQuantity,
      2,
    );
  });

  test('clear removes checked ids for the selected user and week', () async {
    await service.writeCheckedItemStates(
      uid: 'user-1',
      weekStartDate: weekStartDate,
      itemStates: <String, CheckedShoppingItemState>{
        'milk__l': const CheckedShoppingItemState(
          itemId: 'milk__l',
          totalQuantity: 1,
        ),
      },
    );

    await service.clearCheckedItemIds(
      uid: 'user-1',
      weekStartDate: weekStartDate,
    );

    final checkedIds = await service.readCheckedItemStates(
      uid: 'user-1',
      weekStartDate: weekStartDate,
    );
    expect(checkedIds, isEmpty);
  });
}
