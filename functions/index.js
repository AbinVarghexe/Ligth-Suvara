/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");
const logger = require("firebase-functions/logger");

admin.initializeApp();

// 1. Broadcast Trigger
// Listens for new documents in the 'broadcasts' collection
exports.sendBroadcast = onDocumentCreated("broadcasts/{broadcastId}", async (event) => {
  const snapshot = event.data;
  if (!snapshot) {
    logger.log("No data associated with the event");
    return;
  }

  const data = snapshot.data();
  const title = data.title;
  const body = data.body;
  const imageUrl = data.imageUrl;

  const payload = {
    notification: {
      title: title,
      body: body,
    },
    android: {
      priority: "high",
      notification: {
        channelId: "high_importance_channel",
      },
    },
    apns: {
      payload: {
        aps: {
          sound: "default",
        },
      },
    },
    topic: "broadcasts", // Sent to everyone subscribed to 'broadcasts'
  };

  if (imageUrl) {
    payload.notification.image = imageUrl;
  }

  try {
    const response = await admin.messaging().send(payload);
    logger.log("Successfully sent broadcast:", response);
  } catch (error) {
    logger.error("Error sending broadcast:", error);
  }
});

// 2. Scheduled/Targeted Notification Trigger
// Listens for new documents in the 'notifications' collection
exports.sendNotification = onDocumentCreated("notifications/{notificationId}", async (event) => {
  const snapshot = event.data;
  if (!snapshot) {
    logger.log("No data associated with the event");
    return;
  }

  const data = snapshot.data();
  const recipientId = data.recipientId;
  const title = data.title;
  const body = data.body;
  const imageUrl = data.imageUrl;

  // Determine the target topic
  // 'role_school' targets all Sunday School users.
  // 'all' is now treated as a legacy/fallback or public broadcast if used.
  const topic = recipientId === "role_school" ? "role_school" : (recipientId === "all" ? "broadcasts" : `school_${recipientId}`);

  const payload = {
    notification: {
      title: title,
      body: body,
    },
    android: {
      priority: "high",
      notification: {
        channelId: "high_importance_channel",
      },
    },
    apns: {
      payload: {
        aps: {
          sound: "default",
        },
      },
    },
    topic: topic,
  };

  if (imageUrl) {
    payload.notification.image = imageUrl;
  }

  try {
    const response = await admin.messaging().send(payload);
    logger.log(`Successfully sent notification to topic ${topic}:`, response);
  } catch (error) {
    logger.error(`Error sending notification to topic ${topic}:`, error);
  }
});
