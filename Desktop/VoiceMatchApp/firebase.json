/**
 * index.js
 * Firebase Cloud Functions for VoiceMatchApp
 */

const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
admin.initializeApp();

// =========================================================
// 1. チャットメッセージの通知
// =========================================================
exports.sendChatNotification = functions.firestore
  .document("matches/{matchId}/messages/{messageId}")
  .onCreate(async (snapshot, context) => {
    const messageData = snapshot.data();
    const senderID = messageData.senderID;
    const matchId = context.params.matchId;

    try {
      const matchDoc = await admin.firestore().collection("matches").doc(matchId).get();
      if (!matchDoc.exists) return null;
      
      const matchData = matchDoc.data();
      const receiverID = (matchData.user1ID === senderID) ? matchData.user2ID : matchData.user1ID;

      const receiverDoc = await admin.firestore().collection("users").doc(receiverID).get();
      if (!receiverDoc.exists) return null;
      
      const receiverData = receiverDoc.data();
      const fcmToken = receiverData.fcmToken;
      
      const settings = receiverData.notificationSettings || {};
      if (settings.message === false) return null;
      if (!fcmToken) return null;

      const senderDoc = await admin.firestore().collection("users").doc(senderID).get();
      const senderName = senderDoc.exists ? (senderDoc.data().username || "相手") : "相手";

      // ★修正: ペイロード構造を v1 API に適合させる
      const message = {
        token: fcmToken,
        notification: {
          title: `${senderName}`,
          body: "新着ボイスメッセージが届きました🎙️",
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
              badge: 1, // 数値で指定
            },
          },
        },
        data: {
          type: "chat", 
          matchId: matchId,
        },
      };

      await admin.messaging().send(message);
      console.log(`チャット通知送信成功: ${receiverID} 宛`);

    } catch (error) {
      console.error("チャット通知エラー:", error);
    }
  });

// =========================================================
// 2. アプローチ受信の通知
// =========================================================
exports.sendApproachNotification = functions.firestore
  .document("messages/{messageId}")
  .onCreate(async (snapshot, context) => {
    const messageData = snapshot.data();
    if (messageData.isMatched === true) return null;

    const receiverID = messageData.receiverID;
    const senderID = messageData.senderID;

    try {
      const receiverDoc = await admin.firestore().collection("users").doc(receiverID).get();
      if (!receiverDoc.exists) return null;
      
      const receiverData = receiverDoc.data();
      const fcmToken = receiverData.fcmToken;

      const settings = receiverData.notificationSettings || {};
      if (settings.approach === false) return null;
      if (!fcmToken) return null;

      const senderDoc = await admin.firestore().collection("users").doc(senderID).get();
      const senderName = senderDoc.exists ? (senderDoc.data().username || "誰か") : "誰か";

      // ★修正: ペイロード構造を v1 API に適合させる
      const message = {
        token: fcmToken,
        notification: {
          title: "新しいアプローチ！",
          body: `${senderName}さんから声が届きました💌`,
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
              badge: 1,
            },
          },
        },
        data: {
          type: "approach",
        },
      };

      await admin.messaging().send(message);
      console.log(`アプローチ通知送信成功: ${receiverID} 宛`);

    } catch (error) {
      console.error("アプローチ通知エラー:", error);
    }
  });

// =========================================================
// 3. マッチ成立の通知
// =========================================================
exports.sendMatchNotification = functions.firestore
  .document("matches/{matchId}")
  .onCreate(async (snapshot, context) => {
    const matchData = snapshot.data();
    const user1ID = matchData.user1ID; 
    const user2ID = matchData.user2ID; 

    try {
      const user1Doc = await admin.firestore().collection("users").doc(user1ID).get();
      if (!user1Doc.exists) return null;
      
      const user1Data = user1Doc.data();
      const fcmToken = user1Data.fcmToken;

      const settings = user1Data.notificationSettings || {};
      if (settings.match === false) return null;
      if (!fcmToken) return null;

      const user2Doc = await admin.firestore().collection("users").doc(user2ID).get();
      const user2Name = user2Doc.exists ? (user2Doc.data().username || "相手") : "相手";

      // ★修正: ペイロード構造を v1 API に適合させる
      const message = {
        token: fcmToken,
        notification: {
          title: "マッチング成立！🎉",
          body: `${user2Name}さんとマッチしました！メッセージを送りましょう。`,
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
              badge: 1,
            },
          },
        },
        data: {
          type: "match",
          matchId: context.params.matchId,
        },
      };

      await admin.messaging().send(message);
      console.log(`マッチ通知送信成功: ${user1ID} 宛`);

    } catch (error) {
      console.error("マッチ通知エラー:", error);
    }
  });