import '../../models/shopping_list_item.dart';

class ShoppingListLocalState {
  const ShoppingListLocalState({
    required this.completedItems,
    required this.separatePendingItems,
  });

  final List<ShoppingListItem> completedItems;
  final List<ShoppingListItem> separatePendingItems;

  ShoppingListLocalState copyWith({
    List<ShoppingListItem>? completedItems,
    List<ShoppingListItem>? separatePendingItems,
  }) {
    return ShoppingListLocalState(
      completedItems: completedItems ?? this.completedItems,
      separatePendingItems: separatePendingItems ?? this.separatePendingItems,
    );
  }

  static const empty = ShoppingListLocalState(
    completedItems: <ShoppingListItem>[],
    separatePendingItems: <ShoppingListItem>[],
  );
}

enum CompletedItemReopenMode { mergeIntoPending, reopenSeparately }

abstract interface class LocalShoppingListStateService {
  Future<ShoppingListLocalState> readState({
    required String uid,
    required DateTime weekStartDate,
  });

  Future<void> writeState({
    required String uid,
    required DateTime weekStartDate,
    required ShoppingListLocalState state,
  });

  Future<void> clearState({
    required String uid,
    required DateTime weekStartDate,
  });
}
