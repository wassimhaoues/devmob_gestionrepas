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
- Optional recipe photo support
- Optional image metadata fields
- Favorite toggle (`isFavorite: bool`)
- Favorites quick access from recipes UI
- Recipe module visual mockup deliverables required by project specification
- Secure recipe photo upload backed by Firebase Storage

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
- `imageMimeType`: string or null
- `imageSizeBytes`: int or null
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
- Recipe photo remains optional, but when used it must be backed by an actual
  pick/upload/display flow rather than metadata-only manual text input.
- Uploaded recipe photos are stored in Firebase Storage under a user-scoped
  path, and the Firestore recipe document keeps only metadata and the public
  access reference needed by the app.

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
- The recipe form must support actual image selection for the optional photo
  requirement from the project PDF.
- Uploaded images must be previewable from recipe list/detail/edit flows when
  available.
- Recipe image uploads must reject files larger than `10 MB`.
- Preferred stored output format is `webp` after client-side compression when
  supported by the chosen implementation path.
- If `webp` conversion is not feasible on the selected Flutter stack, the
  fallback is to compress and downscale the image before upload while keeping a
  safe web/mobile-friendly format such as `jpeg`.

### 6.2 Recipe Photo Upload Strategy

Storage path strategy:
- `users/{uid}/recipes/{recipeId}/cover.webp`
- or `users/{uid}/recipes/{recipeId}/{generatedFileName}.webp`

Client-side upload pipeline:
1. Pick image from device.
2. Reject immediately if the selected file size is greater than `10 MB`.
3. Decode and recompress locally before upload.
4. Convert to `webp` if supported by the selected image processing package.
5. Downscale oversized dimensions to a reasonable maximum for recipe usage.
6. Upload only the processed output.
7. Persist resulting `imageUrl`, `imageStoragePath`, `imageMimeType`, and
   `imageSizeBytes` on the recipe document.

Compression goals:
- Optimize for recipe thumbnails and detail views, not original-quality archive
  storage.
- Prefer a practical upper bound such as `1600px` on the longest edge unless
  later UI needs justify a different limit.
- Target a noticeably smaller processed file than the original whenever
  possible.

Deletion/update behavior:
- Replacing a recipe photo should delete or overwrite the previous file in
  Firebase Storage to avoid orphaned uploads.
- Deleting a recipe should also delete its stored recipe photo when present.

Accepted file types:
- Allow common image inputs such as `jpg`, `jpeg`, `png`, `webp`, `heic`
  only if the chosen processing path can decode them safely.
- Reject unsupported or ambiguous file types before upload.

## 6.1 PDF-Driven Recipe Additions

The project specification PDF adds the following recipe-only expectations on top
of the initial module plan:

- Add recipe with: name, description, ingredients, steps, optional photo.
- Category grouping for recipes (`petit déjeuner`, `déjeuner`, `dîner`,
  `dessert`, etc.), which maps cleanly to the locked enum values in English.
- Favorite recipes with:
  - an "add to favorites" interaction
  - quick access to favorite recipes from the recipes experience
- Visual mockup coverage must include:
  - recipe list page
  - add/edit recipe page
- Bonus alignment if the implemented UI stays faithful to the approved mockup.
- Optional photo support should now be treated as real upload support because
  Firebase Storage is enabled for the project.

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
- Favorite quick-access state can be satisfied by a dedicated favorites entry
  point, explicit favorites section, or an equivalent first-class UI shortcut
  beyond a hidden implementation detail.
- Photo upload state should include enough status to represent picking,
  processing/compressing, uploading, replacing, and deleting image flows.

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
- Recipe image upload succeeds but persisted metadata becomes inconsistent.
- Missing quick-access path makes favorites technically present but weak against
  the PDF wording.
- Image selected by the user exceeds `10 MB`.
- Image conversion/compression fails on-device before upload.
- Replacement upload succeeds but old Firebase Storage object is left orphaned.
- Recipe delete succeeds but associated Firebase Storage object remains.
- Unsupported image format is selected.
- Malicious or malformed file is renamed with an image extension.

## 9. Scalability Considerations (Without Overengineering)

- User partitioning by path already scales naturally.
- Embedded ingredients/steps keep read path simple and atomic.
- Start with minimal indexes; add only query-driven indexes.
- Sort list by `updatedAt desc` for predictable UX.
- Add pagination (`limit` + cursor) only when list size justifies it.
- Keep normalization deterministic so future shopping aggregation can reuse it.
- Keep photo handling optional so the recipe document stays usable even when the
  user skips image upload.
- Keep processed image files small enough for fast mobile loading and modest
  Firebase Storage usage.

## 9.1 Security Requirements For Recipe Images

Security expectations:
- Firebase Storage rules must restrict recipe image access by authenticated user
  ownership, matching the same user-scoped model as Firestore recipe documents.
- The app must validate file size, file extension, and MIME type before upload.
- The app must avoid uploading arbitrary files renamed as images when basic type
  checks fail.
- The upload pipeline should decode and re-encode supported image files before
  upload so the stored output is a normalized image artifact rather than the raw
  original file blob.
- Unsupported, unreadable, or malformed files must be rejected client-side.

Security boundaries:
- Client-side checks reduce risk but do not replace backend security rules.
- Storage rules should constrain path ownership and disallow writes outside the
  current user recipe image scope.
- This school project will not implement enterprise malware scanning unless a
  later requirement explicitly demands external scanning infrastructure.
- For this project, the practical anti-malware posture is:
  - accept only supported image formats
  - decode/re-encode before upload
  - reject oversized or malformed files
  - enforce authenticated owner-only storage paths

## 10.1 Branch Naming Convention

All future implementation branches created for this project must start with:

- `feature/`

Examples:
- `feature/recipes-photo-upload`
- `feature/mealplan-calendar`

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
16. `feat(recipes-photo): add actual optional recipe photo pick/upload flow`
17. `feat(recipes-photo): display recipe photo in list/detail/edit experiences`
18. `feat(recipes-favorites): add first-class quick access to favorite recipes`
19. `docs(recipes): attach or reference required recipe UI mockups from spec`
20. `feat(recipes-photo): reject source images above 10 MB before upload`
21. `feat(recipes-photo): compress and convert recipe photos to webp or fallback compressed format`
22. `chore(storage): add Firebase Storage rules for user-scoped recipe images`
23. `feat(recipes-photo): delete or replace orphaned recipe image files safely`
24. `test(recipes-photo): cover validation and processed upload flow`

## 11. Definition of Ready (Before Implementation Starts)

Implementation starts only when all are true:
- Auth module remains unchanged and stable.
- This plan is accepted as source of truth for recipes.
- Route naming and file targets are agreed.
- Firestore rules update scope is approved.
- Commit sequence above is accepted for incremental delivery.
