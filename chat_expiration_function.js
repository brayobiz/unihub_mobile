/**
 * Suggested Firebase Cloud Function for Automatic Conversation Expiration
 *
 * Deployment Instructions:
 * 1. Initialize Firebase Functions in your project.
 * 2. Add this code to your index.js file.
 * 3. Deploy using 'firebase deploy --only functions'.
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
if (!admin.apps.length) admin.initializeApp();

/**
 * Scheduled cleanup of expired conversations.
 * Runs every hour to check for conversations where expiresAt < now.
 */
exports.cleanupExpiredConversations = functions.pubsub.schedule('every 1 hours').onRun(async (context) => {
    const now = admin.firestore.Timestamp.now();
    const db = admin.firestore();

    // Query expired conversations
    const expiredSnap = await db.collection('conversations')
        .where('expiresAt', '<', now)
        .get();

    if (expiredSnap.empty) return null;

    const batchSize = 500;
    let batch = db.batch();
    let count = 0;

    for (const doc of expiredSnap.docs) {
        const convId = doc.id;

        // 1. Delete all messages in subcollection
        const messagesSnap = await doc.ref.collection('messages').get();
        messagesSnap.forEach(msgDoc => {
            batch.delete(msgDoc.ref);
            count++;
        });

        // 2. Delete the conversation document
        batch.delete(doc.ref);
        count++;

        // 3. Optional: Cleanup associated media from Storage could be done here
        // or by a separate onDelete trigger on the messages collection.

        if (count >= batchSize) {
            await batch.commit();
            batch = db.batch();
            count = 0;
        }
    }

    if (count > 0) {
        await batch.commit();
    }

    console.log(`Cleaned up ${expiredSnap.size} expired conversations.`);
    return null;
});

/**
 * Optional: Trigger cleanup of Storage files when a message containing a URL is deleted.
 */
exports.onMessageDelete = functions.firestore
    .document('conversations/{convId}/messages/{msgId}')
    .onDelete(async (snap, context) => {
        const data = snap.data();
        if (data.type === 'image' || data.type === 'file') {
            const fileUrl = data.content;
            if (fileUrl && fileUrl.includes('firebasestorage.googleapis.com')) {
                try {
                    // Extract path from URL and delete from default bucket
                    const filePath = decodeURIComponent(fileUrl.split('/o/')[1].split('?')[0]);
                    await admin.storage().bucket().file(filePath).delete();
                    console.log(`Deleted storage file: ${filePath}`);
                } catch (e) {
                    console.error('Error deleting storage file:', e);
                }
            }
        }
    });
