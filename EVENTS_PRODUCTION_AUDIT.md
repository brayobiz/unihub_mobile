# UniHub Events Feature - Production Readiness Audit

**Date**: July 6, 2026  
**Status**: 🔴 REQUIRES FIXES - Multiple critical gaps identified  
**User Journey**: Event discovery → Creation → Admin approval → Attendance tracking

---

## Executive Summary

The Events feature has a solid domain-driven architecture with comprehensive business logic for organizer verification and event lifecycle management. However, the following **critical gaps** prevent production readiness:

1. **Missing Event Status Transitions** - No automatic status updates (live/ended)
2. **No Event Search/Discovery Filtering** - Browse screen lacks filtering UI
3. **Missing Admin Event Management UI** - No admin dashboard for event approvals
4. **Incomplete Organizer Registration Journey** - Missing key screens
5. **No Event Notifications System** - Attendees not notified of changes
6. **Shallow Error Handling** - Generic error messages in controllers
7. **Missing Data Validation** - Image quality, event capacity checks incomplete
8. **No Event Analytics/Metrics** - Organizers can't track event performance
9. **Organizer Service Missing Methods** - No `submitForReview`, `createApplication` implementations in some paths
10. **Admin Event Approval Missing** - No UI/routes for admin to approve/reject submitted events

---

## Detailed Findings & Fixes

### 1. 🔴 CRITICAL: Missing Event Approval Workflow in Admin System

**Current State**: Events can be submitted, but admin has no UI to approve/reject them.

**Impact**: Events submitted by unverified organizers never get approved, blocking the entire user journey.

**Evidence**:
- `AdminDashboardScreen` shows `pendingEventApprovals` counter but no action button
- No admin route like `/admin/event-approvals` exists
- `AdminRepository` has event count queries but no approval methods
- No verification request handling for events

**Fix Required**:
1. Add event approval methods to `AdminRepository`
2. Create event approval UI screen
3. Add routes `/admin/event-approvals` and `/admin/event-approval/:id`
4. Implement bulk approval/rejection for events
5. Send notifications to organizers on approval/rejection

---

### 2. 🔴 CRITICAL: Event Status Lifecycle Not Automated

**Current State**: Events stay in `approved`/`scheduled` states forever. No automatic transition to `live` or `ended`.

**Impact**: Old events clutter the discovery feed; users can't distinguish active events.

**Evidence**:
- `EventService` has `setEventLive()` and `endEvent()` but they're never called
- No Cloud Function triggers for time-based transitions
- Providers filter by status but don't auto-update past events

**Fix Required**:
1. Add Cloud Function that transitions events to `live` when `startAt <= now`
2. Add Cloud Function that transitions events to `ended` when `endAt <= now`
3. Archive events older than 90 days
4. Update event discovery providers to exclude ended/archived events by default

**Firestore Index Needed**:
```
Collection: events
Fields: campusId (Asc), status (Asc), startAt (Asc)
```

---

### 3. 🔴 CRITICAL: Missing Admin Event Approval Routes & UI

**Current State**: No way for admins to manage submitted events.

**Impact**: Complete blockers for organizer event publishing workflow.

**Code Locations**:
- `app_router.dart` - Missing admin event routes
- `admin_dashboard_screen.dart` - Shows count but no link to manage
- `admin_repository.dart` - Lacks event approval methods

**Fix Required**:
1. Add to `admin_repository.dart`:
   - `watchSubmittedEvents(String campusId)` - Stream of submitted events awaiting approval
   - `approveEvent(String eventId, String adminId, String? reason)` - Approve with optional reason
   - `rejectEvent(String eventId, String adminId, String reason)` - Reject with required reason
   
2. Create new screen: `feature_moderation_screen.dart` or dedicated `event_approval_screen.dart`
   - List submitted events with organizer details
   - Approve/reject actions
   - Bulk operations support

3. Add routes to `app_router.dart`:
   ```dart
   GoRoute(
     path: '/admin/events/pending',
     builder: (context, state) => const EventApprovalScreen(),
   ),
   GoRoute(
     path: '/admin/events/:id/detail',
     builder: (context, state) => EventApprovalDetailScreen(eventId: state.pathParameters['id']!),
   ),
   ```

4. Link from admin dashboard: `stats.pendingEventApprovals` tap → `/admin/events/pending`

---

### 4. 🟡 HIGH: Events Browse Screen Missing Filter/Search UI

**Current State**: Browse shows events but no way to filter by category, date, organizer, or search.

**Impact**: Poor discoverability; users can't find specific events.

