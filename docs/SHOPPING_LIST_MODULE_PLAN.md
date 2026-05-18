# Shopping List Module Plan

## Progress Tracker

Current phase:
- Phase 3: completed

Completed in this phase:
- Phase 1: foundation layer completed
- added shopping domain models
- added generation and local checked-state services
- added `ShoppingListProvider` and app-level dependency wiring
- added `shared_preferences` dependency
- Phase 2: shopping page integration completed
- replaced the static placeholder with a real weekly shopping list page
- synced shopping generation with `MealPlanProvider.activeWeek` and `entries`
- added checklist UI, refresh flow, week navigation, and empty/error states
- reset shopping state on sign-out
- added widget coverage for empty and generated shopping states
- Phase 3: hardening and verification completed
- added `shared_preferences` service tests for read, write, clear, and isolation
- added provider tests for clear, reset, generation failure, and persistence failure
- hardened checklist persistence so local-save failures do not crash the UI
- verified the full repository test suite passes with the shopping module integrated

Still missing:
- nothing for this module phase

Implementation phases:
- [x] Phase 1: foundation layer
- [x] Phase 2: real shopping list page and meal-plan integration
- [x] Phase 3: tests, hardening, and polish

## 1. Why This Module Exists

The PDF explicitly requires automatic shopping-list generation from planned
meals. It is the downstream feature that proves the recipes and meal-planning
modules work together as one product.

## 2. Current Repo Status

Already present:
- `Recipe` model with a typed `List<Ingredient> ingredients` field
- `Ingredient` model with `displayName`, `canonicalName`, `quantity`, `unit`
  — all four fields the aggregation logic needs are already normalized at
  recipe creation time by `IngredientNormalizer`
- `RecipeService.fetchRecipeById(uid, recipeId)` — resolves a single recipe
  by ID, which is the key call for the generation pipeline
- `MealPlanEntry` model carrying `recipeId` as the source-of-truth link to a
  recipe
- `MealPlanService.fetchEntries(uid, startDate, endDate)` — fetches all
  planned entries for a date range
- `MealPlanProvider` with `activeWeek` (`MealPlanWeek`) and `entries`
  (`List<MealPlanEntry>`) — week context and planned entries are live and
  ready to consume
- `MealPlanWeek` model with `startDate` and `endDate` — week boundaries
  already defined
- `ShoppingListPage` stub at `lib/views/shopping/shopping_list_page.dart`
  with route constant `shoppingListRoute` — page shell and route slot exist
- user-scoped Firestore structure and auth isolation

Still missing:
- no known gaps inside the planned shopping-list scope

## 3. Scope

In scope:
- generate a shopping list from planned meals
- merge duplicated ingredients
- group shopping items clearly for the user
- allow checklist behavior for purchased items
- support week-based shopping context
- persist checklist state locally and/or remotely as needed

Out of scope:
- price comparison
- supermarket integrations
- barcode scanning
- advanced pantry/inventory management

## 4. Functional Requirements From the PDF

Required behavior:
- generate a shopping list automatically from ingredients of planned menus

Strong implied requirements for usability:
- the list should be readable
- duplicate ingredients should not appear as noisy repeated rows
- the user should be able to use the list during the week

## 5. Generation Strategy

Primary source:
- planned meal entries for the selected week from `MealPlanProvider.entries`
  (or via `MealPlanService.fetchEntries` if triggered independently)

Generation pipeline:
1. read `MealPlanProvider.entries` for the active week (already live in memory)
2. collect the unique `recipeId` values from those entries
3. resolve each recipe with `RecipeService.fetchRecipeById(uid, recipeId)`
   — duplicates are deduplicated by ID before fetching
4. flatten `Recipe.ingredients` from all resolved recipes into a single list
5. `Ingredient.canonicalName` is already normalized (written by
   `IngredientNormalizer` at recipe creation) — no further normalization needed
6. merge by `(canonicalName, unit)` and sum `quantity`
7. produce `List<ShoppingListItem>` for the provider to expose

