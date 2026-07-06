rateseeg# UniHub Verification System Architecture & Functionality

## Overview

UniHub implements a **multi-layered trust verification system** to establish user credibility across the platform. The system combines three verification pathways:

1. **Platform Verification** (Identity + Student Status) - for general platform access & safety
2. **Professional Verification** - for marketplace roles (seller, tutor, plug, etc.)
3. **Trust Scoring** - calculated reputation based on activity & verification status

---

## System Architecture

### Feature Structure
```
lib/features/trust/
├── domain/
│   ├── models/
│   │   ├── student_verification.dart      # Student ID verification
│   │   ├── identity_verification.dart     # Government ID + Selfie
│   │   ├── verification_application.dart  # Professional role applications
│   │   ├── professional_role.dart         # Enum: seller, tutor, plug, etc.
│   │   └── badge.dart                     # Visual badges for verified status
│   └── repositories/
│       └── trust_repository.dart          # Abstract interface
├── data/
│   └── repositories/
│       └── trust_repository_impl.dart     # Firestore implementation
└── presentation/
    ├── providers/
    │   └── trust_providers.dart           # Riverpod state management
    └── screens/
        ├── trust_center_screen.dart       # Main hub (all verifications)
        ├── student_verification_screen.dart
        ├── identity_verification_screen.dart
        └── professional_verification_screen.dart
```

### Data Storage (Firestore)

**Collections:**

```
├── users/{uid}                           # Main user doc
│   ├── isEmailVerified (bool)
│   ├── isPhoneVerified (bool)
│   ├── isStudentVerified (bool)
│   ├── isIdentityVerified (bool)
│   ├── identityStatus (string)            # 'none'|'pending'|'approved'|'rejected'
│   └── verifiedRoles (array)              # ['seller', 'housePlug', ...]
│
├── student_verifications/{uid}            # One per user
│   ├── userId
│   ├── studentIdUrl (Firebase Storage URL)
│   ├── status (enum)                      # pending|underReview|approved|rejected|expired|resubmissionRequested
│   ├── rejectionReason (optional)
│   ├── submittedAt (timestamp)
│   └── verifiedAt (timestamp)
│
├── identity_verifications/{uid}           # One per user
│   ├── userId
│   ├── idDocumentUrl (Firebase Storage - private)
│   ├── selfieUrl (Firebase Storage - private)
│   ├── status (enum)                      # none|pending|underReview|approved|rejected|resubmissionRequested
│   ├── rejectionReason (optional)
│   ├── submittedAt (timestamp)
│   └── verifiedAt (timestamp)
│
└── verification_applications/{appId}     # One per professional application
    ├── userId
    ├── role (enum)                        # seller|housePlug|tutor|serviceProvider|technician|business
    ├── status (enum)                      # pending|underReview|approved|rejected|expired|resubmissionRequested
    ├── fullName
    ├── phoneNumber
    ├── idDocumentUrl (optional, Firebase Storage)
    ├── selfieUrl (optional, Firebase Storage)
    ├── metadata (map)                     # Role-specific requirements
    ├── createdAt (timestamp)
    ├── updatedAt (timestamp)
    └── rejectionReason (optional)
```

**File Storage (Firebase Storage):**
```
gs://unihub-3663e.appspot.com/
├── verifications/student/{filename}      # Public student IDs
├── verifications/identity/ids/{filename}  # Private (isPrivate: true)
├── verifications/identity/selfies/{filename}  # Private (isPrivate: true)
└── verifications/professional/{filename} # Professional documents
```

---

## Verification Types

### 1. Student Verification
**Purpose:** Confirm university enrollment  
**Status Enum:** `pending`, `underReview`, `approved`, `rejected`, `expired`, `resubmissionRequested`

**Data Model:**
```dart
StudentVerification {
  String id;
  String userId;
  StudentVerificationStatus status;
  String studentIdUrl;          // Student ID/transcript
  String? rejectionReason;
  DateTime submittedAt;
  DateTime? verifiedAt;
}
```

**Submission Flow (StudentVerificationScreen):**
1. User picks student ID image (80% quality compression)
2. Upload to Firebase Storage: `verifications/student/student_id_{uid}_{timestamp}`
3. Submit to Firestore `student_verifications/{uid}` with `status: pending`
4. Notification sent to admins via `notifyAdmins()`

