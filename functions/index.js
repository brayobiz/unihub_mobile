const {onDocumentCreated} = require("firebase-functions/v2/firestore");
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
      // Use the "all_users" topic for broadcast. Clients must subscribe to this.
      const message = {
        notification: {
          title: title,
          body: body,
        },
        data: payload || {},
        topic: "all_users",
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

    // 2. Build FCM message
    const message = {
      notification: {
        title: title,
        body: body,
      },
      data: payload || {},
      tokens: tokens,
    };

    // 3. Send multicast message
    const response = await getMessaging().sendEachForMulticast(message);

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