## 6. Aggregation Rules

Recommended first version:
- merge ingredients only when both match:
  - `canonicalName`
  - `unit`

Example:
- `2 tomato`
- `3 tomatoes`
- both become `5 tomato` if units match

Do not attempt in first version:
- converting `kg` to `g`
- converting `cup` to `ml`
- smart substitutions

If units differ:
- keep separate rows even if canonical names match

## 7. Domain Model Proposal

Planned model artifacts:
- `ShoppingList`
- `ShoppingListItem`
- optional `ShoppingListSourceRecipe`

Recommended `ShoppingListItem` fields:
- `id`
- `canonicalName`
- `displayName`
- `totalQuantity`
- `unit`
- `isChecked`
- `sourceRecipeIds`

Potential `ShoppingList` fields:
- `ownerUid`
- `weekStartDate`
- `generatedAt`
- `items`

## 8. Persistence Strategy

The PDF mentions local persistence as an interesting technical aspect.

Recommended first approach:
- generate list content from backend meal-plan data (recipes + entries already
  in Firestore)
- persist only the checked/unchecked state locally with `shared_preferences`

Why:
- checked state is UI-centric and user-specific
- faster to ship for a single-user school project
- avoids unnecessary backend complexity for ephemeral UI state

Action required before implementation:
- add `shared_preferences` to `pubspec.yaml` (not present yet)

Potential local persistence key:
- `shopping_check_state_{uid}_{weekStartIso}`

## 9. Service Responsibilities

Planned services:
- `ShoppingListService`
- optional `LocalShoppingListStateService`

Responsibilities:
- load planned recipes for a week
- aggregate ingredients
- output list items
- persist and restore local checked state

## 10. Provider Responsibilities

Planned provider:
- `ShoppingListProvider`

Responsibilities:
- load selected week list
- expose grouped/flat items to the UI
- toggle checked state
- refresh after meal-plan changes
- manage loading/error/empty states

## 11. UI Structure

Planned views:
- `ShoppingListPage`

Core page features:
- week selector or current-week focus
- generated timestamp or “based on this week’s plan”
- checklist rows
- empty state when no meals are planned
- refresh/regenerate action

Helpful extras if time allows:
- grouping by category
- “uncheck all” or “clear checks” action
- copy/share exported text

## 12. Integration With Meal Planning

This module depends directly on meal-planning data. All required hooks are
already in place — no changes to the meal plan module are needed.

Concrete integration points:
- `MealPlanProvider.activeWeek` — use its `startDate`/`endDate` as the
  generation window so the shopping list always reflects the same week the
  user is viewing in the planner
- `MealPlanProvider.entries` — the live list of `MealPlanEntry` objects
  (each carrying `recipeId`) is the direct input to the generation pipeline
- `RecipeService.fetchRecipeById` — resolves each entry's `recipeId` into
  a full `Recipe` with its `ingredients` list
- `ShoppingListPage` stub already registered in the app shell with route
  `shoppingListRoute` — no routing changes needed

Required behavior:
- shopping list week should follow `MealPlanProvider.activeWeek`
- list should regenerate when the user refreshes or the week changes
- empty meal plan should produce a clear empty state (no entries → no items)

## 13. Testing Strategy

Required tests:
- aggregation logic tests
- duplicate merge tests
- mixed-unit separation tests
- checked-state persistence tests
- provider loading tests
- widget tests for empty/list/checked states

## 14. Acceptance Criteria

This module is complete when:
- a user can open the shopping list for a week
- the list is generated from planned meal recipes
- duplicate ingredients merge predictably
- checked state persists for the same user/week
- empty plans produce a clear empty state

## 15. Implementation Roadmap

1. Define shopping-list models.
2. Implement aggregation rules from recipe ingredients.
3. Add local checklist persistence.
4. Implement `ShoppingListProvider`.
5. Build `ShoppingListPage`.
6. Integrate with meal-plan week selection.
7. Add tests and empty/error states.

## 16. Branching Rule

Any future branch created for this work must start with:
- `feature/`