**Verification Status in UI:**
- ✅ **Approved** → Green badge "Student" with school icon
- ⏳ **Pending/Under Review** → Yellow state, waiting indicator
- ❌ **Rejected** → Red with rejection reason shown
- 🔄 **Resubmission Requested** → User must resubmit

---

### 2. Identity Verification
**Purpose:** Confirm real identity via government-issued ID + biometric match  
**Status Enum:** `none`, `pending`, `underReview`, `approved`, `rejected`, `resubmissionRequested`

**Data Model:**
```dart
IdentityVerification {
  String userId;
  IdentityVerificationStatus status;
  String idDocumentUrl;           // ID photo (private)
  String selfieUrl;               // Face photo (private)
  String? rejectionReason;
  DateTime submittedAt;
  DateTime? verifiedAt;
}
```

**Submission Flow (IdentityVerificationScreen):**
1. User picks ID document from gallery (70% quality compression)
2. User takes selfie from camera (70% quality)
3. Upload both sequentially with progress tracking (0.5 + 0.5):
   - ID → `verifications/identity/ids/{filename}` (private)
   - Selfie → `verifications/identity/selfies/{filename}` (private)
4. Submit to Firestore `identity_verifications/{uid}` with `status: pending`
5. Update user document: `users/{uid}.identityStatus = 'pending'`
6. Notify admins: "New Identity Verification 🛡️"

**Key Differences from Student Verification:**
- **Two documents** (ID + Selfie) vs. single document
- **Private storage** (`isPrivate: true`) for sensitive biometric data
- Updates user profile with `identityStatus` field
- Stronger verification signal (30 trust points vs. 20)

---

### 3. Professional Verification
**Purpose:** Verify role-specific qualifications (seller, tutor, house plug, etc.)  
**Status Enum:** `pending`, `underReview`, `approved`, `rejected`, `expired`, `resubmissionRequested`

**Data Model:**
```dart
VerificationApplication {
  String id;                      // UUID
  String userId;
  ProfessionalRole role;          // seller|housePlug|tutor|serviceProvider|technician|business
  VerificationStatus status;
  String fullName;
  String phoneNumber;
  String? idDocumentUrl;          // May be required if user not identity verified
  String? selfieUrl;
  Map<String, dynamic> metadata;  // Role-specific data (e.g., certification #, business license)
  DateTime createdAt;
  DateTime? updatedAt;
  String? rejectionReason;
}
```

**Submission Flow (ProfessionalVerificationScreen):**
1. Select professional role (seller, tutor, plug, etc.)
2. Fill form: fullName, phoneNumber (pre-filled from profile)
3. If user not identity verified:
   - Must upload ID document
   - Must take selfie
   - Used for KYC verification before role approval
4. Generate UUID for application ID
5. Submit to Firestore `verification_applications/{appId}`
6. Notify admins: "New Professional Application 💼"

**Metadata Format (Extensible by Role):**
```dart
// Seller role
metadata: {
  'categoryFocus': 'electronics',
  'avgPriceRange': '100-500',
}

// Tutor role
metadata: {
  'subject': 'Mathematics',
  'qualification': 'BSc',
  'experience': '3 years',
}

// House Plug role
metadata: {
  'apartmentsManaged': 5,
  'yearsExperience': 2,
}
```

**Professional Roles Enum:**
```dart
enum ProfessionalRole {
  seller,              // Marketplace seller → "Verified Seller"
  housePlug,           // Property manager → "Verified House Plug"
  tutor,               // Academic help → "Verified Tutor"
  serviceProvider,     // Services → "Verified Service Provider"
  technician,          // Tech repair → "Verified Technician"
  business;            // Business account → "Verified Business"
}
```

---

## Trust Score Calculation

**Formula (Deterministic, 0-100 scale):**

