import 'dart:async';

import 'package:devmob_gestionrepas/models/meal_plan_entry.dart';
import 'package:devmob_gestionrepas/models/meal_plan_failure.dart';
import 'package:devmob_gestionrepas/models/meal_slot_type.dart';
import 'package:devmob_gestionrepas/models/recipe.dart';
import 'package:devmob_gestionrepas/models/recipe_category.dart';
import 'package:devmob_gestionrepas/providers/meal_plan_provider.dart';
import 'package:devmob_gestionrepas/services/mealplan/meal_plan_exception.dart';
import 'package:devmob_gestionrepas/services/mealplan/meal_plan_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _FakeMealPlanService mealPlanService;

  setUp(() {
    mealPlanService = _FakeMealPlanService();
  });

  tearDown(() async {
    await mealPlanService.dispose();
  });

  MealPlanProvider buildProvider() {
    return MealPlanProvider(mealPlanService: mealPlanService);
  }

  test('startWatchingWeek listens to week entries and updates state', () async {
    final provider = buildProvider();

    await provider.startWatchingWeek(
      uid: 'user-1',
      anchorDate: DateTime(2026, 5, 20),
    );
    expect(provider.status, MealPlanProviderStatus.loading);

    mealPlanService.emitEntries(<MealPlanEntry>[
      _sampleEntry(date: DateTime(2026, 5, 18)),
    ]);
    await _flushAsync();

    expect(provider.status, MealPlanProviderStatus.ready);
    expect(provider.entries, hasLength(1));
    expect(provider.activeWeek.startDate, DateTime(2026, 5, 18));
    provider.dispose();
  });

  test('showNextWeek restarts watcher for the following week', () async {
    final provider = buildProvider();

    await provider.startWatchingWeek(
      uid: 'user-1',
      anchorDate: DateTime(2026, 5, 20),
    );
    await provider.showNextWeek();

    expect(provider.activeWeek.startDate, DateTime(2026, 5, 25));
    expect(mealPlanService.lastWatchStartDate, DateTime(2026, 5, 25));
    provider.dispose();
  });

  test('assignRecipeToSlot upserts a denormalized meal plan entry', () async {
    final provider = buildProvider();
    await provider.startWatchingWeek(
      uid: 'user-1',
      anchorDate: DateTime(2026, 5, 20),
    );

    final errors = await provider.assignRecipeToSlot(
      date: DateTime(2026, 5, 19),
      slotType: MealSlotType.lunch,
      recipe: _sampleRecipe(id: 'recipe-1'),
    );

    expect(errors, isEmpty);
    expect(mealPlanService.lastUpsertedEntry, isNotNull);
    expect(mealPlanService.lastUpsertedEntry!.slotType, MealSlotType.lunch);
    expect(mealPlanService.lastUpsertedEntry!.recipeTitle, 'Tomato Soup');
    expect(provider.plannedMealCount, 1);
    provider.dispose();
  });

  test('removeEntryForSlot deletes existing slot assignment', () async {
    final provider = buildProvider();
    await provider.startWatchingWeek(
      uid: 'user-1',
      anchorDate: DateTime(2026, 5, 20),
    );
    mealPlanService.emitEntries(<MealPlanEntry>[
      _sampleEntry(date: DateTime(2026, 5, 19)),
    ]);
    await _flushAsync();

    final result = await provider.removeEntryForSlot(
      date: DateTime(2026, 5, 19),
      slotType: MealSlotType.breakfast,
    );

    expect(result, isTrue);
    expect(
      mealPlanService.lastDeletedEntryId,
      MealPlanEntry.buildId(
        date: DateTime(2026, 5, 19),
        slotType: MealSlotType.breakfast,
        recipeId: 'recipe-1',
      ),
    );
    expect(provider.entries, isEmpty);
    provider.dispose();
  });

  test('assignRecipeToSlot surfaces mapped service failures', () async {
    final provider = buildProvider();
    await provider.startWatchingWeek(
      uid: 'user-1',
      anchorDate: DateTime(2026, 5, 20),
    );
    mealPlanService.upsertError = const MealPlanException(
      MealPlanFailure(
        code: MealPlanFailureCode.permissionDenied,
        message: 'You do not have permission to access this meal plan.',
      ),
    );

    final errors = await provider.assignRecipeToSlot(
      date: DateTime(2026, 5, 19),
      slotType: MealSlotType.dinner,
      recipe: _sampleRecipe(id: 'recipe-1'),
    );

    expect(errors, isNotEmpty);
    expect(provider.status, MealPlanProviderStatus.error);
    expect(
      provider.errorMessage,
      'You do not have permission to access this meal plan.',
    );
    provider.dispose();
  });
}

Future<void> _flushAsync() async {
  await Future<void>.delayed(Duration.zero);
}

MealPlanEntry _sampleEntry({
  required DateTime date,
  MealSlotType slotType = MealSlotType.breakfast,
}) {
  return MealPlanEntry(
    id: MealPlanEntry.buildId(date: date, slotType: slotType, recipeId: 'recipe-1'),
    ownerUid: 'user-1',
    date: date,
    slotType: slotType,
    recipeId: 'recipe-1',
    recipeTitle: 'Tomato Soup',
    recipeImageUrl: null,
    recipeCategory: RecipeCategory.lunch,
    createdAt: DateTime(2026, 5, 1),
    updatedAt: DateTime(2026, 5, 2),
  );
}

Recipe _sampleRecipe({required String id}) {
  return Recipe(
    id: id,
    ownerUid: 'user-1',
    title: 'Tomato Soup',
    description: 'Simple soup',
    category: RecipeCategory.lunch,
    isFavorite: false,
    ingredients: const [],
    steps: const [],
    createdAt: DateTime(2026, 5, 1),
    updatedAt: DateTime(2026, 5, 2),
  );
}

class _FakeMealPlanService implements MealPlanService {
  final StreamController<List<MealPlanEntry>> _controller =
      StreamController<List<MealPlanEntry>>.broadcast();

  DateTime? lastWatchStartDate;
  MealPlanEntry? lastUpsertedEntry;
  String? lastDeletedEntryId;
  MealPlanException? upsertError;

  void emitEntries(List<MealPlanEntry> entries) {
    _controller.add(entries);
  }

  Future<void> dispose() async {
    await _controller.close();
  }

  @override
  Future<void> deleteEntry({
    required String uid,
    required String entryId,
  }) async {
    lastDeletedEntryId = entryId;
  }

  @override
  Future<List<MealPlanEntry>> fetchEntries({
    required String uid,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    lastWatchStartDate = startDate;
    return const <MealPlanEntry>[];
  }

  @override
  Future<bool> hasEntriesForRecipe({
    required String uid,
    required String recipeId,
  }) async {
    return false;
  }

  @override
  Future<void> upsertEntry({
    required String uid,
    required MealPlanEntry entry,
  }) async {
    if (upsertError != null) {
      throw upsertError!;
    }
    lastUpsertedEntry = entry;
  }

  @override
  Stream<List<MealPlanEntry>> watchEntries({
    required String uid,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    lastWatchStartDate = startDate;
    return _controller.stream;
  }
}
