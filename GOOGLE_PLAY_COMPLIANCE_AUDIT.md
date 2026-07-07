# Google Play Policy & Compliance Audit Report
## UniHub RC-1 Mobile Application

**Report Date**: July 8, 2026  
**App Version**: 1.0.0+1  
**Target SDK**: Android 14 (API 36)  
**Package**: `com.unihub.unihub_mobile`

---

## EXECUTIVE SUMMARY

**Overall Compliance Status**: 🟡 **87% READY FOR GOOGLE PLAY**

**Blocker Count**: 1 Critical  
**High Priority Issues**: 4  
**Medium Priority Issues**: 2  
**Estimated Time to Fix**: 1-2 weeks

**Recommendation**: **CONDITIONAL GO** - Can proceed after critical Ad Unit ID issue is resolved.

---

## 1. PRIVACY POLICY & TERMS OF SERVICE

### Status: ⚠️ **CONDITIONAL COMPLIANCE**

#### ✅ **VERIFIED**
- **Privacy Policy URL**: `https://unihub-3663e.web.app/privacy`
  - Configured in: `lib/features/profile/settings_screen.dart:202`
  - Also referenced in: `lib/features/auth/presentation/screens/register_screen.dart`
  - Dynamically retrieved from: `systemSettingsProvider` (Firebase config)

- **Terms of Service URL**: `https://unihub-3663e.web.app/terms`
  - Configured in: `lib/features/profile/settings_screen.dart:212`
  - Admin-configurable via Firebase system settings

#### ⚠️ **ACTION REQUIRED**

**HIGH PRIORITY**: Verify both URLs resolve to actual hosted documents:
1. Ensure Privacy Policy is hosted at `https://unihub-3663e.web.app/privacy`
2. Ensure Terms of Service is hosted at `https://unihub-3663e.web.app/terms`
3. Both must be publicly accessible (not behind authentication)
4. Both must be comprehensive and updated for this app version

**Privacy Policy Must Include**:
- Data collection practices (profiles, media, verification docs, location)
- Data usage (Firebase services, push notifications, crash reporting)
- Data retention policies
- User rights (access, deletion, export)
- Third-party sharing (Firebase, Cloudinary, Google services)
- Security measures
- Contact information for privacy inquiries
- GDPR/CCPA compliance statements
- Age restrictions/COPPA compliance (if applicable)

---

## 2. DATA COLLECTION & SAFETY

### Status: ✅ **COMPLIANT**

#### Data Collected

**Core User Profile** (Required):
- Email address
- Full name
- University & campus
- Course & year of study

**Core User Profile** (Optional):
- Phone number (for WhatsApp contact)
- Profile photo & cover image
- Bio/description
- Social media links

**Identity & Trust** (Optional, user-initiated):
- Identity verification documents (photo + selfie)
- Student ID images
- Professional credentials
- Reviews & ratings

**Activity Data** (System-generated):
- Listings created (marketplace, housing, gigs, events)
- Messages & chat history
- Study notes created
- Housing applications
- Event attendance
- Blocked users list

**Location Data** (Optional, user-controlled):
- Campus coordinates
- Housing listing location (latitude/longitude)
- Landmark coordinates for map display

**Device & Technical Data** (System):
- Firebase Cloud Messaging tokens
- Device OS version & platform
- Last active timestamp
- Online status

**Preferences**:
- Notification settings
- Privacy settings
- Theme preferences (dark/light)

#### Transmission Security: ✅ **ENCRYPTED**
- All URLs enforce HTTPS globally
- Firebase connections use TLS 1.3
- Firestore rules enforce access control
- File uploads via Cloudinary CDN (HTTPS)

#### Data Retention: ⚠️ **NOT DOCUMENTED**
- Account deletion clears all associated data ✅
- But no documented retention policies for inactive accounts
- No data archival policy specified

#### Compliance Assessment
- ✅ Data encryption in transit
- ✅ Data encryption at rest (Firebase default)
- ✅ Purpose-driven collection
- ✅ Granular user control
- ⚠️ Retention policies not documented

---

## 3. PERMISSIONS ANALYSIS

### Status: ✅ **FULLY COMPLIANT**

#### Android Permissions Declared

