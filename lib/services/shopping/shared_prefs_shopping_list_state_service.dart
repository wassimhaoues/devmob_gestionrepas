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
  Future<Map<String, CheckedShoppingItemState>> readCheckedItemStates({
    required String uid,
    required DateTime weekStartDate,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final values =
        preferences.getStringList(
          _buildStorageKey(uid: uid, weekStartDate: weekStartDate),
        ) ??
        const <String>[];
    final itemStates = <String, CheckedShoppingItemState>{};
    for (final value in values) {
      final parsed = _parseStoredValue(value);
      if (parsed == null) {
        continue;
      }
      itemStates[parsed.itemId] = parsed;
    }
    return itemStates;
  }

  @override
  Future<void> writeCheckedItemStates({
    required String uid,
    required DateTime weekStartDate,
    required Map<String, CheckedShoppingItemState> itemStates,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final values = itemStates.values.map(_serializeState).toList()..sort();
    await preferences.setStringList(
      _buildStorageKey(uid: uid, weekStartDate: weekStartDate),
      values,
    );
  }

  static String _serializeState(CheckedShoppingItemState state) {
    return '${state.itemId}|${state.totalQuantity}';
  }

  static CheckedShoppingItemState? _parseStoredValue(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return null;
    }

    final separatorIndex = normalized.lastIndexOf('|');
    if (separatorIndex <= 0 || separatorIndex == normalized.length - 1) {
      return CheckedShoppingItemState(itemId: normalized, totalQuantity: 0);
    }

    final itemId = normalized.substring(0, separatorIndex).trim();
    final quantityValue = normalized.substring(separatorIndex + 1).trim();
    final totalQuantity = double.tryParse(quantityValue);
    if (itemId.isEmpty || totalQuantity == null) {
      return null;
    }

    return CheckedShoppingItemState(
      itemId: itemId,
      totalQuantity: totalQuantity,
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