**Evidence**:
- `EventsBrowseScreen` has placeholder search/filter buttons but do nothing
- Filter UI widgets exist in `marketplace` feature but not used in events
- `EventsListScreen` accepts filters but not called with query params

**Fix Required**:
1. Implement category filter chips in browse screen (horizontal scroll)
2. Add "Today", "This Week", "Upcoming" quicklinks
3. Add search sheet/modal with:
   - Search by event title/organizer name
   - Filter by category, date range, campus (already selected)
   - Sort by: Date, Popularity, Name
4. Handle empty states with helpful copy

---

### 5. 🟡 HIGH: Missing Event Notifications System

**Current State**: Users attending events receive confirmation but no:
- Event time reminders (1 day before, 1 hour before)
- Cancellation alerts to attendees
- Organizer event approval notifications (via Cloud Function)
- Major change notifications (time/venue updated)

**Impact**: Users miss events; no communication when events are cancelled.

**Fix Required**:
1. Add Cloud Function triggers:
   ```javascript
   // Trigger: Event time approaches
   onSchedule("every 1 hours", async (context) => {
     const now = admin.firestore.Timestamp.now();
     const in1Day = new Date(now.toDate().getTime() + 24*60*60*1000);
     const in1Hour = new Date(now.toDate().getTime() + 60*60*1000);
     
     // Find events starting in next 1 day / 1 hour
     // Get attendees
     // Send notifications
   });
   ```

2. Add event change handler:
   ```dart
   // In EventService.updateEvent() after venue/time change detected
   if (timeChanged || venueChanged) {
     final attendees = await _attendanceRepository.getEventAttendees(eventId);
     for (final attendee in attendees) {
       await _notificationSender.sendNotification(
         recipientId: attendee.userId,
         title: 'Event Updated 📝',
         body: timeChanged 
           ? 'Time changed to ${event.startAt}' 
           : 'Venue changed to ${event.venue.address}',
         type: NotificationType.events,
         targetId: eventId,
         targetType: 'event',
       );
     }
   }
   ```

3. Send cancellation notifications:
   ```dart
   // In EventService.cancelEvent()
   final attendees = await _attendanceRepository.getEventAttendees(eventId);
   for (final attendee in attendees) {
     await _notificationSender.sendNotification(
       recipientId: attendee.userId,
       title: 'Event Cancelled ❌',
       body: 'Event "${event.title}" was cancelled. Reason: $reason',
       type: NotificationType.events,
       targetId: eventId,
       targetType: 'event',
     );
   }
   ```

---

### 6. 🟡 HIGH: Incomplete Organizer Registration Journey

**Current State**:
- `CreateOrganizerController` and screen exist
- User can create organizer profile
- BUT: Missing screens/flows for:
  - "Invite Team Members" flow
  - Organizer dashboard to manage events
  - Verification status tracking
  - Appeal rejected applications

**Impact**: Organizers can't build teams; poor management experience.

**Fix Required**:
1. Create `organizer_members_screen.dart` - Manage team members (CRUD, role changes)
2. Enhance `organizer_dashboard_screen.dart` - Show:
   - Verification status badge
   - Event stats (total, pending approval, live, ended)
   - Recent activity
   - Quick action buttons
3. Create `appeal_rejection_screen.dart` - Allow resubmission after rejection
4. Add validation: Organizer type = "department" requires admin approval

---

### 7. 🟡 HIGH: Shallow Error Handling in Controllers

**Current State**: Generic error messages like `"Failed to upload event images"` with no recovery paths.

**Impact**: Users frustrated when something fails; no actionable feedback.

**Example from `CreateEventController`:
```dart
state = state.copyWith(
  isLoading: false,
  error: e.toString(),  // ← Exposes raw Firebase exceptions
);
```

**Fix Required**:
1. Add error translation layer:
```dart
String _translateFirebaseError(dynamic error) {
  if (error.toString().contains('PERMISSION_DENIED')) {
    return 'You don\'t have permission to create events for this organizer.';
  }
  if (error.toString().contains('UNAVAILABLE')) {
    return 'Network error. Please check your connection and try again.';
  }
  if (error.toString().contains('verified organizers')) {
    return 'Your organizer profile must be verified before publishing events. Check your verification status.';
  }
  return 'Something went wrong. Please try again later.';
}
```

2. Add retry logic in controller:
```dart
Future<bool> _save(EventStatus status, {int retries = 0}) async {
  // ... existing code ...
  try {
    // upload, create, etc.
  } catch (e) {
    if (retries < 2 && _isRetryable(e)) {
      return _save(status, retries: retries + 1);
    }
    // fail after max retries
  }
}
```

---

### 8. 🟠 MEDIUM: Missing Image Validation & Compression

