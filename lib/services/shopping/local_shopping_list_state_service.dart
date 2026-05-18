class CheckedShoppingItemState {
  const CheckedShoppingItemState({
    required this.itemId,
    required this.totalQuantity,
  });

  final String itemId;
  final double totalQuantity;
}

abstract interface class LocalShoppingListStateService {
  Future<Map<String, CheckedShoppingItemState>> readCheckedItemStates({
    required String uid,
    required DateTime weekStartDate,
  });

  Future<void> writeCheckedItemStates({
    required String uid,
    required DateTime weekStartDate,
    required Map<String, CheckedShoppingItemState> itemStates,
  });

  Future<void> clearCheckedItemIds({
    required String uid,
    required DateTime weekStartDate,
  });
}
