# Meal Planner

A Flutter meal planning application for managing recipes, organizing weekly meals, and generating shopping lists from planned dishes.

The app is built with Firebase for authentication, data storage, and image hosting, and uses a provider-based state management approach for app-level features.

## Overview

Meal Planner helps users:
- create and manage recipes with ingredients, steps, favorites, and optional images
- assign one or more recipes to meal slots across the week
- generate a shopping list from the current meal plan
- track shopping progress locally on the device
- sign in, register, reset passwords, and verify email accounts

## Features

### Authentication
- email/password sign in and registration
- email verification flow
- forgot password flow
- Firestore-backed user profile storage

### Recipe Management
- create, edit, view, and delete recipes
- categorize recipes by meal type
- mark recipes as favorites
- upload and store recipe images in Firebase Storage
- validate recipe input before persistence
- typed ingredient units for more reliable quantity handling

### Meal Planning
- weekly planner with day-by-day navigation
- multiple recipes per meal slot
- dedicated meal slots including dessert
- assign recipes through a multi-select picker
- remove individual planned recipes from a slot

### Shopping List
- generate shopping items from planned meals
- normalize compatible ingredient units for better aggregation
- keep completed shopping state in local storage
- separate pending and completed items

### UI
- custom theme with shared panels, loading states, and auth shell
- branded app icon propagated across app surfaces and launcher assets
- responsive meal planner improvements for better day navigation

## Tech Stack

- Flutter
- Dart
- Firebase Auth
- Cloud Firestore
- Firebase Storage
- Provider
- Shared Preferences

## Project Structure

```text
lib/
  main.dart                App entrypoint and dependency wiring
  firebase_options.dart    FlutterFire configuration
  models/                  Core domain models
  providers/               App state and feature controllers
  services/                Firebase, validation, image, and shopping logic
  theme/                   Shared theme tokens and styles
  views/                   App screens
  widgets/                 Reusable UI components
```

## Getting Started

### Prerequisites

- Flutter SDK
- Dart SDK
- Android Studio or VS Code with Flutter tooling
- Firebase project configured for the platforms you want to run

### Install Dependencies

```bash
flutter pub get
```

### Firebase Setup

This repository already includes generated Firebase configuration for the current project setup:
- `lib/firebase_options.dart`
- `android/app/google-services.json`

If you connect the app to a different Firebase project or change the Android package id / iOS bundle id, regenerate the FlutterFire config and replace the platform-specific Firebase files.

### Run the App

```bash
flutter run
```

## Testing

Run the full test suite with:

```bash
flutter test
```

The repository includes tests for:
- providers
- validators
- shopping list generation
- key widget flows

## Building Android APK

To build a release APK:

```bash
flutter build apk --release
```

Generated output:

```text
build/app/outputs/flutter-apk/app-release.apk
```

## Release Notes

The project is functional for testing, but a few production-release items are still worth finalizing:

- Android package id is still using a placeholder-style value
- Android release signing is not yet configured with a dedicated release keystore
- app naming and store metadata may still need final polish before public distribution

## Repository Assets

Branding assets introduced in this repository live under:

```text
assets/branding/
```

This includes:
- transparent in-app icon source
- 1024 master icon export
- chroma-key source used during generation

## Useful Commands

```bash
flutter pub get
flutter run
flutter test
flutter build apk --release
flutter clean
```

## Roadmap Ideas

- proper Android release signing
- package/bundle id cleanup
- app store ready metadata and branding polish
- richer meal-plan analytics
- recipe import/export
- collaborative or shared planning

## License

No license is currently defined in this repository. Add one before public distribution if needed.