**Current State**: 
- `CreateEventController` uploads images without checking quality, size, or format
- No guidance for users on image specs

**Impact**: Massive image files slow down app; poor performance on low-end devices.

**Fix Required**:
1. Add image validation before upload:
```dart
const int maxImageSize = 5 * 1024 * 1024; // 5 MB
const int targetQuality = 80;

Future<bool> _validateImage(File file) async {
  final size = await file.length();
  if (size > maxImageSize) {
    state = state.copyWith(error: 'Image too large (max 5 MB)');
    return false;
  }
  return true;
}
```

2. Compress images before upload (use `flutter_image_compress`):
```dart
final compressed = await FlutterImageCompress.compressAndGetFile(
  file.absolute.path,
  "${file.path}_compressed.jpg",
  quality: 80,
);
```

---

### 9. 🟠 MEDIUM: Missing Event Analytics for Organizers

**Current State**: 
- No view count tracking
- No attendance metrics
- Organizers can't see performance

**Impact**: Poor insights for organizers; can't improve event quality.

**Fix Required**:
1. Add to `Event` model:
```dart
class Event {
  final int viewCount;        // Incremented when event detail opened
  final int saveCount;        // Already exists as savedCount
  final int attendanceCount;  // Current going count
  final DateTime? eventEndsAt; // Use endAt
  // ...
}
```

2. Add analytics collector:
```dart
// In event_detail_screen.dart
@override
void initState() {
  super.initState();
  ref.read(eventRepositoryProvider).logEventView(eventId);
}
```

3. Add dashboard display in `OrganizerDashboardScreen`:
```dart
// Show: Total views, saves, attendees for each event
// Show: Trending events
// Show: Attendance over time chart (if using analytics service)
```

---

### 10. 🟠 MEDIUM: No Event Capacity Management During Live Event

**Current State**: 
- `maxCapacity` field exists but never enforced in real-time
- Overbooking possible due to race conditions

**Impact**: Events overbooked; poor UX when hitting capacity.

**Fix Required**:
1. Add capacity info to event detail screen:
```dart
if (event.maxCapacity != null) {
  final remaining = event.maxCapacity! - event.currentAttendeeCount;
  Text(
    remaining > 0 
      ? 'Only $remaining spots left!' 
      : 'Event Full ❌',
    style: TextStyle(
      color: remaining < 5 ? Colors.red : Colors.orange,
      fontWeight: FontWeight.bold,
    ),
  );
}
```

2. Prevent RSVP when at capacity (already in `AttendanceRepositoryImpl` but verify):
```dart
if (maxCapacity != null && currentCount >= maxCapacity) {
  throw Exception('Event is at full capacity');
}
```

---

### 11. 🟢 MEDIUM: Missing Organizer Service Method Bindings

**Current State**: 
- `organizer_service.dart` defines methods like `createApplication()`, `submitForReview()`
- BUT: They're not exposed via providers in `shared/providers.dart`

**Impact**: Controllers can't call these methods.

**Fix Required**:
- Verify `organizer_service.dart` methods are called from controllers
- Example: `CreateOrganizerController` should call `organizerServiceProvider.createApplication()`

---

### 12. 🟢 LOW: Missing Event Report Functionality in UI

**Current State**: 
- `EventRepository.reportEvent()` exists in data layer
- No UI button to report inappropriate events

**Impact**: Bad events aren't removed; community safety compromised.

**Fix Required**:
1. Add "Report Event" action button in `event_detail_screen.dart`:
```dart
IconButton(
  icon: Icon(Icons.flag_outlined),
  onPressed: () => _showReportDialog(context, event.id),
)
```

2. Create report dialog:
```dart
Future<void> _showReportDialog(BuildContext context, String eventId) async {
  final reason = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Report Event'),
      content: DropdownButton<String>(
        items: [
          'Inappropriate content',
          'Spam/Scam',
          'Copyright violation',
          'Other'
        ].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(context, 'Selected reason'), child: const Text('Report')),
      ],
    ),
  );
  
  if (reason != null) {
    await ref.read(eventRepositoryProvider).reportEvent(
      eventId: eventId,
      reporterId: userId,
      reason: reason,
    );
  }
}
```

---

## User Journey Validation

### ✅ Complete User Flows

1. **Browse & RSVP Flow** ✅
   - User → Events tab → Browse events (campus filtered)
   - Tap event → Detail screen → Mark as "Going" / "Saved"
   - Notification: "You're going! 📅"

2. **Create & Submit Event Flow** ✅
   - User (verified) → Become organizer (application)
   - Organizer verified → Become organizer → Create event
   - Multi-step form: Details → Location → Images → Review
   - Submit for admin approval