```dart
double calculatedTrustScore {
  double score = 0.0;

  // 1. Foundational Verifications (50%)
  if (isIdentityVerified)      score += 30.0;  // Government ID ← Strongest signal
  if (isStudentVerified)       score += 20.0;  // Campus enrollment

  // 2. Professional Standing (15%)
  score += (verifiedRoles.length.clamp(0, 3) * 5.0);  // +5 per unique role (max 15)

  // 3. Platform Activity & Reputation (25%)
  score += (profileCompletion * 10.0);              // Profile % → 0-10 points
  score += (completedSalesCount.clamp(0, 5) * 2.0);  // Deals → 0-10 points
  score += (resourcesSharedCount.clamp(0, 5) * 1.0); // Resources → 0-5 points

  // 4. Community Feedback (10%)
  if (ratingsCount >= 3) {  // Requires 3+ ratings for credibility
    if (averageRating >= 4.5)      score += 10.0;
    else if (averageRating >= 4.0) score += 7.0;
    else if (averageRating >= 3.0) score += 3.0;
  }

  // 5. Bonus Reputation (Legacy system, capped at 20%)
  score += (reputationPoints.clamp(0, 20));

  return score.clamp(0.0, 100.0);
}
```

**Profile Completion Score (0-1.0):**
- Photo ✓
- Cover photo ✓
- Bio ✓
- Username ✓
- University ✓
- Course ✓
- Year of study ✓
- Skills ✓
- Interests ✓
- Social links ✓
(10 criteria total)

**Badge System:**

Automatically awarded to users based on verification status:
```dart
enum BadgeType {
  verification,   // Platform identity badges
  professional,   // Professional role badges
  achievement,    // Activity milestones (Top Seller: 10+ sales)
  community,      // Social standing
  feature,        // Feature-specific
}

// Auto-generated badges:
AppBadge.identityVerified()  → "ID Verified" (Blue badge icon)
AppBadge.studentVerified()   → "Student" (Green school icon)
// + one per verifiedRole (e.g., "Verified Seller", "Verified Tutor")
// + milestones (e.g., "Top Seller" when completedSalesCount >= 10)
```

---

## State Management (Riverpod Providers)

**Repository Layer:**
```dart
final trustRepositoryProvider = Provider<TrustRepository>((ref) {
  return TrustRepositoryImpl(
    ref.watch(firestoreProvider),
    ref.watch(notificationServiceProvider),  // For admin notifications
  );
});
```

**Stream Providers (Real-time Listeners):**
```dart
// Current user's applications (all roles)
final userApplicationsProvider = StreamProvider.autoDispose<List<VerificationApplication>>((ref) {
  final user = ref.watch(appUserProvider).valueOrNull;
  if (user == null) return Stream.value([]);
  return ref.watch(trustRepositoryProvider).watchUserApplications(user.uid);
});

// Student verification status
final studentVerificationProvider = StreamProvider.autoDispose<StudentVerification?>((ref) {
  final user = ref.watch(appUserProvider).valueOrNull;
  if (user == null) return Stream.value(null);
  return ref.watch(trustRepositoryProvider).watchStudentVerification(user.uid);
});

// Identity verification status
final identityVerificationProvider = StreamProvider.autoDispose<IdentityVerification?>((ref) {
  final user = ref.watch(appUserProvider).valueOrNull;
  if (user == null) return Stream.value(null);
  return ref.watch(trustRepositoryProvider).watchIdentityVerification(user.uid);
});

// Check if user has a specific role verified
final isRoleVerifiedProvider = Provider.autoDispose.family<bool, ProfessionalRole>((ref, role) {
  final user = ref.watch(appUserProvider).valueOrNull;
  if (user == null) return false;
  return user.verifiedRoles.contains(role.name);
});

// Professional application by role
final applicationByRoleProvider = StreamProvider.autoDispose.family<VerificationApplication?, ProfessionalRole>((ref, role) {
  return ref.watch(userApplicationsProvider.stream).map((applications) {
    try {
      return applications.firstWhere((app) => app.role == role);
    } catch (_) {
      return null;
    }
  });
});
```

---

## Repository Methods