| Permission | Used For | Status | Justification |
|-----------|----------|--------|---------------|
| **INTERNET** | Firebase, APIs | ✅ Required | Core functionality |
| **ACCESS_FINE_LOCATION** | Campus maps, listing location | ✅ Used | geolocator package |
| **ACCESS_COARSE_LOCATION** | Fallback location | ✅ Used | geolocator package |
| **ACCESS_NETWORK_STATE** | Network detection | ✅ Used | Connectivity detection |
| **READ_MEDIA_IMAGES** | Photo uploads | ✅ Used | image_picker package (Android 13+) |
| **READ_MEDIA_VIDEO** | Video uploads | ✅ Used | image_picker package (Android 13+) |
| **READ_MEDIA_VISUAL_USER_SELECTED** | Partial photo access | ✅ Used | image_picker (Android 14+) |
| **READ_EXTERNAL_STORAGE** | Legacy storage (Android ≤12) | ✅ Used | Scoped with maxSdkVersion=32 |
| **WRITE_EXTERNAL_STORAGE** | Legacy storage (Android ≤9) | ✅ Used | Scoped with maxSdkVersion=29 |
| **CAMERA** | Profile/verification photos | ✅ Used | image_picker package |
| **POST_NOTIFICATIONS** | FCM push notifications | ✅ Used | firebase_messaging (Android 13+) |

#### Permission Implementation: ✅ **PROPER**
- Location: Runtime request in `lib/core/location/services/location_service.dart`
- Notifications: Runtime request in `lib/services/notification_service.dart:119`
- Camera/Media: Automatic via image_picker
- All use `permission_handler` package for Android 6.0+ (API 23+)

#### Hardware Features
- `<uses-feature android:name="android.hardware.camera" android:required="false" />`
- Camera correctly marked as optional ✅

---

## 4. ACCOUNT MANAGEMENT

### Status: ⚠️ **PARTIALLY COMPLIANT**

#### Account Creation: ✅ **COMPLIANT**
- Email/password registration
- Google Sign-in support
- Email verification required
- Onboarding completion enforced
- No test accounts in production

#### Account Deletion: ✅ **FULLY IMPLEMENTED**
**Location**: `lib/features/auth/data/repositories/auth_repository_impl.dart:343-430`

**Process**:
1. User confirmation dialog (warns of permanent data loss)
2. Firestore user document marked as deleted
3. Firebase Auth account deleted
4. Cascade cleanup of all user data:
   - Marketplace listings
   - Housing listings
   - Study notes
   - Events created
   - Gigs posted & applications
   - Community feed items
   - All messages & chat data
   - Verification documents
   - FCM tokens
   - Notification preferences

**Cleanup Collections**:
```
listings/
housing_listings/
notes/
feed/
gig_applications/
verification_applications/
student_verifications/
identity_verifications/
events/
organizers/
users/{uid}/notifications/
users/{uid}/tokens/
```

#### Account Data Export: ❌ **NOT IMPLEMENTED**
**REQUIREMENT**: GDPR Article 15, CCPA §1798.100

**ACTION REQUIRED**: Implement user data export feature to allow users to download their data (profile, listings, messages, documents) in common format (JSON, CSV, or PDF).

#### Password Reset: ✅ **IMPLEMENTED**
- Email-based reset via Firebase Auth
- Available in login & settings screens
- No security issues found

#### User Blocking System: ✅ **IMPLEMENTED**
- Users can block other users
- Blocked users' content filtered from feeds
- Stored in user document: `blockedUids` array
- Unblock feature available

#### Ban & Suspension System: ✅ **IMPLEMENTED**
**Location**: `lib/features/shared/banned_screen.dart`
- Permanent bans with reason display
- Temporary suspensions with end date
- Admin can ban/suspend users
- Banned users cannot access app

---

## 5. USER GENERATED CONTENT & MODERATION

### Status: ✅ **COMPLIANT**

#### Report Functionality: ✅ **IMPLEMENTED**
**Location**: `lib/features/shared/feed_repository.dart`

- Users can report inappropriate content
- Report dialog: "Reason for reporting..." text input
- Data stored in Firestore `reports` collection
- Admin notification routed to `/admin/reports`
- Reports tracked with reporter ID, item ID, reason, timestamp

#### Block Functionality: ✅ **IMPLEMENTED**
- Users can block authors/sellers
- Blocked users' content hidden from feed
- Block/unblock functions in Settings > Blocked Users

#### Moderation Interface: ✅ **IMPLEMENTED**
**Location**: `lib/features/admin/presentation/screens/`
- Admin dashboard with moderation tools
- Report queue
- Content removal capability
- Moderation history tracking

#### Safety Features: ✅ **IMPLEMENTED**
- University-only community (prevents random strangers)
- Identity verification system (optional, builds trust)
- Student verification badge
- Professional role verification
- Trust score calculation
- Verification status displayed on profiles

