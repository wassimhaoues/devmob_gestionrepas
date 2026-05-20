# Integration And Hardening Plan

## Progress Tracker

Current phase:
- Phase 1: completed

Completed in this phase:
- branch created for integration and hardening work
- dashboard now owns signed-in startup for recipe and meal-plan providers
- meal-plan startup is disabled for dashboard-embedded tabs to avoid duplicate
  watcher wiring
- dashboard home summary now shows live shopping-list counts instead of a
  placeholder zero
- added widget coverage for dashboard-level provider wiring and shopping summary

Implementation phases:
- [x] Phase 1: signed-in flow wiring and dashboard integration
- [ ] Phase 2: cross-module dependency policies and backend completion
- [ ] Phase 3: reliability consistency, coverage expansion, and demo readiness

## 1. Why This Phase Exists

After recipes, meal planning, and shopping list are all present, the app still
needs one dedicated pass to become reliably usable as a complete school-project
submission.

This phase is about making the modules work together cleanly before the final
visual polish phase.

## 2. Scope

In scope:
- cross-module wiring
- route completion
- backend rules completion
- loading/error consistency
- deletion and dependency policies
- test coverage for critical flows
- demo readiness

Out of scope:
- major redesign work
- branding-only polish

## 3. Integration Points To Resolve

Required integration checks:
- recipe deletion versus planned meals
- meal-plan updates versus shopping-list regeneration
- home/dashboard summary data
- auth session transitions across all providers
- sign-out cleanup for all user-scoped providers

## 4. Backend Completion

Before this phase is done, ensure:
- Firestore rules cover recipes, meal plans, and any derived collections
- Storage rules remain aligned with recipe photo rules
- required indexes exist and are committed

## 5. Reliability Requirements

Every main flow should have:
- loading state
- empty state
- recoverable error state
- retry path where appropriate

Critical flows:
- sign in -> dashboard
- create recipe with photo
- assign recipe to meal slot
- generate shopping list
- sign out

## 6. Testing Goals

Minimum targets:
- provider tests for every main module
- service tests for core mapping/aggregation logic
- widget tests for at least the most important screens
- one end-to-end manual QA checklist for demo day

## 7. Demo Readiness

Before calling the app feature-complete:
- no placeholder module tiles remain
- all routes used in the demo are registered and stable
- seeded or easy-to-create data exists for presentation
- image upload works on the target device
- Firebase project configuration is documented

## 8. Acceptance Criteria

This phase is complete when:
- the app feels internally consistent across modules
- major user flows work without dead ends
- critical dependencies between modules are handled intentionally
- the project is ready for final UI/UX improvements

## 9. Implementation Roadmap

1. Wire all providers into the signed-in app flow.
2. Resolve cross-module deletion/update policies.
3. Add missing backend rules and indexes.
4. Standardize loading/error/empty state patterns.
5. Expand widget and provider coverage.
6. Create a demo/QA checklist in docs.

## 10. Branching Rule

Any future branch created for this work must start with:
- `feature/`
