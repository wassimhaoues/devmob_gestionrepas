# Shopping List Module Plan

## 1. Why This Module Exists

The PDF explicitly requires automatic shopping-list generation from planned
meals. This module is still fully missing from the repo.

It is the downstream feature that proves the recipes and meal-planning modules
work together as one product.

## 2. Current Repo Status

Already present:
- recipes with normalized ingredients
- deterministic ingredient canonical names
- user-scoped Firestore structure

Still missing:
- shopping list domain models
- shopping list generation logic
- aggregation and deduplication rules
- shopping list screens
- persistence strategy for checklist state

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
- planned meal entries for a selected week

Generation pipeline:
1. load the selected week of meal-plan entries
2. resolve their linked recipes
3. flatten all ingredients from those recipes
4. normalize by persisted `canonicalName`
5. merge compatible items
6. produce a user-facing shopping list model

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
- generate list content from backend meal-plan data
- persist checklist state locally with `shared_preferences` or `hive`

Why:
- checked/unchecked state is UI-centric
- faster to ship for a single-user school project
- avoids unnecessary backend complexity

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

This module depends directly on meal-planning data.

Required integration:
- selected week in shopping list should align with selected week in meal plan
- shopping list should regenerate when planned meals change
- empty meal plan should produce a friendly empty shopping state

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

