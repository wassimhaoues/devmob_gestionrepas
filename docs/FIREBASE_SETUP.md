# Firebase Setup

## Purpose

This project depends on Firebase for:
- Authentication
- Cloud Firestore
- Firebase Storage

The checked-in app code already expects Firebase to be configured through:
- [lib/firebase_options.dart](/home/coworky/Study/flutter_project/devmob_gestionrepas/lib/firebase_options.dart)
- [firebase.json](/home/coworky/Study/flutter_project/devmob_gestionrepas/firebase.json)
- [firestore.rules](/home/coworky/Study/flutter_project/devmob_gestionrepas/firestore.rules)
- [firestore.indexes.json](/home/coworky/Study/flutter_project/devmob_gestionrepas/firestore.indexes.json)
- [storage.rules](/home/coworky/Study/flutter_project/devmob_gestionrepas/storage.rules)

## Required Firebase Services

Enable these products in the target Firebase project:
- Firebase Authentication
  Use Email/Password sign-in.
- Cloud Firestore
  Use production or locked test rules as needed for the demo.
- Firebase Storage
  Required for recipe photo upload.

## Project Configuration

1. Install the Firebase CLI if it is not already available.
   Command: `npm install -g firebase-tools`
2. Install FlutterFire CLI if needed.
   Command: `dart pub global activate flutterfire_cli`
3. Log in to Firebase.
   Command: `firebase login`
4. From the repo root, connect the Flutter app to the target Firebase project.
   Command: `flutterfire configure`
5. Make sure the generated [lib/firebase_options.dart](/home/coworky/Study/flutter_project/devmob_gestionrepas/lib/firebase_options.dart) matches the intended Firebase project.

## Deploying Backend Config

From the repo root:

- Deploy Firestore rules:
  `firebase deploy --only firestore:rules`
- Deploy Firestore indexes:
  `firebase deploy --only firestore:indexes`
- Deploy Storage rules:
  `firebase deploy --only storage`

Or deploy all checked-in Firebase config:

`firebase deploy --only firestore,storage`

## Firestore Collections Used

User profile document:
- `users/{uid}`

Recipe documents:
- `users/{uid}/recipes/{recipeId}`

Meal plan documents:
- `users/{uid}/mealPlanEntries/{entryId}`

Local shopping checklist state:
- stored on-device with `shared_preferences`
- not stored in Firestore

## Storage Paths Used

Recipe images are uploaded under:
- `users/{uid}/recipes/{recipeId}/cover.webp`

The exact filename may vary if processing changes later, but the path prefix is:
- `users/{uid}/recipes/{recipeId}/`

## Demo-Day Verification

Before presenting:
- confirm Email/Password sign-in is enabled
- confirm Firestore rules and indexes are deployed
- confirm Storage rules are deployed
- create one fresh test account
- confirm recipe image upload works on the actual target device
- confirm the app launches with the intended Firebase project, not a personal test project

## Notes

- Shopping list generation depends on recipe and meal-plan data being readable for the signed-in user.
- Recipe deletion is intentionally blocked when a recipe is still used by meal-plan entries.
- No extra Firestore composite indexes are currently required beyond the checked-in [firestore.indexes.json](/home/coworky/Study/flutter_project/devmob_gestionrepas/firestore.indexes.json).
