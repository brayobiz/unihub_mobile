const {onDocumentCreated, onDocumentUpdated} = require("firebase-functions/v2/firestore");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const {getMessaging} = require("firebase-admin/messaging");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");
const {initializeApp} = require("firebase-admin/app");

initializeApp();

/**
 * Cloud Function to process the notification queue and send push notifications.
 * Triggered when a new document is added to the 'notifications_queue' collection.
 */
exports.processNotificationQueue = onDocumentCreated("notifications_queue/{queueId}", async (event) => {
  const snapshot = event.data;
  if (!snapshot) return;

  const data = snapshot.data();
  const {recipientId, title, body, data: payload, isBroadcast} = data;

  if ((!recipientId && !isBroadcast) || !title || !body) {
    console.error("Missing required notification fields");
    return snapshot.ref.update({status: "failed", error: "Missing fields"});
  }

  try {
    const db = getFirestore();
    const messaging = getMessaging();

    if (isBroadcast) {
      console.log("Processing broadcast notification");
      const message = {
        notification: {
          title: title,
          body: body,
        },
        data: payload || {},
        topic: (payload && payload.topic) ? payload.topic : "all_users",
      };

      await messaging.send(message);
      return snapshot.ref.update({
        status: "sent",
        type: "broadcast_topic",
        processedAt: FieldValue.serverTimestamp(),
      });
    }

    // 1. Get user's device tokens
    const tokensSnapshot = await db
        .collection("users")
        .doc(recipientId)
        .collection("tokens")
        .get();

    if (tokensSnapshot.empty) {
      console.log(`No tokens found for user: ${recipientId}`);
      return snapshot.ref.update({status: "no_tokens", processedAt: FieldValue.serverTimestamp()});
    }

    const tokens = tokensSnapshot.docs.map((doc) => doc.data().token);
    console.log(`Sending to ${tokens.length} tokens for user ${recipientId}`);

    // 2. Build FCM message with High Priority for Android
    const message = {
      notification: {
        title: title,
        body: body,
      },
      data: payload || {},
      android: {
        priority: "high",
        notification: {
          channelId: "unihub_main_channel",
          priority: "high",
          clickAction: "FLUTTER_NOTIFICATION_CLICK",
        },
      },
      apns: {
        payload: {
          aps: {
            contentAvailable: true,
            sound: "default",
          },
        },
      },
      tokens: tokens,
    };

    // 3. Send multicast message
    const response = await messaging.sendEachForMulticast(message);

    console.log(`${response.successCount} messages were sent successfully`);

    // 4. Handle failed tokens (cleanup)
    if (response.failureCount > 0) {
      const failedTokens = [];
      response.responses.forEach((resp, idx) => {
        if (!resp.success) {
          const errorCode = resp.error?.code;
          if (errorCode === "messaging/registration-token-not-registered" ||
              errorCode === "messaging/invalid-registration-token") {
            failedTokens.push(tokens[idx]);
          }
        }
      });

      if (failedTokens.length > 0) {
        console.log(`Cleaning up ${failedTokens.length} invalid tokens`);
        const batch = db.batch();
        failedTokens.forEach((token) => {
          const tokenRef = db.collection("users").doc(recipientId).collection("tokens").doc(token);
          batch.delete(tokenRef);
        });
        await batch.commit();
      }
    }

    // 5. Update queue status
    return snapshot.ref.update({
      status: "sent",
      successCount: response.successCount,
      failureCount: response.failureCount,
      processedAt: FieldValue.serverTimestamp(),
    });
  } catch (error) {
    console.error("Error sending push notification:", error);
    return snapshot.ref.update({
      status: "failed",
      error: error.message,
      processedAt: FieldValue.serverTimestamp(),
    });
  }
});

/**
 * Scheduled function to send a random marketplace reminder to all users every day.
 * This satisfies the "triggers itself" requirement.
 */
