# Meal Plan Module Plan

## 1. Why This Module Exists

The PDF requires weekly meal planning as a core feature, and it is currently
missing from the repo.

This module is the heart of the app after recipes:
- it gives users a weekly calendar
- it lets them assign recipes to meal slots
- it becomes the source for shopping list generation

## 2. Current Repo Status

Already present:
- authenticated user isolation
- recipe catalog with category support and favorites
- dashboard entry point where meal planning can be attached

Missing completely:
- meal plan models
- meal plan services
- meal plan provider
- calendar views
- assignment flow for recipes to slots
- storage schema and rules for user meal plans

## 3. Scope

In scope:
- weekly meal calendar
- day-by-day meal slots
- breakfast, lunch, dinner assignment
- selecting an existing recipe for a slot
- updating and removing slot assignments
- user-scoped backend persistence
- enough structure for shopping list generation to read planned meals

Out of scope:
- nutritional analytics
- cost forecasting
- notifications
- multi-user collaboration

Optional, not required for first delivery:
- drag and drop slot organization
- alternate calendar packages if `table_calendar` is not sufficient

## 4. Functional Requirements From the PDF

The module must support:
- weekly calendar
- for each day:
  - breakfast
  - lunch
  - dinner
- assignment of recipes to each slot

This is a required feature, not a bonus.

## 5. Domain Model Proposal

Planned model artifacts:
- `MealPlanWeek`
- `MealPlanEntry`
- `MealSlotType` enum
- optional small query/filter value objects

Recommended `MealSlotType` values:
- `breakfast`
- `lunch`
- `dinner`

Recommended `MealPlanEntry` fields:
- `id`
- `ownerUid`
- `date`
- `slotType`
- `recipeId`
- denormalized `recipeTitle`
- optional `recipeImageUrl`
- optional `recipeCategory`
- `createdAt`
- `updatedAt`

Why denormalize a small amount:
- faster calendar rendering
- fewer extra fetches
- smoother shopping-list generation

## 6. Storage Strategy

Recommended path:
- `users/{uid}/mealPlanEntries/{entryId}`

Reasoning:
- simple CRUD
- easy query by date range
- easy aggregate for one week
- easy delete/update per slot

Recommended indexes:
- `date` ascending
- composite index for:
  - `date`
  - `slotType`

## 7. Validation Strategy

Rules:
- `date` is required
- `slotType` must match enum
- `recipeId` is required for a planned slot
- only one recipe per user/date/slotType at a time

Provider/service rule:
- assigning a recipe to an already occupied slot should overwrite by explicit
  update flow, not silently create duplicates

## 8. Provider Responsibilities

Planned provider:
- `MealPlanProvider`

Responsibilities:
- load the active week
- expose per-day/per-slot structures to the UI
- assign recipe to slot
- replace recipe in slot
- remove assignment
- shift active week backward/forward
- expose loading/error states

State slices:
- active week start/end
- current entries
- selected day
- selected slot
- status and failure

## 9. Service Responsibilities

Planned service:
- `MealPlanService`
- `FirestoreMealPlanService`

Responsibilities:
- fetch meal-plan entries for a date range
- create or upsert a slot assignment
- delete a slot assignment
- map backend exceptions into module-level failures

## 10. UI Structure

Planned views:
- `MealCalendarPage`
- `AssignRecipePage`
- maybe a `MealSlotPickerSheet` or dialog

The calendar page should provide:
- week navigation
- a compact weekly overview
- day sections with breakfast/lunch/dinner rows
- clear actions to assign, replace, or remove a recipe

The assignment flow should let the user:
- search/select from existing recipes
- optionally favor favorites first
- confirm assignment to the chosen slot

## 11. Integration With Recipes

This module depends on recipes being usable as source content.

Integration rules:
- meal plan stores `recipeId` as the source of truth
- small denormalized display fields may be stored for performance
- if a recipe is deleted, planned entries referencing it need a defined policy

Recommended first policy:
- keep the entry but mark it as unavailable until the user replaces it

Alternative simpler policy:
- delete related meal plan entries when recipe is deleted

Choose one policy before implementation and apply it consistently.

## 12. Shopping List Dependency

Meal planning is the upstream source for shopping list generation.

So this module must make it easy to:
- fetch all planned recipes for a selected week
- inspect their ingredients
- detect duplicates across planned meals

## 13. Testing Strategy

Required tests:
- model serialization tests
- provider week-loading tests
- assign/replace/remove tests
- duplicate-slot prevention tests
- service mapping tests
- widget tests for calendar interaction basics

## 14. Acceptance Criteria

This module is complete when:
- a user can open a week view
- each day exposes breakfast, lunch, and dinner slots
- recipes can be assigned, replaced, and removed
- assignments persist per authenticated user
- the week reloads correctly after app restart
- the shopping list module can consume the meal plan data

## 15. Implementation Roadmap

1. Create meal-plan models and failure types.
2. Add meal-plan Firestore schema and security rules.
3. Implement `MealPlanService`.
4. Implement `MealPlanProvider`.
5. Build `MealCalendarPage`.
6. Build recipe assignment flow for a slot.
7. Wire dashboard/app shell entry points.
8. Add tests and empty/error states.

## 16. Branching Rule

Any future branch created for this work must start with:
- `feature/`