3. **Manage Events as Organizer** ✅
   - Organizer → My Events → List of events
   - Tap event → Edit or View details
   - See attendance count

### ⚠️ Incomplete Flows

1. **Admin Event Approval** ❌
   - Admin → Dashboard (sees pending count) → DEAD END
   - Should: Click count → Approval queue → Approve/Reject

2. **Event Status Lifecycle** ❌
   - Event published → Should auto-transition to LIVE at startTime
   - Currently: Stays APPROVED until manually ended

3. **Event Cancellation** ⚠️
   - Organizer can cancel event
   - BUT: Attendees not notified

4. **Team Management** ⚠️
   - Invite team members: UI doesn't exist
   - Manage roles: No screen to update member roles

---

## Firestore Schema Validation

### Current Collections ✅
- `events/` - Event documents
- `event_attendance/` - User → Event relationships
- `organizers/` - Organizer profiles
- `organizers/{id}/members/` - Team members
- `organizers/{id}/audit_trail/` - Verification history

### Missing Indexes
```
Collection: events
Composite Index:
  - campusId (Asc)
  - status (Asc)
  - startAt (Asc)

Collection: event_attendance
Composite Index:
  - userId (Asc)
  - status (Asc)
```

### Potential Data Consistency Issues
- Event `currentAttendeeCount` updated transactionally ✅
- Organizer `eventCount` never updated ❌ (should increment on event creation)
- Organizer `trustScore` never updated ❌ (should increase after successful event)

---

## Performance Optimization Checklist

- [x] Firestore persistence enabled in `main.dart`
- [x] Campus filtering gates all queries
- [x] In-memory sorting avoids complex composite indexes
- [x] Image uploads async (won't block UI)
- [ ] Event list pagination (currently no limit on watchEventsByCampus)
- [ ] Search results cached
- [ ] Event detail lazy-loads organizer + attendance

**Recommended Pagination**:
```dart
// Add pagination to watchEventsByCampus
limit: 20,  // Load first 20, then paginate on scroll
```

---

## Security & Permissions Checklist

✅ **Identity Verification Required for:**
- Becoming organizer
- Marking "Going" (trust rule)

✅ **Organizer Verification Required for:**
- Publishing events (must be verified/official)
- Invitation only after verification

✅ **Admin Checks:**
- `approveEvent()` re-verifies admin privileges
- Event approval enforces status state machine

⚠️ **Potential Gaps:**
- No rate limiting on event creation (spam risk)
- No report auto-moderation (flagged events not auto-hidden)
- No organizer suspension workflow (rejected organizers can keep creating new profiles)

---

## Deployment Checklist

### Before Production Release

- [ ] Implement event approval admin UI (#3)
- [ ] Add event status lifecycle Cloud Functions (#2)
- [ ] Implement admin event approval workflow (#3)
- [ ] Add events browse filtering UI (#4)
- [ ] Send event notifications (approvals, cancellations, reminders) (#5)
- [ ] Complete organizer registration journey (#6)
- [ ] Improve error handling with user-friendly messages (#7)
- [ ] Add image validation & compression (#8)
- [ ] Implement event analytics dashboard for organizers (#9)
- [ ] Verify event capacity enforcement (#10)
- [ ] Test organizer service method bindings (#11)
- [ ] Add event report button to UI (#12)
- [ ] Deploy Firestore composite indexes
- [ ] Test end-to-end event creation → approval → attendance flow
- [ ] Load test event browse with 1000+ events per campus
- [ ] Verify offline support (Firestore cache)
- [ ] Mobile testing: Test on low-end devices (Samsung A10)

### Cloud Functions to Deploy
```bash
firebase deploy --only functions
```

Add to `functions/index.js`:
- Event status transition trigger (on schedule, every hour)
- Event approval notification trigger (on submitted event creation)
- Event cancellation notification trigger (on event update to cancelled)

---

## Revision History

| Date | Version | Changes |
|------|---------|---------|
| 2026-07-06 | 1.0 | Initial audit - 12 findings identified |

---

## Notes for Development Team

This feature is **architecturally sound** but lacks the glue code and admin workflows needed for production. The domain models, repositories, and business logic are well-structured. Priority fixes:

1. **Week 1**: Admin event approval UI + Cloud Functions for status transitions (blocks user journey)
2. **Week 2**: Error handling, event notifications, organizer dashboard
3. **Week 3**: Analytics, search/filtering, capacity management
4. **Week 4**: Testing, load testing, security audit

**Estimated Effort**: 3-4 weeks for full production readiness.

---