exports.scheduledMarketplaceReminder = onSchedule("0 10 * * *", async (event) => {
  const messages = [
    {
      title: "New Deals Alert! 🛍️",
      body: "Fresh items just landed in the marketplace. See what you can find today!",
    },
    {
      title: "UniHub Marketplace 🎓",
      body: "Looking for something specific? Your campus mates might be selling exactly what you need!",
    },
    {
      title: "Save Money Today! 💸",
      body: "Why buy new when you can get quality items from fellow students? Check out the marketplace.",
    },
    {
      title: "Tired of the same old stuff? 📦",
      body: "Discover hidden gems and great bargains in the marketplace right now!",
    },
  ];

  const randomMessage = messages[Math.floor(Math.random() * messages.length)];

  const message = {
    notification: {
      title: randomMessage.title,
      body: randomMessage.body,
    },
    data: {
      route: "/marketplace",
      targetType: "marketplace",
    },
    topic: "all_users",
  };

  try {
    await getMessaging().send(message);
    console.log("Scheduled marketplace reminder sent successfully");
  } catch (error) {
    console.error("Error sending scheduled marketplace reminder:", error);
  }
});

/**
 * Scheduled function to prune notifications older than 20 days.
 * Runs every day at midnight.
 */
exports.pruneOldNotifications = onSchedule("0 0 * * *", async (event) => {
  const db = getFirestore();
  const twentyDaysAgo = new Date();
  twentyDaysAgo.setDate(twentyDaysAgo.getDate() - 20);

  console.log(`Pruning notifications created before: ${twentyDaysAgo.toISOString()}`);

  try {
    // Use collectionGroup to query all 'notifications' subcollections across all users
    const oldNotificationsSnapshot = await db
        .collectionGroup("notifications")
        .where("createdAt", "<", twentyDaysAgo)
        .limit(500) // Process in chunks to avoid timeout/memory issues
        .get();

    if (oldNotificationsSnapshot.empty) {
      console.log("No old notifications to prune.");
      return null;
    }

    const batch = db.batch();
    oldNotificationsSnapshot.docs.forEach((doc) => {
      batch.delete(doc.ref);
    });

    await batch.commit();
    console.log(`Successfully pruned ${oldNotificationsSnapshot.size} old notifications.`);
    return null;
  } catch (error) {
    console.error("Error pruning old notifications:", error);
    return null;
  }
});

/**
 * Scheduled function to cleanup expired conversations.
 * Runs every hour to check for conversations where expiresAt < now.
 */
exports.cleanupExpiredConversations = onSchedule("0 * * * *", async (event) => {
  const db = getFirestore();
  const now = FieldValue.serverTimestamp();

  console.log("Checking for expired conversations...");

  try {
    const expiredSnap = await db.collection("conversations")
        .where("expiresAt", "<", new Date())
        .limit(100)
        .get();

    if (expiredSnap.empty) {
      console.log("No expired conversations found.");
      return null;
    }

    const batch = db.batch();
    for (const doc of expiredSnap.docs) {
      // Note: In production, you'd recursively delete messages subcollection
      // For now, we delete the conversation doc.
      // Firestore batch limit is 500, so 100 docs is safe.
      batch.delete(doc.ref);
    }

    await batch.commit();
    console.log(`Successfully cleaned up ${expiredSnap.size} expired conversations.`);
    return null;
  } catch (error) {
    console.error("Error cleaning up expired conversations:", error);
    return null;
  }
});

/**
 * Cloud Function to clean up all data associated with a user when their account is deleted.
 * Triggered when a user document in the 'users' collection is deleted.
 */
const {onDocumentDeleted} = require("firebase-functions/v2/firestore");

