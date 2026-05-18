import 'package:flutter/foundation.dart';

import '../models/meal_plan_entry.dart';
import '../models/meal_plan_week.dart';
import '../models/shopping_list.dart';
import '../models/shopping_list_item.dart';
import '../services/shopping/local_shopping_list_state_service.dart';
import '../services/shopping/shopping_list_generator_service.dart';

enum ShoppingListProviderStatus { initial, loading, ready, error }

class ShoppingListProvider extends ChangeNotifier {
  ShoppingListProvider({
    required ShoppingListGeneratorService generatorService,
    required LocalShoppingListStateService localStateService,
  }) : _generatorService = generatorService,
       _localStateService = localStateService;

  final ShoppingListGeneratorService _generatorService;
  final LocalShoppingListStateService _localStateService;

  bool _disposed = false;
  String? _uid;
  MealPlanWeek? _activeWeek;
  ShoppingList? _shoppingList;
  ShoppingListProviderStatus _status = ShoppingListProviderStatus.initial;
  String? _errorMessage;

  String? get uid => _uid;
  MealPlanWeek? get activeWeek => _activeWeek;
  ShoppingList? get shoppingList => _shoppingList;
  List<ShoppingListItem> get items =>
      _shoppingList?.items ?? const <ShoppingListItem>[];
  ShoppingListProviderStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == ShoppingListProviderStatus.loading;
  bool get hasItems => items.isNotEmpty;
  int get checkedItemCount => items.where((item) => item.isChecked).length;

  Future<void> loadForWeek({
    required String uid,
    required MealPlanWeek week,
    required List<MealPlanEntry> entries,
  }) async {
    _uid = uid;
    _activeWeek = week;
    _status = ShoppingListProviderStatus.loading;
    _errorMessage = null;
    _safeNotify();

    try {
      final generatedList = await _generatorService.generateForWeek(
        uid: uid,
        weekStartDate: week.startDate,
        entries: entries,
      );
      final checkedStates = await _localStateService.readCheckedItemStates(
        uid: uid,
        weekStartDate: week.startDate,
      );
      _shoppingList = generatedList.copyWith(
        items: generatedList.items
            .map(
              (item) => item.copyWith(
                isChecked: _shouldKeepCheckedState(
                  item: item,
                  checkedState: checkedStates[item.id],
                ),
              ),
            )
            .toList(),
      );
      _status = ShoppingListProviderStatus.ready;
      _safeNotify();
    } catch (error) {
      _shoppingList = null;
      _status = ShoppingListProviderStatus.error;
      _errorMessage = 'Unable to generate the shopping list.';
      _safeNotify();
    }
  }

  Future<void> refresh({
    required String uid,
    required MealPlanWeek week,
    required List<MealPlanEntry> entries,
  }) async {
    await loadForWeek(uid: uid, week: week, entries: entries);
  }

  Future<void> toggleItem(String itemId) async {
    final currentUid = _uid;
    final currentWeek = _activeWeek;
    final currentList = _shoppingList;
    if (currentUid == null || currentWeek == null || currentList == null) {
      return;
    }

    final updatedItems = currentList.items
        .map(
          (item) => item.id == itemId
              ? item.copyWith(isChecked: !item.isChecked)
              : item,
        )
        .toList();
    _shoppingList = currentList.copyWith(items: updatedItems);
    _errorMessage = null;
    _safeNotify();

    try {
      await _persistCheckedState(
        uid: currentUid,
        week: currentWeek,
        items: updatedItems,
      );
    } catch (error) {
      _errorMessage = 'Unable to save shopping checklist state.';
      _safeNotify();
    }
  }

  Future<void> clearCheckedItems() async {
    final currentUid = _uid;
    final currentWeek = _activeWeek;
    final currentList = _shoppingList;
    if (currentUid == null || currentWeek == null || currentList == null) {
      return;
    }

    final updatedItems = currentList.items
        .map((item) => item.copyWith(isChecked: false))
        .toList();
    _shoppingList = currentList.copyWith(items: updatedItems);
    _errorMessage = null;
    _safeNotify();

    try {
      await _localStateService.clearCheckedItemIds(
        uid: currentUid,
        weekStartDate: currentWeek.startDate,
      );
    } catch (error) {
      _errorMessage = 'Unable to save shopping checklist state.';
      _safeNotify();
    }
  }

  void reset() {
    _uid = null;
    _activeWeek = null;
    _shoppingList = null;
    _status = ShoppingListProviderStatus.initial;
    _errorMessage = null;
    _safeNotify();
  }

  Future<void> _persistCheckedState({
    required String uid,
    required MealPlanWeek week,
    required List<ShoppingListItem> items,
  }) async {
    final checkedStates = items
        .where((item) => item.isChecked)
        .map(
          (item) => MapEntry(
            item.id,
            CheckedShoppingItemState(
              itemId: item.id,
              totalQuantity: item.totalQuantity,
            ),
          ),
        );
    await _localStateService.writeCheckedItemStates(
      uid: uid,
      weekStartDate: week.startDate,
      itemStates: Map<String, CheckedShoppingItemState>.fromEntries(
        checkedStates,
      ),
    );
  }

  bool _shouldKeepCheckedState({
    required ShoppingListItem item,
    required CheckedShoppingItemState? checkedState,
  }) {
    if (checkedState == null) {
      return false;
    }

    return checkedState.totalQuantity == item.totalQuantity;
  }

  void _safeNotify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