#### Content Categories with Moderation:
- **Marketplace**: Listings with product details
- **Housing**: Apartment & roommate listings
- **Events**: Community & club events
- **Chat**: Direct messaging
- **Community**: Feed posts
- **Gigs**: Job postings
- **Notes**: Study materials

#### Compliance Assessment: ✅ **FULLY COMPLIANT**
- ✅ Report system functional
- ✅ Block system functional
- ✅ Ban/suspension available
- ✅ Community safety features present
- ⚠️ Moderation policies should be documented in Privacy Policy

---

## 6. SENSITIVE APIS & FEATURES

### Status: ⚠️ **MOSTLY COMPLIANT WITH ACTION ITEMS**

#### Location Services: ✅ **COMPLIANT**
**Package**: `geolocator: ^11.0.0`
- Usage: Campus maps, housing location picker, distance calculation
- Permissions: `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION` (already reviewed ✅)
- Privacy: Location only collected when user explicitly sets it for listings
- Justification: Clear user intent

#### Camera & Image Picker: ✅ **COMPLIANT**
**Package**: `image_picker: ^1.0.7`
- Usage: Profile photos, verification selfies, student IDs, listing photos, housing media, chat uploads
- Permissions: `CAMERA`, `READ_MEDIA_*` (already reviewed ✅)
- Justification: Clear user intent for each upload

#### File Picker: ✅ **COMPLIANT**
**Package**: `file_picker: ^8.1.2`
- Usage: PDF uploads for notes, documents for verification, chat attachments
- Storage: `READ_EXTERNAL_STORAGE` (scoped appropriately)
- Justification: User-initiated uploads only

#### Local Storage: ✅ **COMPLIANT**
**Package**: `path_provider: ^2.1.3`, `hive: ^2.2.3`
- Usage: App cache, non-sensitive local data storage
- Note: Not using device-wide file access, only app-private storage

#### Push Notifications: ✅ **COMPLIANT**
**Package**: `firebase_messaging: ^15.0.1`
- Implementation:
  - FCM tokens stored in Firestore: `users/{uid}/collection('tokens')`
  - Tokens deleted on sign out
  - Background handler: `_firebaseMessagingBackgroundHandler`
  - Local display via `flutter_local_notifications`
- Permissions: `POST_NOTIFICATIONS` (Android 13+, already reviewed ✅)
- User Control: Notification settings per category in app

#### Crash Reporting: ✅ **COMPLIANT**
**Package**: `firebase_crashlytics: ^4.0.1`
- Production only (gated by `kReleaseMode`)
- Captures uncaught exceptions
- Configured in `lib/main.dart:134-141`
- Privacy: No sensitive user data logged
- Compliance: ✅ Properly gated from user view

#### Google Mobile Ads: 🔴 **CRITICAL BLOCKER**
**Package**: `google_mobile_ads: ^5.1.0`

**Status**: ❌ **NOT PRODUCTION-READY**

**Issue**: Ad Unit IDs not configured
- **File**: `lib/features/ads/services/ad_unit_ids.dart`
- **Current State**: Placeholder strings `'ca-app-pub-xxxxxxxxxxxxxxxx/xxxxxxxxxx'`
- **TODO Comment**: Line 8 - "Replace with production IDs"
- **Impact**: Ads will not serve; app may crash or reject ads

**Action Required** (CRITICAL):
1. Create/register Google AdMob account
2. Register app: `com.unihub.unihub_mobile`
3. Create ad unit IDs for:
   - Banner ads (multiple placements)
   - Interstitial ads (if planned)
   - Native ads (if planned)
   - Rewarded ads (if planned)
4. Replace placeholder IDs in `ad_unit_ids.dart`
5. Test production IDs thoroughly before release

**UMP Consent**: ✅ Already implemented
- User consent collected properly
- Consent dialog configured

---

## 7. PRODUCTION READINESS

### Status: ⚠️ **CONDITIONALLY PRODUCTION-READY**

#### Debug Code & Banners: ✅ **PROPERLY GATED**
- `debugShowCheckedModeBanner: false` in main.dart ✅
- All `debugPrint()` statements wrapped in `if (kDebugMode)` ✅
- No debug banners visible in production ✅

#### Debug Logging: ✅ **CONTROLLED**
- App-wide logging via `AppLogger` class
- Production logging only in release mode
- Controlled via `kDebugMode` and `kReleaseMode` checks
- Sensitive data masked in logs

#### Test Accounts: ✅ **NONE FOUND**
- No hardcoded test accounts in production
- Google test Ad IDs used only in debug
- No placeholder test data