exports.cleanupUserData = onDocumentDeleted("users/{userId}", async (event) => {
  const userId = event.params.userId;
  const db = getFirestore();

  console.log(`🧹 Starting full cleanup for deleted user: ${userId}`);

  const collectionsToClean = [
    {name: "listings", field: "sellerId"},
    {name: "housing_listings", field: "plugId"},
    {name: "notes", field: "authorId"},
    {name: "feed", field: "authorId"},
    {name: "gigs", field: "employerId"},
    {name: "gig_applications", field: "freelancerId"},
    {name: "verification_applications", field: "userId"},
    {name: "events", field: "createdBy"},
    {name: "organizers", field: "ownerId"},
    {name: "offers", field: "buyerId"},
    {name: "reports", field: "reporterId"},
    {name: "housing_reports", field: "reporterId"},
    {name: "housing_vacancy_requests", field: "userId"},
    {name: "housing_saved_searches", field: "userId"},
    {name: "housing_viewing_requests", field: "studentId"},
    {name: "event_attendance", field: "userId"},
    {name: "payments", field: "userId"},
    {name: "roommates", field: "userId"},
  ];

  try {
    // 0. Delete User Subcollections (Thorough Server-side Recursive Deletion)
    const subcollections = [
      "notifications", "tokens", "saved_listings", "saved_housing",
      "saved_searches", "recent_searches", "followed_organizers",
      "saved_events", "saved_notes", "study_progress", "collections", "reviews",
    ];

    for (const sub of subcollections) {
      const snap = await db.collection("users").doc(userId).collection(sub).get();
      if (!snap.empty) {
        console.log(`Cleaning subcollection ${sub} for user ${userId}`);
        const batch = db.batch();
        snap.docs.forEach((doc) => batch.delete(doc.ref));
        await batch.commit();
      }
    }

    // 1. Delete documents in top-level collections where user is the owner/author
    for (const coll of collectionsToClean) {
      const snapshot = await db.collection(coll.name)
          .where(coll.field, "==", userId)
          .get();

      if (!snapshot.empty) {
        console.log(`Deleting ${snapshot.size} docs from ${coll.name}`);
        const batch = db.batch();
        snapshot.docs.forEach((doc) => batch.delete(doc.ref));
        await batch.commit();
      }
    }

    // 2. Handle specific documents with ID == userId
    const directDocs = [
      "identity_verifications",
      "student_verifications",
      "subscriptions",
    ];

    for (const collName of directDocs) {
      await db.collection(collName).doc(userId).delete().catch(() => null);
    }

    // 3. Handle Conversations (User as participant)
    // We remove the user from participants. If no participants left, delete.
    const convSnapshot = await db.collection("conversations")
        .where("participants", "array-contains", userId)
        .get();

    if (!convSnapshot.empty) {
      console.log(`Updating ${convSnapshot.size} conversations for user: ${userId}`);
      for (const doc of convSnapshot.docs) {
        const participants = doc.data().participants || [];
        const updatedParticipants = participants.filter((p) => p !== userId);

        if (updatedParticipants.length <= 1) {
          // If only 0 or 1 person left (and one was the deleted user), delete the chat
          await doc.ref.delete();
        } else {
          await doc.ref.update({
            participants: updatedParticipants,
            updatedAt: FieldValue.serverTimestamp(),
          });
        }
      }
    }

    // 4. Handle Offers where user is SELLER (buyerId was handled in loop)
    const receivedOffers = await db.collection("offers")
        .where("sellerId", "==", userId)
        .get();

    if (!receivedOffers.empty) {
      const batch = db.batch();
      receivedOffers.docs.forEach((doc) => batch.delete(doc.ref));
      await batch.commit();
    }

    console.log(`✅ Cleanup completed for user: ${userId}`);
  } catch (error) {
    console.error(`❌ Error during user data cleanup for ${userId}:`, error);
  }
});

/**
 * Cloud Function to hide/restore user content based on their suspension status.
 * Triggered when a user document is updated.
 */
