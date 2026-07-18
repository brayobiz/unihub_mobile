# Ulify Events Module Architecture

## 1. Overview
The Events module provides a campus-centric platform for students to discover and organize activities. It strictly enforces a hierarchical ownership model: **User -> Organizer Profile -> Event**.

## 2. Core Components

### Domain Models
- **Organizer**: Public campus identity (Club, Dept, etc.) with `trustScore` and `verificationStatus`.
- **OrganizerMember**: Represents membership in an organization with roles (`Owner`, `Admin`, `Editor`).
- **Event**: Scheduled activity with lifecycle states (`Draft`, `Submitted`, `Approved`, `Live`, `Ended`, `Archived`).
- **EventAttendance**: Link between User and Event with statuses (`Saved`, `Going`).

### Repositories
- **OrganizerRepository**: CRUD for profiles and membership.
- **EventRepository**: Fetching and filtering events by campus, category, and status.
- **AttendanceRepository**: Manages user participation using Firestore Transactions for data integrity.

### Services
- **OrganizerService**: Business logic for membership management and verification workflows.
- **EventService**: Enforces publishing rules (only verified organizers can publish) and major change notification triggers.

## 3. Firestore Schema

- `organizers/`: Profile documents.
  - `members/`: (Sub-collection) Team members.
  - `audit_trail/`: (Sub-collection) Verification history.
- `events/`: Primary event documents.
- `event_categories/`: Global configuration for categories.
- `event_attendance/`: Relational mapping of users to events (`userId_eventId`).

## 4. Security & Permissions

| Role | Actions |
| :--- | :--- |
| **Student** | Browse, RSVP, Save, Report, Follow Organizer. |
| **Editor** | Create Drafts, Edit assigned Organizer events. |
| **Admin** | Invite members, Manage Organizer Profile, Submit for Review. |
| **Owner** | All of above + Role Management + Delete Organizer. |
| **Ulify Admin** | Approve/Reject/Suspend Organizers and Events. |

## 5. Integration Points

- **Notification System**: Consumes domain events from the service layer.
- **Campus Maps**: Renders `MarkerType.event` using standardized `LocationData`.
- **Trust Engine**: Updates organizer and owner scores upon successful verification and event completion.
- **Homepage**: Consumes `homepageEventsProvider` for time-aware relevance ranking.

## 6. Performance Optimization
- **Campus Partitioning**: All queries are gated by `campusId`.
- **Composite Indexes**: Optimized for status + date filtering.
- **Skeleton Loading**: Consistent UI performance during cold starts.
- **Lazy Fetching**: Event detail pages only load necessary context (organizer, attendance) when mounted.
