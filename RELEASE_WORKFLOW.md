# UniHub Mobile - Play Store Release Workflow

This document outlines the systematic process for preparing and releasing the UniHub Mobile app to the Google Play Store.

---

## Phase 1: Branding & Assets
- [x] **App Name & Package ID**: Verified `com.unihub.unihub_mobile` is final and `label` is "UniHub".
- [x] **Launcher Icons**: Configuration verified in `pubspec.yaml`.
- [ ] **Splash Screen**: Verify splash screen implementation for Android 12+.
- [x] **Version Consistency**: Version `1.0.0+1` confirmed in `pubspec.yaml`.

## Phase 2: Firebase Production Readiness
- [x] **Security Rules**: Drafted production Firestore rules in `firestore.rules`. **Action: Deploy to Firebase Console**.
- [x] **Firestore Indexes**: Documented required composite indexes in `FIRESTORE_INDEXES_REQUIRED.md`.
- [ ] **Environment Check**: Restrict API keys in Google Cloud Console.
- [x] **Analytics & Crashlytics**: Integrated Firebase Crashlytics in `main.dart` and `AppLogger`.

## Phase 3: Code Cleanup & Performance
- [x] **Logging Audit**: Migrated verbose `debugPrint` in `AdminRepository` and `NoteReader` to `AppLogger`.
- [x] **Permissions Audit**: Verified `AndroidManifest.xml` permissions.
- [x] **Error Handling**: Implemented fatal error catching in `main.dart`.
- [ ] **Performance Profile**: Run the app in Profile mode to check for jank.

## Phase 4: Android Build Configuration
- [x] **Keystore Configuration**: Verified `key.properties` and `upload-keystore.jks`.
- [x] **Proguard/R8**: Enabled in `build.gradle` and created `proguard-rules.pro`.
- [x] **Target API**: Verified `targetSdkVersion` is 34+.
- [ ] **App Bundle Generation**: Run `flutter build appbundle --release`.

## Phase 5: Testing & QA
- [ ] **Release Build Test**: Install the `.aab` on a physical device.
- [ ] **Feature Verification**: Final check of Marketplace, Events, Housing, and Chat.
- [ ] **Logcat Cleanliness**: Monitor for unexpected warnings in release logs.

## Phase 6: Play Store Submission
- [ ] **Store Listing**: Prepare screenshots and description.
- [ ] **Privacy Policy**: Host and link the privacy policy.
- [ ] **Data Safety**: Complete the questionnaire in Play Console.

---

## Current Status
- **Phase 4 completed** (Technical config).
- **Next Task**: Phase 5 - Generate and test a Release App Bundle.
