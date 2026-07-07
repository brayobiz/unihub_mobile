# Firestore Required Composite Indexes

To ensure the app functions correctly in production, the following composite indexes must be created in the Firebase Console under **Firestore Database > Indexes > Composite**.

---

## User Search (Case-Insensitive)
| Collection | Fields | Query Usage |
|------------|--------|-------------|
| `users` | `fullNameLower` (Asc), `usernameLower` (Asc), `email` (Asc) | Global Student Search |

> **Note**: If you receive a "Query requires an index" error in the logs, Firestore will provide a direct link to create the necessary index.

---

## Marketplace Listings (`listings`)

| Index Fields | Query Usage |
|--------------|-------------|
| `status` (Asc), `createdAt` (Desc) | Main marketplace browse (Newest) |
| `status` (Asc), `price` (Asc) | Marketplace browse (Lowest Price) |
| `status` (Asc), `price` (Desc) | Marketplace browse (Highest Price) |
| `status` (Asc), `viewsCount` (Desc) | Marketplace browse (Most Viewed) |
| `status` (Asc), `savesCount` (Desc) | Marketplace browse (Most Saved) |
| `status` (Asc), `category` (Asc), `createdAt` (Desc) | Category browsing |
| `status` (Asc), `sellerUniversity` (Asc), `createdAt` (Desc) | Campus browsing |
| `status` (Asc), `category` (Asc), `sellerUniversity` (Asc), `createdAt` (Desc) | Filtered campus & category browsing |
| `sellerId` (Asc), `status` (Asc) | Seller inventory management |
| `flagged` (Asc), `createdAt` (Desc) | Admin flag queue |

## Housing Listings Collection (`housing_listings`)

| Index Fields | Query Usage |
|--------------|-------------|
| `status` (Asc), `lastVerifiedAt` (Desc) | Main housing browse (Newest) |
| `status` (Asc), `rent` (Asc) | Housing browse (Lowest Rent) |
| `status` (Asc), `rent` (Desc) | Housing browse (Highest Rent) |
| `status` (Asc), `university` (Asc), `lastVerifiedAt` (Desc) | Campus-specific housing |
| `status` (Asc), `type` (Asc), `lastVerifiedAt` (Desc) | Category-specific housing |
| `plugId` (Asc), `updatedAt` (Desc) | Plug dashboard |

## Events Collection (`events`)

| Index Fields | Query Usage |
|--------------|-------------|
| `campusId` (Asc), `isDeleted` (Asc), `status` (Asc) | Campus events feed |
| `organizerId` (Asc), `isDeleted` (Asc), `startAt` (Desc) | Organizer dashboard |
| `status` (Asc), `isDeleted` (Asc), `createdAt` (Desc) | Admin approval queue |

## Organizers Collection (`organizers`)

| Index Fields | Query Usage |
|--------------|-------------|
| `campusId` (Asc), `isDeleted` (Asc), `trustScore` (Desc) | Main campus organizer directory |

## Conversations Collection (`conversations`)

| Index Fields | Query Usage |
|--------------|-------------|
| `participants` (Array-Contains), `lastMessageTime` (Desc) | User's chat list |
| `isSupport` (Asc), `supportStatus` (Asc), `lastMessageTime` (Desc) | Admin support queue |
| `isSupport` (Asc), `assignedAdminId` (Asc), `lastMessageTime` (Desc) | Admin assigned tickets |

## Verification Collections

| Path | Fields | Query Usage |
|------|--------|-------------|
| `identity_verifications` | `status` (Asc), `submittedAt` (Desc) | Admin verification queue |
| `student_verifications` | `status` (Asc), `submittedAt` (Desc) | Admin verification queue |
| `verification_applications` | `status` (Asc), `createdAt` (Desc) | Professional verification queue |
| `organizer_verification_requests` | `status` (Asc), `submittedAt` (Desc) | Organizer approval queue |

## Offers Collection (`offers`)

| Index Fields | Query Usage |
|--------------|-------------|
| `listingId` (Asc), `timestamp` (Desc) | Viewing offers for a listing |
| `buyerId` (Asc), `timestamp` (Desc) | User's sent offers history |

## Event Attendance Collection (`event_attendance`)

| Index Fields | Query Usage |
|--------------|-------------|
| `userId` (Asc), `status` (Asc) | User's going/saved events lists |

## Event Categories Collection (`event_categories`)

| Index Fields | Query Usage |
|--------------|-------------|
| `isActive` (Asc), `priority` (Desc) | Category picker |

## User Collections (Sub-collections)

| Path | Fields | Query Usage |
|------|--------|-------------|
| `users/{uid}/recently_viewed` | `timestamp` (Desc) | Recents list |
| `users/{uid}/saved_searches` | `createdAt` (Desc) | Saved searches UI |
| `users/{uid}/collections/{cid}/listings` | `addedAt` (Desc) | Collection view |

---

## Collection Group Indexes

The following indexes must be created for **All Collections** with the specified ID (Collection Group scope).

| Collection ID | Fields | Query Usage |
|---------------|--------|-------------|
| `members` | `userId` (Asc) | Finding organizers a user manages |
| `saved_housing` | `__name__` (Asc) | Finding users who saved a specific property |

---

## Notes Collection (`notes`)

| Index Fields | Query Usage |
|--------------|-------------|
| `status` (Asc), `createdAt` (Desc) | Main notes feed (Newest) |
| `status` (Asc), `subjectCategory` (Asc), `createdAt` (Desc) | Category-specific notes |
| `status` (Asc), `university` (Asc), `createdAt` (Desc) | Campus-specific notes |
| `authorId` (Asc), `createdAt` (Desc) | Author's shared notes |

## Feed Collection (`feed`)

| Index Fields | Query Usage |
|--------------|-------------|
| `type` (Asc), `createdAt` (Desc) | Community, Confessions, and Gigs feeds |

## Instructions
1. Open [Firebase Console](https://console.firebase.google.com/).
2. Navigate to **Firestore Database**.
3. Select the **Indexes** tab.
4. Click **Create Index**.
5. Enter the Collection ID and the fields exactly as specified above.
   * **IMPORTANT**: When copying field names, ensure there are **no trailing spaces**.
6. Note: Some indexes may already be prompted for creation via links in the Firebase Debug Console during testing.
