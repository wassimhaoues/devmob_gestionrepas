import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/meal_plan_entry.dart';
import '../models/meal_plan_failure.dart';
import '../models/meal_plan_week.dart';
import '../models/meal_slot_type.dart';
import '../models/recipe.dart';
import '../services/mealplan/meal_plan_exception.dart';
import '../services/mealplan/meal_plan_service.dart';

enum MealPlanProviderStatus { initial, loading, ready, mutating, error }

class MealPlanProvider extends ChangeNotifier {
  MealPlanProvider({required MealPlanService mealPlanService})
    : _mealPlanService = mealPlanService;

  final MealPlanService _mealPlanService;

  StreamSubscription<List<MealPlanEntry>>? _entriesSubscription;
  bool _disposed = false;

  String? _uid;
  MealPlanWeek _activeWeek = MealPlanWeek.fromAnchor(DateTime.now());
  List<MealPlanEntry> _entries = const <MealPlanEntry>[];
  MealPlanProviderStatus _status = MealPlanProviderStatus.initial;
  String? _errorMessage;
  MealPlanFailure? _failure;

  String? get uid => _uid;
  MealPlanWeek get activeWeek => _activeWeek;
  List<MealPlanEntry> get entries => _entries;
  MealPlanProviderStatus get status => _status;
  String? get errorMessage => _errorMessage;
  MealPlanFailure? get failure => _failure;
  bool get isLoading =>
      _status == MealPlanProviderStatus.loading ||
      _status == MealPlanProviderStatus.mutating;
  int get plannedMealCount => _entries.length;

  Future<void> startWatchingWeek({
    required String uid,
    DateTime? anchorDate,
  }) async {
    _uid = uid;
    _activeWeek = MealPlanWeek.fromAnchor(anchorDate ?? _activeWeek.startDate);
    _status = MealPlanProviderStatus.loading;
    _errorMessage = null;
    _failure = null;
    _safeNotify();

    await _entriesSubscription?.cancel();
    _entriesSubscription = _mealPlanService
        .watchEntries(
          uid: uid,
          startDate: _activeWeek.startDate,
          endDate: _activeWeek.endDate,
        )
        .listen(
          (entries) {
            _entries = entries;
            _status = MealPlanProviderStatus.ready;
            _errorMessage = null;
            _failure = null;
            _safeNotify();
          },
          onError: (Object error, StackTrace _) {
            _applyServiceError(error);
          },
        );
  }

  Future<void> refresh() async {
    final currentUid = _uid;
    if (currentUid == null) {
      return;
    }

    _status = MealPlanProviderStatus.loading;
    _errorMessage = null;
    _failure = null;
    _safeNotify();

    try {
      _entries = await _mealPlanService.fetchEntries(
        uid: currentUid,
        startDate: _activeWeek.startDate,
        endDate: _activeWeek.endDate,
      );
      _status = MealPlanProviderStatus.ready;
      _failure = null;
      _safeNotify();
    } catch (error) {
      _applyServiceError(error);
    }
  }

  Future<void> showPreviousWeek() async {
    final currentUid = _uid;
    _activeWeek = _activeWeek.previousWeek();
    if (currentUid == null) {
      _safeNotify();
      return;
    }

    await startWatchingWeek(uid: currentUid, anchorDate: _activeWeek.startDate);
  }

  Future<void> showNextWeek() async {
    final currentUid = _uid;
    _activeWeek = _activeWeek.nextWeek();
    if (currentUid == null) {
      _safeNotify();
      return;
    }

    await startWatchingWeek(uid: currentUid, anchorDate: _activeWeek.startDate);
  }