**TrustRepository Interface:**
```dart
abstract class TrustRepository {
  // Professional
  Future<void> submitProfessionalApplication(VerificationApplication application);
  Future<VerificationApplication?> getLatestApplication(String userId, ProfessionalRole role);
  Stream<List<VerificationApplication>> watchUserApplications(String userId);

  // Student
  Future<void> submitStudentVerification(String userId, String studentIdUrl);
  Future<StudentVerification?> getStudentVerification(String userId);
  Stream<StudentVerification?> watchStudentVerification(String userId);

  // Identity
  Future<void> submitIdentityVerification(String userId, String idUrl, String selfieUrl);
  Future<IdentityVerification?> getIdentityVerification(String userId);
  Stream<IdentityVerification?> watchIdentityVerification(String userId);

  // Reputation
  Future<void> updateReputation(String userId, Map<String, dynamic> delta);
}
```

**Key Implementation Details:**
- Applications sorted **in memory** by `createdAt` to avoid composite Firestore indices
- Notifications sent via `NotificationSender` interface (admin alert + routing)
- Identity submission also updates user profile: `users/{uid}.identityStatus`

---

## UI Screens & User Flows

### Trust Center Screen
**Path:** `/trust-center`  
**Purpose:** Central hub for all verification status & actions

**Sections:**
1. **Trust Score Breakdown**
   - Visual score (0-100)
   - Tap to see detailed score calculation
   - Lists contributing factors

2. **Platform Verification**
   - Student verification card
     - Status badge (none/pending/approved/rejected)
     - Upload button if not started
     - Resubmit option if rejected
   - Identity verification card
     - Status badge
     - Same actions as student

3. **Professional Verification**
   - Cards for each role (Seller, Tutor, Plug, etc.)
   - Current application status (if any)
   - "Apply" button if not applied
   - "Reapply" if rejected

4. **Badges Display**
   - Visual grid of earned badges
   - Verification badges (Identity, Student)
   - Professional badges (Seller, Tutor, etc.)
   - Achievement badges (Top Seller, etc.)

### Student Verification Screen
**Path:** `/trust/student-verification`

**UX Flow:**
1. Instructions: "Upload your student ID or transcript"
2. Image picker button
3. Preview of selected image
4. "Submit" button (disabled until image selected)
5. Upload progress bar
6. Success/error feedback via SnackBar

### Identity Verification Screen
**Path:** `/trust/identity-verification`

**UX Flow:**
1. Two-step process with instructions
2. **Step 1: ID Document**
   - Gallery picker
   - Preview card
3. **Step 2: Selfie**
   - Camera picker (camera source only)
   - Preview card
4. **Submit Button** (disabled until both images selected)
5. Dual progress bar (0-50% for ID, 50-100% for selfie)

### Professional Verification Screen
**Path:** `/trust/professional/{role}`

**UX Flow:**
1. Role header (Seller, Tutor, etc.)
2. Form validation
3. **Basic Info**
   - Full name (pre-filled from profile)
   - Phone number (pre-filled)
4. **Identity Check** (if user not identity verified)
   - Upload ID document
   - Take selfie
5. **Role-Specific Questions** (metadata form)
   - Fields vary by role
6. **Submit** button with loading state

---

## Integration Points

### 1. AppUser Model
**Verification Fields:**
```dart
class AppUser {
  bool isEmailVerified;           // Email confirmation
  bool isPhoneVerified;           // Phone OTP
  bool isStudentVerified;         // Student ID approval
  bool isIdentityVerified;        // Government ID approval
  String identityStatus;          // 'none'|'pending'|'approved'|'rejected'
  List<String> verifiedRoles;     // e.g., ['seller', 'housePlug']

  // Computed getters
  bool get isVerified => isIdentityVerified || verifiedRoles.isNotEmpty;
  bool get isVerifiedSeller => verifiedRoles.contains('seller');
  double get displayTrustScore => calculatedTrustScore;
  List<AppBadge> get activeBadges => [...]; // Generated from verification status
}
```

**Watched via:**
```dart
final appUserProvider = StreamProvider<AppUser?>((ref) { /* ... */ });
```

### 2. Marketplace Integration
**Seller Verification Check:**
```dart
// In marketplace screens:
if (user.isVerifiedSeller) {
  // Show "Verified Seller" badge
}
```

### 3. Housing/Plug System
**Plug Verification Check:**
```dart
if (user.isVerifiedPlug) {
  // Show plug-specific UI (viewing requests, verified badge)
}
```

### 4. Chat/Messaging
**Trust Display:**
```dart
// In chat bubbles, seller profiles, etc.
user.activeBadges.forEach((badge) {
  // Display badge icon + label
});
```

