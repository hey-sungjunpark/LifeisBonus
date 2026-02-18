const { onRequest } = require("firebase-functions/v2/https");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();

exports.kakaoCustomToken = onRequest({ cors: true }, async (req, res) => {
  if (req.method !== "POST") {
    return res.status(405).json({ error: "method-not-allowed" });
  }

  const accessToken = req.body?.accessToken;
  if (!accessToken) {
    return res.status(400).json({ error: "missing-access-token" });
  }

  try {
    const kakaoResponse = await fetch("https://kapi.kakao.com/v2/user/me", {
      method: "GET",
      headers: { Authorization: `Bearer ${accessToken}` },
    });

    if (!kakaoResponse.ok) {
      const detail = await kakaoResponse.text();
      return res.status(401).json({
        error: "kakao-auth-failed",
        detail,
      });
    }

    const kakaoProfile = await kakaoResponse.json();
    const kakaoId = kakaoProfile.id;
    if (!kakaoId) {
      return res.status(500).json({ error: "kakao-id-missing" });
    }

    const uid = `kakao:${kakaoId}`;
    const additionalClaims = {
      provider: "kakao",
      kakaoId,
    };
    const firebaseToken = await getAuth().createCustomToken(
      uid,
      additionalClaims,
    );

    return res.status(200).json({ firebaseToken, kakaoId });
  } catch (error) {
    return res.status(500).json({
      error: "internal-error",
      detail: String(error),
    });
  }
});

exports.sendMessagePush = onDocumentCreated(
  {
    document: "threads/{threadId}/messages/{messageId}",
    region: "asia-northeast3",
  },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
      return;
    }
    const message = snapshot.data() || {};
    const threadId = event.params.threadId;
    const senderId = String(message.senderId || "").trim();
    const text = String(message.text || "").trim();
    if (!threadId || !senderId) {
      return;
    }

    const db = getFirestore();
    const threadSnap = await db.collection("threads").doc(threadId).get();
    if (!threadSnap.exists) {
      return;
    }
    const participants = Array.isArray(threadSnap.get("participants"))
      ? threadSnap.get("participants").map((v) => String(v))
      : [];
    const receiverIds = participants.filter((id) => id && id !== senderId);
    if (receiverIds.length === 0) {
      return;
    }

    let senderName = "새 쪽지";
    const senderSnap = await db.collection("users").doc(senderId).get();
    if (senderSnap.exists) {
      const displayName = senderSnap.get("displayName");
      if (typeof displayName === "string" && displayName.trim().length > 0) {
        senderName = displayName.trim();
      }
    }

    for (const receiverId of receiverIds) {
      const userRef = db.collection("users").doc(receiverId);
      const userSnap = await userRef.get();
      if (!userSnap.exists) {
        continue;
      }
      const enabled = userSnap.get("notificationsEnabled");
      if (enabled === false) {
        continue;
      }

      const tokensRaw = userSnap.get("fcmTokens");
      const tokens = Array.isArray(tokensRaw)
        ? tokensRaw
            .map((v) => String(v || "").trim())
            .filter((v) => v.length > 0)
        : [];
      if (tokens.length === 0) {
        continue;
      }

      const response = await getMessaging().sendEachForMulticast({
        tokens,
        notification: {
          title: senderName,
          body: text.isEmpty ? "새 메시지가 도착했어요." : text,
        },
        android: {
          priority: "high",
          notification: {
            channelId: "chat_messages",
            priority: "max",
            defaultSound: true,
            visibility: "public",
          },
        },
        apns: {
          headers: {
            "apns-priority": "10",
          },
          payload: {
            aps: {
              sound: "default",
            },
          },
        },
        data: {
          type: "chat_message",
          threadId,
          senderId,
          receiverId,
          senderName,
        },
      });

      const invalidTokens = [];
      response.responses.forEach((r, idx) => {
        if (!r.success) {
          const code = r.error?.code || "";
          if (
            code.includes("registration-token-not-registered") ||
            code.includes("invalid-argument")
          ) {
            invalidTokens.push(tokens[idx]);
          }
        }
      });
      if (invalidTokens.length > 0) {
        await userRef.set(
          {
            fcmTokens: FieldValue.arrayRemove(...invalidTokens),
            updatedAt: FieldValue.serverTimestamp(),
          },
          { merge: true },
        );
      }
    }
  },
);
