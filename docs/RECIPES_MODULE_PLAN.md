# Recipes Module Plan

## 1. Scope and Constraints

This document locks the architecture for the **Recipes module only**.

In scope:
- Add recipe
- Read recipes (authenticated user only)
- Update recipe
- Delete recipe
- Category assignment (`breakfast`, `lunch`, `dinner`, `dessert`)
- Embedded ingredients with canonical normalization
- Preparation steps
- Optional image metadata fields
- Favorite toggle (`isFavorite: bool`)

Out of scope:
- Meal planning
- Shopping list
- Advanced favorites features beyond boolean
- Spelling correction / fuzzy ingredient matching
- Global ingredient registry
- Ingredient subcollections

Data ownership:
- Every recipe is stored under: `users/{uid}/recipes/{recipeId}`.

## 2. High-Level Module Overview

The Recipes module is a user-scoped CRUD context with deterministic ingredient normalization.

Core principles:
- User isolation by `uid` path scoping.
- Recipe document is the aggregate root.
- Ingredients and steps are embedded arrays inside the recipe document.
- Canonical normalization is stable and local to each ingredient.
- Keep design simple and incremental.

## 3. Layer Responsibilities

### Models
Responsibilities:
- Represent immutable recipe domain entities.
- Define serialization/deserialization contracts.
- Enforce lightweight domain invariants (required fields, enum mapping).

Must not:
- Call Firebase APIs.
- Depend on widgets or `BuildContext`.

Planned model artifacts:
- `Recipe`
- `Ingredient`
- `RecipeStep`
- `RecipeCategory` (enum)
- Optional small failure/result value objects for recipe operations.

### Services
Responsibilities:
- Provide user-scoped recipe data operations.
- Hide backend details from providers.
- Map backend exceptions into module-level failures.

Must not:
- Own UI state.
- Perform screen navigation.

### Providers
Responsibilities:
- Hold list/detail/edit state for recipes.
- Execute use cases (create, update, delete, favorite toggle).
- Trigger normalization + validation before mutation requests.
- Surface loading/error/success states to views.

Must not:
- Contain widget trees.
- Execute raw query logic directly (delegate to services).

### Views
Responsibilities:
- Collect user input.
- Render provider state.
- Trigger provider actions.

Must not:
- Make backend calls directly.
- Reimplement normalization rules.

## 4. Firestore Schema (Structure Only)

Collection path:
- `users/{uid}/recipes/{recipeId}`

Recipe document fields:
- `title`: string
- `description`: string
- `category`: string enum (`breakfast`, `lunch`, `dinner`, `dessert`)
- `isFavorite`: bool
- `ingredients`: array of ingredient maps
- `steps`: array of step maps
- `imageUrl`: string or null
- `imageStoragePath`: string or null
- `createdAt`: timestamp
- `updatedAt`: timestamp

Ingredient map fields (embedded):
- `displayName`: string
- `canonicalName`: string
- `quantity`: number
- `unit`: string

Step map fields (embedded):
- `order`: int
- `text`: string

Notes:
- Ingredients are embedded; no `ingredients` subcollection.
- `canonicalName` is persisted at write time for deterministic downstream usage.
- UI can still display localized labels (for example French) mapped from the
  English enum values.

## 5. Ingredient Canonical Normalization Strategy

Normalization applies to ingredient name input and outputs `canonicalName`.

Pipeline:
1. Trim surrounding whitespace.
2. Collapse internal repeated whitespace into a single space.
3. Convert to lowercase.
4. Remove accents/diacritics.
5. Optional simple plural reduction:
   - If token length > 4 and ends with `es`, remove `es`.
   - Else if token length > 3 and ends with `s`, remove `s`.

Important boundaries:
- `displayName` remains human-readable and close to user input.
- `canonicalName` is machine-friendly and not directly edited by user.
- No spelling correction.
- No fuzzy matching.
- No synonym registry.

Examples:
- `  Tómatoes  ` -> `displayName: "Tómatoes"`, `canonicalName: "tomato"`
- `POTATOES` -> `canonicalName: "potato"`
- `EGGS` -> `canonicalName: "egg"` (with simple plural reduction)