### 5. Admin Backend
**Verification Queue:**
- Cloud Functions listen to `verification_applications` collection
- Admin dashboard receives notifications
- Admins approve/reject via Firestore updates (in admin panel, not visible here)
- User notified when status changes

---

## Security Considerations

### File Privacy
```dart
// Student ID (semi-public - visible to admins)
uploadFile(path: 'verifications/student', isPrivate: false)

// Identity documents (strictly private - admin access only)
uploadFile(path: 'verifications/identity/ids', isPrivate: true)
uploadFile(path: 'verifications/identity/selfies', isPrivate: true)
```

### Data Sensitivity
- Biometric data (selfies) never exposed to client unless user owns it
- Storage rules enforce role-based access:
  - Admins can download any verification file
  - Users can view their own submissions
  - Public cannot access verification documents

### Server-Side Validation (Backend)
- Cloud Functions must validate:
  - Image dimensions & file type
  - Document vs. selfie authenticity (future ML)
  - Status transitions (only admins can approve)
  - Rate limiting on resubmissions

---

## Verification Status Transitions

### Student Verification States
```
none → pending ─→ underReview ─→ approved
                              └─→ rejected ─→ resubmissionRequested ─→ pending
                                          └─→ expired
```

### Identity Verification States
```
none → pending ─→ underReview ─→ approved
                              └─→ rejected ─→ resubmissionRequested ─→ pending
```

### Professional Application States
```
pending ─→ underReview ─→ approved
                       └─→ rejected ─→ resubmissionRequested ─→ pending
                       └─→ expired
```

---

## API Endpoints & Listeners

### Submission Notifications (via NotificationService)
```dart
await _notificationSender!.notifyAdmins(
  title: 'New Student Verification 🎓',
  body: 'A user has submitted their student ID for verification.',
  route: '/admin/verifications',
);
```

### Firestore Listeners (Real-Time)
```dart
// Applications change → UI updates instantly
watchUserApplications(userId)  // returns Stream<List<VerificationApplication>>

// Student status changes → UI updates instantly
watchStudentVerification(userId)  // returns Stream<StudentVerification?>

// Identity status changes → UI updates instantly
watchIdentityVerification(userId)  // returns Stream<IdentityVerification?>
```

### Offline Behavior
- Firestore offline persistence enabled (see `main.dart`)
- Verification status reads work offline
- Submissions queue when offline, sync when online

---

## Testing Scenarios

### Test Case 1: Student Verification Flow
1. Navigate to Trust Center
2. Tap "Verify Student Status"
3. Select student ID image
4. Tap submit
5. ✅ Should show "pending" state
6. ✅ Admin should receive notification

### Test Case 2: Identity + Professional Verification
1. Complete identity verification first (2 images)
2. Navigate to professional verification
3. Select role (Seller)
4. Form should be pre-filled with name/phone
5. ID & selfie not required (already verified)
6. Fill role metadata
7. ✅ Submit should create application

### Test Case 3: Trust Score Calculation
1. User with:
   - Identity verified (30 pts)
   - Student verified (20 pts)
   - Seller role verified (5 pts)
   - 60% profile completion (6 pts)
   - 3 completed sales (6 pts)
   - 10 resources shared (5 pts)
   - 4.5★ rating with 5 reviews (10 pts)
2. ✅ Score = 30+20+5+6+6+5+10 = **82/100**

### Test Case 4: Badge Display
1. After identity approval
   - Show "ID Verified" badge (blue)
2. After student approval
   - Show "Student" badge (green)
3. After seller approval
   - Show "Verified Seller" badge (blue checkmark)
4. After 10 sales
   - Show "Top Seller" badge (orange star)

---

## Future Enhancements

- **ML-Based Verification:** Image liveness detection (selfie is real person)
- **Document OCR:** Automatic text extraction from ID documents
- **Blockchain Credentials:** Store verifications on blockchain for portability
- **Reputation API:** Third-party integrations (credit checks, background verification)
- **Time-Bound Verification:** Annual recertification for professional roles
- **Batch Admin Review:** Bulk approve/reject in admin dashboard
- **Verification Analytics:** Dashboard showing acceptance rates, common rejections

