abstract interface class LocalShoppingListStateService {
  Future<Set<String>> readCheckedItemIds({
    required String uid,
    required DateTime weekStartDate,
  });

  Future<void> writeCheckedItemIds({
    required String uid,
    required DateTime weekStartDate,
    required Set<String> itemIds,
  });

  Future<void> clearCheckedItemIds({
    required String uid,
    required DateTime weekStartDate,
  });
}