exports.handleUserSuspension = onDocumentUpdated("users/{userId}", async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();
  const userId = event.params.userId;
  const db = getFirestore();

  const wasSuspended = before.suspendedUntil && before.suspendedUntil.toDate() > new Date();
  const isSuspended = after.suspendedUntil && after.suspendedUntil.toDate() > new Date();
  const isBanned = after.isBanned === true;

  // Case 1: User newly suspended or banned
  if ((isSuspended && !wasSuspended) || (isBanned && before.isBanned !== true)) {
    console.log(`🚫 User ${userId} restricted. Hiding active content.`);

    // Hide Listings
    const listingsSnap = await db.collection("listings")
        .where("sellerId", "==", userId)
        .where("status", "==", "active")
        .get();

    if (!listingsSnap.empty) {
      const batch = db.batch();
      listingsSnap.docs.forEach((doc) => {
        batch.update(doc.ref, {
          status: "userSuspended",
          originalStatus: "active",
          restrictedAt: FieldValue.serverTimestamp(),
        });
      });
      await batch.commit();
      console.log(`Paused ${listingsSnap.size} listings for suspended user ${userId}`);
    }

    // Hide Housing
    const housingSnap = await db.collection("housing_listings")
        .where("plugId", "==", userId)
        .where("status", "==", "available")
        .get();

    if (!housingSnap.empty) {
      const batch = db.batch();
      housingSnap.docs.forEach((doc) => {
        batch.update(doc.ref, {
          status: "userSuspended",
          originalStatus: "available",
          restrictedAt: FieldValue.serverTimestamp(),
        });
      });
      await batch.commit();
    }
  }
  // Case 2: User restored (suspension cleared or expired)
  else if ((!isSuspended && wasSuspended && !isBanned) || (after.isBanned === false && before.isBanned === true)) {
    console.log(`✅ User ${userId} restriction lifted. Restoring content.`);

    // Restore Listings
    const suspendedListings = await db.collection("listings")
        .where("sellerId", "==", userId)
        .where("status", "==", "userSuspended")
        .get();

    if (!suspendedListings.empty) {
      const batch = db.batch();
      suspendedListings.docs.forEach((doc) => {
        const data = doc.data();
        batch.update(doc.ref, {
          status: data.originalStatus || "active",
          restrictedAt: null,
          originalStatus: null,
        });
      });
      await batch.commit();
      console.log(`Restored ${suspendedListings.size} listings for user ${userId}`);
    }

    // Restore Housing
    const suspendedHousing = await db.collection("housing_listings")
        .where("plugId", "==", userId)
        .where("status", "==", "userSuspended")
        .get();

    if (!suspendedHousing.empty) {
      const batch = db.batch();
      suspendedHousing.docs.forEach((doc) => {
        const data = doc.data();
        batch.update(doc.ref, {
          status: data.originalStatus || "available",
          restrictedAt: null,
          originalStatus: null,
        });
      });
      await batch.commit();
    }
  }
});

/**
 * Scheduled function to check for expired suspensions and restore content.
 * Runs every hour.
 */
exports.checkExpiredSuspensions = onSchedule("0 * * * *", async (event) => {
  const db = getFirestore();
  const now = new Date();

  console.log("Checking for expired suspensions...");

  try {
    // Find users where suspension ended but items might still be hidden
    const expiredUsersSnap = await db.collection("users")
        .where("suspendedUntil", "<", now)
        .limit(100)
        .get();

    if (expiredUsersSnap.empty) {
      console.log("No expired suspensions to process.");
      return null;
    }

    for (const userDoc of expiredUsersSnap.docs) {
      const userId = userDoc.id;

      // Trigger the restore logic by updating the user doc slightly
      // or just call a shared restore function.
      // For simplicity, we'll clear the suspendedUntil field which triggers handleUserSuspension
      await userDoc.ref.update({
        suspendedUntil: null,
        updatedAt: FieldValue.serverTimestamp(),
      });
      console.log(`Cleared suspension for user ${userId}`);
    }

    return null;
  } catch (error) {
    console.error("Error checking expired suspensions:", error);
    return null;
  }
});


