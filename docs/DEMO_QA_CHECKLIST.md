# Demo QA Checklist

## Before The Demo

- Firebase project is the intended one for presentation
- Firestore rules are deployed
- Firestore indexes are deployed
- Storage rules are deployed
- target device is signed in to the correct Firebase-backed build
- at least one clean demo account is available
- network connection is stable enough for sign-in, Firestore, and image upload

## Recommended Demo Data

Create or verify:
- at least 3 recipes
- at least 1 favorite recipe
- at least 1 recipe with a photo
- meals planned across multiple days in the current week
- at least 1 shopping list with both pending and completed items

Suggested ingredient overlap for the demo:
- two recipes sharing one ingredient such as `black olives`
- this makes shopping-list aggregation easy to show

## Auth Flow

- sign in works with Email/Password
- incorrect credentials show a recoverable error
- registration works for a new account
- email verification flow is reachable
- sign out returns the app to the auth flow cleanly

## Recipe Flow

- create a recipe successfully
- edit a recipe successfully
- favorite toggle updates correctly
- recipe photo upload works
- deleting an unused recipe works
- deleting a recipe that is still planned is blocked with a clear message

## Meal Plan Flow

- current week loads successfully
- assign a recipe to a slot
- replace a recipe in a slot
- remove a recipe from a slot
- previous and next week navigation works
- past weeks remain view-only

## Shopping List Flow

- shopping list generates from current planned meals
- repeated planned recipes increase ingredient quantities correctly
- checking an item moves it into completed
- adding a new meal after completion creates new pending quantity instead of mutating completed history
- reopening a completed item works
- shopping list refresh works

## Dashboard And Navigation

- dashboard opens after sign-in
- recipe, meal plan, and shopping tabs are reachable from the shell
- dashboard summary cards load real values
- refresh actions recover from temporary sync failures

## Error And Recovery Checks

- recipe sync failure shows a retry path
- meal-plan sync failure shows a retry path
- shopping summary failure shows a retry path
- shopping screen retry works after a temporary failure

## Final Presentation Pass

- no placeholder pages appear in the main demo flow
- obvious empty states read clearly
- no crashes during sign in, recipe create, meal assign, shopping generate, or sign out
- images render correctly on the demo device
- text is readable on the target screen size

## Nice Demo Sequence

1. Sign in.
2. Show recipes and favorites.
3. Create or open a recipe with a photo.
4. Go to meal plan and assign recipes to the current week.
5. Open shopping list and show generated ingredients.
6. Check one item as completed.
7. Add another meal with an overlapping ingredient.
8. Show the new pending shopping quantity and preserved completed history.
9. Sign out.