  Future<List<String>> assignRecipeToSlot({
    required DateTime date,
    required MealSlotType slotType,
    required Recipe recipe,
  }) async {
    final currentUid = _uid;
    if (currentUid == null) {
      return _applyMessageFailure(
        const MealPlanFailure(
          code: MealPlanFailureCode.unauthenticated,
          message: 'Authenticated user is required.',
        ),
      );
    }

    final recipeId = recipe.id.trim();
    final recipeTitle = recipe.title.trim();
    if (recipeId.isEmpty || recipeTitle.isEmpty) {
      return _applyMessageFailure(
        const MealPlanFailure(
          code: MealPlanFailureCode.invalidData,
          message: 'A valid recipe is required for meal planning.',
        ),
      );
    }

    _status = MealPlanProviderStatus.mutating;
    _errorMessage = null;
    _failure = null;
    _safeNotify();

    final normalizedDate = DateTime(date.year, date.month, date.day);
    final existingEntry = entryFor(date: normalizedDate, slotType: slotType);
    final now = DateTime.now();
    final entry = MealPlanEntry(
      id: MealPlanEntry.buildId(date: normalizedDate, slotType: slotType),
      ownerUid: currentUid,
      date: normalizedDate,
      slotType: slotType,
      recipeId: recipeId,
      recipeTitle: recipeTitle,
      recipeImageUrl: recipe.imageUrl,
      recipeCategory: recipe.category,
      createdAt: existingEntry?.createdAt ?? now,
      updatedAt: now,
    );

    try {
      await _mealPlanService.upsertEntry(uid: currentUid, entry: entry);
      _upsertEntry(entry);
      _status = MealPlanProviderStatus.ready;
      _failure = null;
      _safeNotify();
      return const <String>[];
    } catch (error) {
      _applyServiceError(error);
      return <String>[_errorMessage ?? 'Unable to save meal plan entry.'];
    }
  }

  Future<bool> removeEntryForSlot({
    required DateTime date,
    required MealSlotType slotType,
  }) async {
    final currentUid = _uid;
    if (currentUid == null) {
      _applyMessageFailure(
        const MealPlanFailure(
          code: MealPlanFailureCode.unauthenticated,
          message: 'Authenticated user is required.',
        ),
      );
      return false;
    }

    final entry = entryFor(date: date, slotType: slotType);
    if (entry == null) {
      return true;
    }

    _status = MealPlanProviderStatus.mutating;
    _errorMessage = null;
    _failure = null;
    _safeNotify();

    try {
      await _mealPlanService.deleteEntry(uid: currentUid, entryId: entry.id);
      _entries = _entries.where((item) => item.id != entry.id).toList();
      _status = MealPlanProviderStatus.ready;
      _failure = null;
      _safeNotify();
      return true;
    } catch (error) {
      _applyServiceError(error);
      return false;
    }
  }

  Future<void> stopWatching() async {
    await _entriesSubscription?.cancel();
    _entriesSubscription = null;
    _uid = null;
    _entries = const <MealPlanEntry>[];
    _status = MealPlanProviderStatus.initial;
    _errorMessage = null;
    _failure = null;
    _safeNotify();
  }

  MealPlanEntry? entryFor({
    required DateTime date,
    required MealSlotType slotType,
  }) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    for (final entry in _entries) {
      if (entry.slotType != slotType) {
        continue;
      }
      if (_isSameDate(entry.date, normalizedDate)) {
        return entry;
      }
    }
    return null;
  }

  List<MealPlanEntry> entriesForDay(DateTime date) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    return _entries
        .where((entry) => _isSameDate(entry.date, normalizedDate))
        .toList()
      ..sort((a, b) => a.slotType.index.compareTo(b.slotType.index));
  }

  void _upsertEntry(MealPlanEntry entry) {
    final updatedEntries = List<MealPlanEntry>.from(_entries);
    final index = updatedEntries.indexWhere((item) => item.id == entry.id);
    if (index >= 0) {
      updatedEntries[index] = entry;
    } else {
      updatedEntries.add(entry);
    }
    updatedEntries.sort((a, b) {
      final dateComparison = a.date.compareTo(b.date);
      if (dateComparison != 0) {
        return dateComparison;
      }
      return a.slotType.index.compareTo(b.slotType.index);
    });
    _entries = updatedEntries;
  }

  List<String> _applyMessageFailure(MealPlanFailure failure) {
    _status = MealPlanProviderStatus.error;
    _failure = failure;
    _errorMessage = failure.message;
    _safeNotify();
    return <String>[failure.message];
  }

  void _applyServiceError(Object error) {
    if (error is MealPlanException) {
      _status = MealPlanProviderStatus.error;
      _failure = error.failure;
      _errorMessage = error.failure.message;
    } else {
      _status = MealPlanProviderStatus.error;
      _failure = const MealPlanFailure(
        code: MealPlanFailureCode.unknown,
        message:
            'Something went wrong while processing the meal plan request.',
      );
      _errorMessage = _failure!.message;
    }
    _safeNotify();
  }

  bool _isSameDate(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  void _safeNotify() {
    if (_disposed) {
      return;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_entriesSubscription?.cancel());
    super.dispose();
  }
}
