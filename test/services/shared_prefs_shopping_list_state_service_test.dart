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

  test('writes and reads checked ids for the same user and week', () async {
    await service.writeCheckedItemIds(
      uid: 'user-1',
      weekStartDate: weekStartDate,
      itemIds: <String>{'milk__l', 'tomato__piece'},
    );

    final checkedIds = await service.readCheckedItemIds(
      uid: 'user-1',
      weekStartDate: weekStartDate,
    );

    expect(checkedIds, <String>{'milk__l', 'tomato__piece'});
  });

  test('keeps persisted state isolated by week and user', () async {
    await service.writeCheckedItemIds(
      uid: 'user-1',
      weekStartDate: weekStartDate,
      itemIds: <String>{'milk__l'},
    );
    await service.writeCheckedItemIds(
      uid: 'user-2',
      weekStartDate: weekStartDate,
      itemIds: <String>{'tomato__piece'},
    );
    await service.writeCheckedItemIds(
      uid: 'user-1',
      weekStartDate: DateTime(2026, 5, 25),
      itemIds: <String>{'rice__kg'},
    );

    expect(
      await service.readCheckedItemIds(
        uid: 'user-1',
        weekStartDate: weekStartDate,
      ),
      <String>{'milk__l'},
    );
    expect(
      await service.readCheckedItemIds(
        uid: 'user-2',
        weekStartDate: weekStartDate,
      ),
      <String>{'tomato__piece'},
    );
    expect(
      await service.readCheckedItemIds(
        uid: 'user-1',
        weekStartDate: DateTime(2026, 5, 25),
      ),
      <String>{'rice__kg'},
    );
  });

  test('clear removes checked ids for the selected user and week', () async {
    await service.writeCheckedItemIds(
      uid: 'user-1',
      weekStartDate: weekStartDate,
      itemIds: <String>{'milk__l'},
    );

    await service.clearCheckedItemIds(
      uid: 'user-1',
      weekStartDate: weekStartDate,
    );

    final checkedIds = await service.readCheckedItemIds(
      uid: 'user-1',
      weekStartDate: weekStartDate,
    );
    expect(checkedIds, isEmpty);
  });
}
