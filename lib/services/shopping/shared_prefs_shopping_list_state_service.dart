import 'package:shared_preferences/shared_preferences.dart';

import 'local_shopping_list_state_service.dart';

class SharedPrefsShoppingListStateService
    implements LocalShoppingListStateService {
  @override
  Future<void> clearCheckedItemIds({
    required String uid,
    required DateTime weekStartDate,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(
      _buildStorageKey(uid: uid, weekStartDate: weekStartDate),
    );
  }

  @override
  Future<Set<String>> readCheckedItemIds({
    required String uid,
    required DateTime weekStartDate,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final values =
        preferences.getStringList(
          _buildStorageKey(uid: uid, weekStartDate: weekStartDate),
        ) ??
        const <String>[];
    return values
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet();
  }

  @override
  Future<void> writeCheckedItemIds({
    required String uid,
    required DateTime weekStartDate,
    required Set<String> itemIds,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final values = itemIds.toList()..sort();
    await preferences.setStringList(
      _buildStorageKey(uid: uid, weekStartDate: weekStartDate),
      values,
    );
  }

  static String buildWeekKey(DateTime weekStartDate) {
    final normalized = DateTime(
      weekStartDate.year,
      weekStartDate.month,
      weekStartDate.day,
    );
    return normalized.toIso8601String().split('T').first;
  }

  static String _buildStorageKey({
    required String uid,
    required DateTime weekStartDate,
  }) {
    return 'shopping_check_state_${uid}_${buildWeekKey(weekStartDate)}';
  }
}