## 6. Data Validation Strategy

Validation is enforced at provider/domain boundary before service mutations.

Recipe-level rules:
- `title`: required, trimmed, non-empty, bounded length.
- `description`: optional or bounded (project decision; keep bounded if enabled).
- `category`: required and must match enum.
- `ingredients`: minimum 1 valid ingredient.
- `steps`: minimum 1 valid non-empty step.
- `isFavorite`: default `false`.

Ingredient-level rules:
- `displayName`: required after trim.
- `quantity`: required numeric value and `> 0`.
- `unit`: required after trim.
- `canonicalName`: must be non-empty after normalization.
- Reject duplicates inside same recipe by `(canonicalName, unit)` pair.

Step-level rules:
- `text`: required after trim.
- `order`: sequential and stable after add/remove/reorder operations.

Image metadata rules:
- Both `imageUrl` and `imageStoragePath` are optional.
- If one is present, maintain consistency contract in update flow.

## 7. State Management Strategy

Recommended strategy: **hybrid**.

- Real-time stream for recipe list per user.
- One-shot load for detail/edit if not already available in provider cache.

Why:
- Real-time list keeps UI fresh after create/update/delete and across devices.
- Edit form should not be live-overwritten by stream updates while typing.
- Keeps complexity low and fits Provider architecture already in project.

Planned provider state slices:
- `recipes`
- `selectedRecipeId` / selected recipe view model
- `status` (`idle`, `loading`, `mutating`, `error`)
- `error` message/failure
- Filters (`category`, `favoritesOnly`)

## 8. Edge Cases and Failure Scenarios

- Missing auth user (`uid == null`) when opening recipe screens.
- Permission denied due to rules mismatch.
- Offline create/update/delete attempts.
- Duplicate submit taps causing double writes.
- Recipe deleted remotely while user is editing.
- Legacy/partial documents missing required fields.
- Category value not recognized (fallback or reject strategy required).
- Normalization collisions (different display names same canonical result).
- Excessively large ingredient/step arrays increasing document size.
- Image metadata stale after a failed upload/delete workflow.

## 9. Scalability Considerations (Without Overengineering)

- User partitioning by path already scales naturally.
- Embedded ingredients/steps keep read path simple and atomic.
- Start with minimal indexes; add only query-driven indexes.
- Sort list by `updatedAt desc` for predictable UX.
- Add pagination (`limit` + cursor) only when list size justifies it.
- Keep normalization deterministic so future shopping aggregation can reuse it.

## 10. Incremental Commit Roadmap (Minimum 10)

1. `chore(recipes): scaffold recipe module folders and placeholder files`
2. `feat(recipes-model): add recipe category enum and mapping rules`
3. `feat(recipes-model): add ingredient and step entities with contracts`
4. `feat(recipes-model): add recipe entity with embedded arrays schema`
5. `feat(recipes-normalization): add deterministic ingredient canonical normalizer`
6. `test(recipes-normalization): cover trim/lowercase/diacritic/plural cases`
7. `feat(recipes-validation): add recipe input validation contracts`
8. `feat(recipes-service): define recipe service interface for user-scoped CRUD`
9. `feat(recipes-service): implement firestore recipe CRUD under users/{uid}/recipes`
10. `feat(recipes-provider): add recipe list state with real-time subscription`
11. `feat(recipes-provider): add create/update/delete/favorite actions`
12. `feat(recipes-view): wire recipe list and add/edit/detail pages to provider`
13. `chore(firebase): add firestore rules for users/{uid}/recipes/{recipeId}`
14. `chore(firebase): add indexes for category/favorite/sort queries`
15. `test(recipes-provider): add provider behavior tests (loading/error/mutations)`

## 11. Definition of Ready (Before Implementation Starts)

Implementation starts only when all are true:
- Auth module remains unchanged and stable.
- This plan is accepted as source of truth for recipes.
- Route naming and file targets are agreed.
- Firestore rules update scope is approved.
- Commit sequence above is accepted for incremental delivery.
