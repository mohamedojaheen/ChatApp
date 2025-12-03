const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");

admin.initializeApp();

exports.sendChatNotification = functions.firestore
    .document("chats/{chatId}/messages/{messageId}")
    .onCreate(async (snapshot, context) => {
      const message = snapshot.data();
      const receiverId = message.receiverId;
      const senderId = message.senderId;

      // 1. Get Receiver's FCM Token
      const receiverDoc = await admin.firestore()
          .collection("users")
          .doc(receiverId)
          .get();

      if (!receiverDoc.exists) {
        console.log("No receiver found");
        return null;
      }

      const token = receiverDoc.data().fcmToken;
      if (!token) {
        console.log("No token found for receiver");
        return null;
      }

      // 2. Get Sender's Name
      const senderDoc = await admin.firestore()
          .collection("users")
          .doc(senderId)
          .get();

      const senderName = senderDoc.exists ?
        senderDoc.data().name : "New Message";

      // 3. Construct Notification Payload
      const payload = {
        notification: {
          title: senderName,
          body: message.text,
          sound: "default",
          clickAction: "FLUTTER_NOTIFICATION_CLICK",
        },
        data: {
          senderId: senderId,
          chatId: context.params.chatId,
        },
      };

      // 4. Send Message via FCM
      try {
        return await admin.messaging().sendToDevice(token, payload);
      } catch (error) {
        console.error("Error sending notification:", error);
        return null;
      }
    });