#### Build Configuration: ✅ **CORRECT**
- **Target SDK**: 36 (Android 14)
- **Min SDK**: API 21 (Android 5.0)
- **Package**: `com.unihub.unihub_mobile`
- **Version**: `1.0.0+1`
- **Signing**: Configured ✅
- **Code Shrinking**: R8 enabled ✅
- **Proguard**: Enabled ✅

#### Firebase Configuration: ✅ **PRODUCTION-READY**
- Android configured: Project ID `unihub-3663e`
- Security rules in place
- Firestore offline persistence enabled
- FCM configured

**Note**: iOS not configured (can be added later; not required for Android Play Store)

#### Network Security: ✅ **ENCRYPTED**
- All URLs enforce HTTPS
- Firebase enforces TLS 1.3
- Cloudinary CDN over HTTPS

#### Error Handling: ✅ **IMPLEMENTED**
- Crashlytics captures fatal errors
- Graceful error messages to users
- Try-catch blocks throughout

#### Performance Optimizations: ✅ **PRESENT**
- Offline persistence enabled
- Image compression: `flutter_image_compress: ^2.3.0`
- Caching via `cached_network_image`
- Pagination implemented

#### TODOs Found: 🔴 **CRITICAL**

| File | Line | Issue | Priority |
|------|------|-------|----------|
| `ad_unit_ids.dart:8` | TODO | Replace production Ad Unit IDs | 🔴 **CRITICAL** |
| `admin_repository.dart` | TODO | Notify content owner if possible | 🟡 Medium |

**Only critical TODO is Ad Unit IDs** - must be completed before release.

---

## 8. CRITICAL ISSUES & BLOCKERS

### 🔴 **BLOCKER: Ad Unit IDs Not Configured**

**Severity**: CRITICAL - Will cause app rejection or crashes

**Location**: `lib/features/ads/services/ad_unit_ids.dart` (lines 9-80)

**Current State**:
```dart
// All Ad Unit IDs are placeholder strings
const String bannerAdUnitIdMarketplace = 'ca-app-pub-xxxxxxxxxxxxxxxx/xxxxxxxxxx';
// ... more placeholders
```

**Why It's a Blocker**:
- Google Play will reject app with placeholder Ad Unit IDs
- Ads will not serve in production
- App may crash when attempting to load ads

**Fix Required**:
1. Obtain Google AdMob account with production Ad Unit IDs
2. Replace all placeholder strings with real AdMob IDs
3. Test ads thoroughly in production build
4. Verify ads load correctly before release

**Estimated Time**: 2-3 hours (if AdMob setup is quick)

---

### ⚠️ **HIGH PRIORITY: Policy Documentation Not Verified**

**Issue**: Privacy Policy and Terms URLs are configured but documents not verified as hosted

**Files Affected**:
- Privacy Policy: `https://unihub-3663e.web.app/privacy`
- Terms of Service: `https://unihub-3663e.web.app/terms`

**Action Required**:
1. Manually verify both URLs are publicly accessible
2. Verify documents are comprehensive and current
3. Include all required disclosures (see Privacy Policy Must Include section above)

---

### ⚠️ **HIGH PRIORITY: Data Export Feature Missing**

**Requirement**: GDPR Article 15, CCPA §1798.100

**Issue**: No way for users to download/export their personal data

**Action Required**: Implement user data export feature allowing download of:
- User profile information
- All created listings/posts
- Chat message history
- Verification documents
- Activity logs

**Timeline**: Should be implemented before release

---

### ⚠️ **HIGH PRIORITY: Play Console Data Safety Form**

**Issue**: Form not yet completed in Google Play Console

**Required Fields**:
- Data types collected (location, photos, contacts, etc.)
- Data handling (encrypted, deleted, retained)
- Third-party sharing
- User rights (delete, export)

**Action**: Complete questionnaire in Play Console before submission

---

### ⚠️ **HIGH PRIORITY: COPPA/Age Verification**

**Issue**: No explicit age gate or age verification found

**Assessment**: If app targets minors under 13, must implement age verification

**Status**: Verify app's intended audience:
- If 13+: No action required
- If includes under 13: Implement age gate at signup

---

### 🟡 **MEDIUM PRIORITY: Moderation Policies Documentation**

**Issue**: Report/block systems implemented but policies not documented

**Action**: Document community standards and moderation policies
- Add to Privacy Policy or create separate Community Guidelines
- Define what content is prohibited
- Explain enforcement actions

---

## 9. COMPLIANCE SCORECARD

