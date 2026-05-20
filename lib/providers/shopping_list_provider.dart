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
  ShoppingList? _generatedShoppingList;
  ShoppingListLocalState _localState = ShoppingListLocalState.empty;
  List<ShoppingListItem> _pendingItems = const <ShoppingListItem>[];
  List<ShoppingListItem> _completedItems = const <ShoppingListItem>[];
  ShoppingListProviderStatus _status = ShoppingListProviderStatus.initial;
  String? _errorMessage;

  String? get uid => _uid;
  MealPlanWeek? get activeWeek => _activeWeek;
  ShoppingList? get shoppingList => _generatedShoppingList;
  List<ShoppingListItem> get items => <ShoppingListItem>[
    ..._pendingItems,
    ..._completedItems,
  ];
  List<ShoppingListItem> get pendingItems => _pendingItems;
  List<ShoppingListItem> get completedItems => _completedItems;
  ShoppingListProviderStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == ShoppingListProviderStatus.loading;
  bool get hasItems => items.isNotEmpty;
  int get checkedItemCount => _completedItems.length;

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
      _generatedShoppingList = await _generatorService.generateForWeek(
        uid: uid,
        weekStartDate: week.startDate,
        entries: entries,
      );
      _localState = await _localStateService.readState(
        uid: uid,
        weekStartDate: week.startDate,
      );
      _rebuildVisibleItems();
      _status = ShoppingListProviderStatus.ready;
      _safeNotify();
    } catch (error, stackTrace) {
      debugPrint(
        'ShoppingListProvider.loadForWeek failed: $error\n$stackTrace',
      );
      _generatedShoppingList = null;
      _localState = ShoppingListLocalState.empty;
      _pendingItems = const <ShoppingListItem>[];
      _completedItems = const <ShoppingListItem>[];
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

  Future<void> completePendingItem(String itemId) async {
    final currentUid = _uid;
    final currentWeek = _activeWeek;
    if (currentUid == null || currentWeek == null) {
      return;
    }

    final pendingItem = _pendingItems.cast<ShoppingListItem?>().firstWhere(
      (item) => item?.id == itemId,
      orElse: () => null,
    );
    if (pendingItem == null) {
      return;
    }

    final now = DateTime.now();
    final completedItem = pendingItem.copyWith(
      id: ShoppingListItem.buildBatchId(
        ingredientKey: pendingItem.ingredientKey,
        status: ShoppingListItemStatus.completed,
        origin: pendingItem.origin,
        timestamp: now,
      ),
      status: ShoppingListItemStatus.completed,
      isNewBatch: false,
      completedAt: now,
    );

    final separatePendingItems = List<ShoppingListItem>.from(
      _localState.separatePendingItems,
    );
    if (!pendingItem.isGenerated) {
      separatePendingItems.removeWhere((item) => item.id == pendingItem.id);
    }

    _localState = _localState.copyWith(
      completedItems: <ShoppingListItem>[
        ..._localState.completedItems,
        completedItem,
      ],
      separatePendingItems: separatePendingItems,
    );

    await _persistAndRebuild(uid: currentUid, week: currentWeek);
  }

  Future<void> reopenCompletedItem({
    required String itemId,
    required CompletedItemReopenMode mode,
  }) async {
    final currentUid = _uid;
    final currentWeek = _activeWeek;
    if (currentUid == null || currentWeek == null) {
      return;
    }

    final completedItem = _completedItems.cast<ShoppingListItem?>().firstWhere(
      (item) => item?.id == itemId,
      orElse: () => null,
    );
    if (completedItem == null) {
      return;
    }

    final updatedCompletedItems = List<ShoppingListItem>.from(
      _localState.completedItems,
    )..removeWhere((item) => item.id == itemId);

    List<ShoppingListItem> separatePendingItems = List<ShoppingListItem>.from(
      _localState.separatePendingItems,
    );

    if (mode == CompletedItemReopenMode.reopenSeparately) {
      final reopenedItem = completedItem.copyWith(
        id: ShoppingListItem.buildBatchId(
          ingredientKey: completedItem.ingredientKey,
          status: ShoppingListItemStatus.pending,
          origin: ShoppingListItemOrigin.reopened,
          timestamp: DateTime.now(),
        ),
        status: ShoppingListItemStatus.pending,
        origin: ShoppingListItemOrigin.reopened,
        isNewBatch: true,
        completedAt: null,
      );
      separatePendingItems = <ShoppingListItem>[
        ...separatePendingItems,
        reopenedItem,
      ];
    }

    _localState = _localState.copyWith(
      completedItems: updatedCompletedItems,
      separatePendingItems: separatePendingItems,
    );

    await _persistAndRebuild(uid: currentUid, week: currentWeek);
  }

  Future<void> clearCheckedItems() async {
    final currentUid = _uid;
    final currentWeek = _activeWeek;
    if (currentUid == null || currentWeek == null) {
      return;
    }

    _localState = _localState.copyWith(
      completedItems: const <ShoppingListItem>[],
    );
    await _persistAndRebuild(uid: currentUid, week: currentWeek);
  }

  void reset() {
    _uid = null;
    _activeWeek = null;
    _generatedShoppingList = null;
    _localState = ShoppingListLocalState.empty;
    _pendingItems = const <ShoppingListItem>[];
    _completedItems = const <ShoppingListItem>[];
    _status = ShoppingListProviderStatus.initial;
    _errorMessage = null;
    _safeNotify();
  }

  Future<void> _persistAndRebuild({
    required String uid,
    required MealPlanWeek week,
  }) async {
    _errorMessage = null;
    _rebuildVisibleItems();
    _safeNotify();

    try {
      await _localStateService.writeState(
        uid: uid,
        weekStartDate: week.startDate,
        state: _localState,
      );
    } catch (error) {
      _errorMessage = 'Unable to save shopping checklist state.';
      _safeNotify();
    }
  }

  void _rebuildVisibleItems() {
    final generatedItems =
        _generatedShoppingList?.items ?? const <ShoppingListItem>[];
    final completedItems =
        List<ShoppingListItem>.from(_localState.completedItems)..sort((a, b) {
          final aTime = a.completedAt ?? a.createdAt;
          final bTime = b.completedAt ?? b.createdAt;
          return bTime.compareTo(aTime);
        });
    final separatePendingItems = List<ShoppingListItem>.from(
      _localState.separatePendingItems,
    )..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final completedQuantityByKey = <String, double>{};
    for (final item in completedItems) {
      completedQuantityByKey.update(
        item.ingredientKey,
        (value) => value + item.totalQuantity,
        ifAbsent: () => item.totalQuantity,
      );
    }

    final separatePendingQuantityByKey = <String, double>{};
    for (final item in separatePendingItems) {
      separatePendingQuantityByKey.update(
        item.ingredientKey,
        (value) => value + item.totalQuantity,
        ifAbsent: () => item.totalQuantity,
      );
    }

    final generatedPendingItems = <ShoppingListItem>[];
    for (final item in generatedItems) {
      final completedQuantity = completedQuantityByKey[item.ingredientKey] ?? 0;
      final separatePendingQuantity =
          separatePendingQuantityByKey[item.ingredientKey] ?? 0;
      final remainingQuantity =
          item.totalQuantity - completedQuantity - separatePendingQuantity;
      if (remainingQuantity <= 0) {
        continue;
      }

      generatedPendingItems.add(
        item.copyWith(
          id: item.ingredientKey,
          ingredientKey: item.ingredientKey,
          totalQuantity: remainingQuantity,
          status: ShoppingListItemStatus.pending,
          origin: ShoppingListItemOrigin.generated,
          isNewBatch: completedQuantity > 0,
          createdAt: _generatedShoppingList?.generatedAt ?? DateTime.now(),
          completedAt: null,
        ),
      );
    }

    generatedPendingItems.sort(
      (a, b) =>
          a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
    );

    _pendingItems = <ShoppingListItem>[
      ...generatedPendingItems,
      ...separatePendingItems,
    ];
    _completedItems = completedItems;
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
