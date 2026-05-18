# App Shell Module Plan

## 1. Why This Module Exists

Recipes are now the strongest part of the app, but the current home experience is
still a lightweight dashboard with placeholder navigation for the remaining
features.

This module turns the app into a cohesive product shell that:
- routes users into the finished recipe flow
- exposes the upcoming meal planning and shopping flows cleanly
- provides a stable home screen required by the PDF
- gives the rest of the project one consistent navigation structure

## 2. Current Repo Status

Already present:
- authentication gate and user session flow
- dashboard page with shortcut cards
- recipe routes, recipe pages, favorite recipes route
- sign-out flow

Still missing:
- final app-shell navigation strategy for all main modules
- route registration for meal planning and shopping list pages
- real dashboard states tied to live data instead of placeholders
- polished home structure that feels like a complete meal-management app

## 3. Scope

In scope:
- home/dashboard architecture
- top-level navigation between `dashboard`, `recipes`, `meal plan`, and
  `shopping list`
- dashboard shortcuts required by the PDF
- lightweight summary cards driven by provider data
- navigation consistency and empty/loading/error states

Out of scope:
- recipe CRUD internals
- meal plan calendar logic
- shopping list generation logic
- final visual polish beyond what is needed for clean structure

## 4. Product Goals

The app shell should let a signed-in user:
- land on a useful home screen
- reach recipes, favorites, meal planning, and shopping list quickly
- understand what needs attention this week
- move between modules without dead ends or placeholder snackbars

## 5. Recommended Navigation Strategy

Recommended structure:
- keep `AuthGate` as the authenticated entry gate
- replace the current one-page dashboard feel with a small app shell
- use a bottom navigation or a clear primary navigation pattern for:
  - Home
  - Recipes
  - Meal Plan
  - Shopping List

Preferred implementation direction:
- `DashboardPage` becomes the real home page
- dedicated route pages exist for:
  - `Home`
  - `Recipes`
  - `Favorite Recipes`
  - `Meal Plan`
  - `Shopping List`
- add a single source of truth for route constants

## 6. Data Needed From Other Modules

The dashboard should eventually summarize:
- recipe count
- favorite recipe count
- number of planned meal slots this week
- shopping list item count for the active week

This module should not compute those features itself. It should only consume
provider state from the recipes, meal plan, and shopping modules.

## 7. Views to Build

Planned view artifacts:
- `HomeDashboardPage`
- reusable summary/stat card widget
- reusable quick-action tile widget
- empty states for modules with no data yet

Potential directory targets:
- `lib/views/dashboard/`
- `lib/widgets/navigation/`
- `lib/widgets/dashboard/`

## 8. Provider Responsibilities

This module may need a small navigation/app-shell provider only if state becomes
non-trivial.

Keep it lightweight:
- selected tab/index
- restoring the active entry point
- optional home refresh triggers

Avoid putting business logic here.

## 9. Required Integration Points

The app shell must integrate with:
- `AuthProvider`
- `RecipeProvider`
- future `MealPlanProvider`
- future `ShoppingListProvider`

It must support:
- signed-in startup
- sign-out
- route-safe back navigation
- direct entry to favorites and detail pages

## 10. Acceptance Criteria

This module is complete when:
- there is no more “coming next” placeholder for meal plan and shopping list
- the app has a stable home/dashboard entry experience
- every main module can be reached from the shell
- home shows meaningful module shortcuts and summary information
- navigation feels coherent on mobile-sized screens

## 11. Implementation Roadmap

1. Introduce final route constants for app-shell-level navigation.
2. Build real placeholder pages only if needed to bridge unfinished modules.
3. Refactor `DashboardPage` into a production-shaped home page.
4. Add top-level navigation between home, recipes, meal plan, and shopping.
5. Connect dashboard summary cards to provider data.
6. Remove “coming soon” interactions from production paths.
7. Add widget tests for core shell navigation.

## 12. Branching Rule

Any future branch created for this work must start with:
- `feature/`