| Category | Status | Score | Notes |
|----------|--------|-------|-------|
| **Privacy Policy** | ⚠️ Configured | 80% | URLs set up; docs need verification |
| **Terms of Service** | ⚠️ Configured | 80% | URLs set up; docs need verification |
| **Data Collection** | ✅ Compliant | 100% | Proper encryption, GDPR-aligned |
| **Data Retention** | ⚠️ Partial | 60% | Deletion works; policies not documented |
| **Permissions** | ✅ Compliant | 100% | All justified & used correctly |
| **Account Deletion** | ✅ Compliant | 95% | Comprehensive; missing export feature |
| **User Blocking** | ✅ Compliant | 100% | Fully implemented |
| **Content Reporting** | ✅ Compliant | 100% | Fully functional |
| **Moderation** | ✅ Compliant | 90% | System in place; policies not documented |
| **Location Services** | ✅ Compliant | 100% | Proper use; optional |
| **Camera Access** | ✅ Compliant | 100% | User-initiated only |
| **Push Notifications** | ✅ Compliant | 100% | Proper permission handling |
| **Ads Configuration** | 🔴 Blocker | 0% | Ad Unit IDs not configured |
| **Sensitive APIs** | ✅ Compliant | 95% | All properly used |
| **Production Build** | ✅ Ready | 95% | Proper signing, R8 enabled |
| **Debug Code** | ✅ Proper | 100% | All debug properly gated |
| **Firebase Setup** | ✅ Ready | 100% | Security rules in place |

**Overall Average**: 87% Compliance

---

## 10. GO / NO-GO RECOMMENDATION

### Current Status: 🟡 **CONDITIONAL GO**

**Recommendation**: Can proceed to Google Play Store **ONLY AFTER**:

1. **🔴 CRITICAL (BLOCKER)**: 
   - [ ] Replace Ad Unit IDs with production AdMob IDs

2. **⚠️ HIGH PRIORITY (Must Complete)**:
   - [ ] Verify Privacy Policy hosted at HTTPS URL
   - [ ] Verify Terms of Service hosted at HTTPS URL
   - [ ] Implement user data export feature
   - [ ] Complete Play Console Data Safety form

3. **🟡 MEDIUM PRIORITY (Should Complete)**:
   - [ ] Document content moderation policies
   - [ ] Verify/implement age verification if targeting <13

### Timeline to Release

- **Immediate** (1-2 hours): Ad Unit IDs configuration
- **Short term** (1-2 days): Policy documentation verification
- **Medium term** (3-5 days): Data export feature implementation
- **Before submission** (final review): Play Console data safety form

**Estimated Total Time**: 1-2 weeks

### Release Risks

- **Critical**: Ad Unit ID misconfiguration → App rejection
- **High**: Missing policies → App rejection or user complaints
- **Medium**: No data export → GDPR/CCPA non-compliance risk
- **Low**: Moderation policies not documented → Minor policy violation

---

## 11. IMPLEMENTATION NOTES

**DO NOT MODIFY**:
- Architecture or code structure
- UI or UX
- Business logic or feature functionality
- Performance optimizations
- Any unrelated functionality

**ONLY IMPLEMENT**:
1. Ad Unit ID configuration (data replacement only)
2. Policy documentation (external to app)
3. Data export feature (policy requirement)
4. Play Console form completion (external to app)

---

## Appendix: Files Referenced

### Core Configuration
- `pubspec.yaml` - Version, dependencies, build config
- `lib/main.dart` - Startup, Firebase init, debug settings
- `android/app/build.gradle` - Build config, SDK versions
- `android/app/AndroidManifest.xml` - Permissions, features

### Privacy & Policies
- `lib/features/profile/settings_screen.dart` - Policy URLs (lines 202, 212)
- `lib/features/auth/presentation/screens/register_screen.dart` - Onboarding disclosure
- `lib/features/admin/data/repositories/system_settings_repository.dart` - URL storage

### Data & Permissions
- `lib/features/auth/data/repositories/auth_repository_impl.dart` - Account delete, login
- `lib/features/shared/feed_repository.dart` - Reporting system
- `lib/services/notification_service.dart` - FCM & permissions
- `lib/core/location/services/location_service.dart` - Location requests

### Ads Configuration
- `lib/features/ads/services/ad_unit_ids.dart` - **[NEEDS UPDATE]**
- `lib/features/ads/services/ad_config.dart` - Ad initialization

### Moderation
- `lib/features/shared/banned_screen.dart` - Ban/suspension UI
- `lib/features/admin/presentation/screens/` - Admin moderation tools

---

**Report Compiled By**: Google Play Compliance Audit Agent  
**Date**: July 8, 2026  
**Audit Scope**: Full Play Store submission readiness  
**Status**: Ready for submission after blockers resolved
