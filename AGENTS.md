# UniHub Mobile - AI Agent Guide

## Project Overview
UniHub is a multi-feature Flutter mobile app (Android) for university communities. It integrates Firebase backend (Auth, Firestore, Storage, Messaging) with cloud functions for backend logic. All state management uses Riverpod, and code generation via `build_runner`.

**Project Config**: `pubspec.yaml` | **Startup**: `lib/main.dart` | **Navigation**: `lib/app/router/app_router.dart`

---

## Architecture: Feature-Based + Clean Layers

```
lib/
├── features/          # Feature modules: auth, marketplace, housing, chat, etc.
│   └── {feature}/
│       ├── data/      # Repositories (implementation), models with JSON serialization
│       ├── domain/    # Business entities, abstract repositories, interfaces
│       └── presentation/
│           ├── controllers/  # StateNotifier controllers for complex logic
│           └── screens/      # UI pages
├── app/               # Core app setup
│   ├── router/        # GoRouter navigation (961 lines!)
│   ├── providers/     # App-level Riverpod providers
│   └── theme/         # Material theme definitions
├── services/          # Singletons: NotificationService, PresenceService, etc.
├── core/              # Shared utilities, constants, widgets
└── models/            # Shared domain models
```

**Pattern**: Each feature is self-contained with clear boundaries. Cross-feature communication via Firestore listeners and shared providers, NOT direct imports.

---

## State Management: Riverpod Everywhere

### Providers Setup Pattern
- **Raw Firebase Access**: `firebaseAuthProvider`, `firestoreProvider`, `firebaseMessagingProvider` (in `lib/features/auth/shared/providers.dart`)
- **Repository Layer**: `authRepositoryProvider` wraps Firebase + business logic
- **State Streams**: `authStateProvider` (Firebase auth), `appUserProvider` (current user), `userByIdProvider` (family provider for any user)
- **SharedPreferences**: Initialized in `main.dart` as override (required!)

### Controller Pattern (see `auth_controller.dart`)
```dart
class MyController extends StateNotifier<AsyncValue<void>> {
  Future<void> action() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      // Business logic here
    });
  }
}
```
- Use `AsyncValue.guard()` to auto-wrap errors
- Always reset state on success to avoid "sticky" states
- Controllers are StateNotifierProviders, watched by screens

### For Real-Time Data
- Use `StreamProvider` for Firestore listeners
- Use `.map()` on streams to transform data (see `appUserProvider`)
- Family providers for dynamic document access

---

## Firebase Architecture

### Initialization (main.dart)
- Firebase initialized with `DefaultFirebaseOptions.currentPlatform` (auto-generated)
- Firestore persistence ENABLED: `persistenceEnabled: true, cacheSizeBytes: UNLIMITED`
- Background message handler: `@pragma('vm:entry-point') _firebaseMessagingBackgroundHandler`

### Data Layer: Repositories
- Interface in `domain/repositories/`, implementation in `data/repositories/`
- Implementations use Firestore queries, handles errors, does pagination if needed
- Example: `AuthRepositoryImpl` handles signIn, signUp, user CRUD

### Backend: Cloud Functions (Node.js)
- **Location**: `functions/index.js`
- **Triggers**: 
  - Firestore document creation (e.g., `onDocumentCreated("notifications_queue/{queueId}")`)
  - Scheduled tasks via `onSchedule`
  - Handles notification queue processing, token refresh, cleanup
- **Deploy**: `firebase deploy --only functions`

### Real-Time Features
- **Presence Tracking**: `PresenceService` writes user online status to Firestore
- **Notifications**: Queue documents → Cloud Function → Firebase Messaging → Local notifications via `flutter_local_notifications`
- **Chat**: Firestore subcollections store messages; real-time via StreamProvider

---

## Key Services & Patterns

### NotificationService
- Implements `NotificationSender` interface
- Manages Firebase Messaging token storage (in Firestore `users/{uid}/tokens/`)
- Listens for background/foreground messages
- Displays local notifications with icons and channels
- Token refresh on user login

### PresenceService
- Updates `users/{uid}/lastSeen` and `isOnline` in Firestore
- Initializes on auth state change (see `main.dart` auth listener)

### ConnectivityService
- Watches network status via `connectivity_plus`
- Referenced in `main.dart` to show offline banner

### AppLogger (lib/core/utils/app_logger.dart)
- Use `AppLogger.info()`, `.warning()`, `.error()`, `.notification()`
- Only logs in debug mode; errors logged in release via `developer.log()`
- Includes emojis in log names (🚀, 🔔✅, 🔔❌)

---

## Code Generation & Build Workflow

### Build Runner (generates models)
```sh
flutter pub run build_runner build --delete-conflicting-outputs
```
- **freezed**: Data classes with copyWith, equality (`.freezed.dart` files)
- **json_serializable**: `toJson()`, `fromJson()` for Firestore serialization (`.g.dart` files)
- **Router**: GoRouter config (run after router changes)

### Icons Generation
```sh
flutter pub run flutter_launcher_icons
```
- Reads `flutter_launcher_icons` config in `pubspec.yaml`
- Generates app icons for Android/iOS

### Full Build (APK/AAB)
```sh
flutter build apk --release  # or: flutter build appbundle
flutter clean && flutter pub get  # if issues persist
```

---

## Common Patterns & Conventions

### Model Serialization
- Use `@freezed` for immutable data classes with JSON support
- Example: `part 'user.freezed.dart'` + `part 'user.g.dart'`
- Firestore conversions: `.toJson()` before write, `.fromJson()` after read

### Error Handling
- Async operations wrapped with `AsyncValue.guard()` in controllers
- UI checks `state.hasError`, `.error` properties
- Errors logged via `AppLogger.error(message, exception, stackTrace, tag)`

### Firestore Queries
- Always specify exact document paths for direct access
- Use `.where()` clauses, `.orderBy()`, `.limit()` for queries
- Listen via `snapshots()` for StreamProvider, `get()` for one-time reads

### Navigation
- GoRouter with deeplinks support (see `app_router.dart` for 961 lines of routes!)
- Each feature has routes defined; main app router imports all
- Use `context.go()` or `context.push()` for navigation

### Offline Support
- Firestore caching enabled → reads work offline, writes queue
- Presence service syncs when reconnected
- Check `ConnectivityStatus` before critical operations

---

## File Checklist for New Features

Create a new feature with this structure:
```
lib/features/{feature_name}/
├── data/
│   ├── models/           # JSON serializable models
│   ├── data_sources/     # Firestore queries (optional)
│   └── repositories/     # Implementation of domain interface
├── domain/
│   ├── entities/         # Business objects (freezed)
│   ├── models/           # Shared domain models
│   └── repositories/     # Abstract interfaces
├── presentation/
│   ├── controllers/      # StateNotifier for state management
│   ├── widgets/          # Reusable components
│   └── screens/          # Page-level widgets
└── shared/
    └── providers.dart    # Feature-level provider definitions
```

Then add routes to `lib/app/router/app_router.dart` and import provider in `main.dart` if needed.

---

## Quick Reference: Key Files
- **main.dart**: Firebase init, provider overrides, app root (auth listener, connectivity)
- **app_router.dart**: All 961 routes, nested GoRouterShell for tabs, auth guards
- **auth/shared/providers.dart**: Firebase singletons + auth StreamProviders
- **NotificationService**: Token mgmt, message handling, local notification dispatch
- **functions/index.js**: Cloud Function triggers (notifications, cleanup, scheduling)

