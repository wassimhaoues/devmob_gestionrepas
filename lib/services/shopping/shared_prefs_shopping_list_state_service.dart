import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/shopping_list_item.dart';
import 'local_shopping_list_state_service.dart';

class SharedPrefsShoppingListStateService
    implements LocalShoppingListStateService {
  @override
  Future<void> clearState({
    required String uid,
    required DateTime weekStartDate,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(
      _buildStorageKey(uid: uid, weekStartDate: weekStartDate),
    );
  }

  @override
  Future<ShoppingListLocalState> readState({
    required String uid,
    required DateTime weekStartDate,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final rawValue = preferences.get(
      _buildStorageKey(uid: uid, weekStartDate: weekStartDate),
    );
    if (rawValue is List) {
      // Older app versions stored checklist state as a StringList.
      // Treat that legacy shape as empty instead of throwing on load.
      return ShoppingListLocalState.empty;
    }
    final encoded = rawValue as String?;
    if (encoded == null || encoded.trim().isEmpty) {
      return ShoppingListLocalState.empty;
    }

    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) {
        return ShoppingListLocalState.empty;
      }

      final data = decoded.map((key, value) => MapEntry(key.toString(), value));

      return ShoppingListLocalState(
        completedItems: _readItems(data['completedItems']),
        separatePendingItems: _readItems(data['separatePendingItems']),
      );
    } catch (_) {
      return ShoppingListLocalState.empty;
    }
  }

  @override
  Future<void> writeState({
    required String uid,
    required DateTime weekStartDate,
    required ShoppingListLocalState state,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final payload = jsonEncode(<String, dynamic>{
      'completedItems': state.completedItems
          .map((item) => item.toMap())
          .toList(),
      'separatePendingItems': state.separatePendingItems
          .map((item) => item.toMap())
          .toList(),
    });
    await preferences.setString(
      _buildStorageKey(uid: uid, weekStartDate: weekStartDate),
      payload,
    );
  }

  static List<ShoppingListItem> _readItems(Object? value) {
    if (value is! List) {
      return const <ShoppingListItem>[];
    }

    return value
        .whereType<Map>()
        .map(
          (item) => ShoppingListItem.fromMap(
            item.map(
              (key, dynamic itemValue) => MapEntry(key.toString(), itemValue),
            ),
          ),
        )
        .toList();
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
