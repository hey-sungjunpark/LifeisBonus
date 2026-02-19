const { onRequest, onCall, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { google } = require("googleapis");

initializeApp();

const PREMIUM_PRODUCT_IDS = String(
  process.env.PREMIUM_PRODUCT_IDS || "lifeisbonus_premium_monthly_9900",
)
  .split(",")
  .map((v) => v.trim())
  .filter((v) => v.length > 0);
const APPLE_SHARED_SECRET = String(process.env.APPLE_SHARED_SECRET || "").trim();
const ANDROID_PACKAGE_NAME = String(
  process.env.ANDROID_PACKAGE_NAME || "com.lifeisbonus.app.lifeisbonus",
).trim();

async function verifyAppleReceipt({ receiptData, productId }) {
  if (!APPLE_SHARED_SECRET) {
    throw new HttpsError(
      "failed-precondition",
      "APPLE_SHARED_SECRET 환경변수가 설정되지 않았습니다.",
    );
  }
  async function callApple(url) {
    const response = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        "receipt-data": receiptData,
        password: APPLE_SHARED_SECRET,
        "exclude-old-transactions": false,
      }),
    });
    if (!response.ok) {
      throw new HttpsError(
        "internal",
        `Apple 검증 요청 실패: ${response.status}`,
      );
    }
    return response.json();
  }

  let payload = await callApple("https://buy.itunes.apple.com/verifyReceipt");
  if (payload.status === 21007) {
    payload = await callApple("https://sandbox.itunes.apple.com/verifyReceipt");
  }
  if (payload.status !== 0) {
    throw new HttpsError(
      "permission-denied",
      `Apple 영수증 검증 실패(status=${payload.status})`,
    );
  }

  const receiptInfos = Array.isArray(payload.latest_receipt_info)
    ? payload.latest_receipt_info
    : [];
  const candidates = receiptInfos.filter((item) => item.product_id === productId);
  if (candidates.length === 0) {
    return {
      isActive: false,
      platform: "ios",
      productId,
      storeState: "NOT_FOUND",
      expiresAtMillis: 0,
      autoRenew: false,
      transactionId: null,
      raw: payload,
    };
  }
  candidates.sort((a, b) => {
    const aMs = Number(a.expires_date_ms || 0);
    const bMs = Number(b.expires_date_ms || 0);
    return bMs - aMs;
  });
  const latest = candidates[0];
  const expiresAtMillis = Number(latest.expires_date_ms || 0);
  const now = Date.now();
  const canceledAtMillis = Number(latest.cancellation_date_ms || 0);
  const isCanceled = canceledAtMillis > 0;
  const pendingRenewals = Array.isArray(payload.pending_renewal_info)
    ? payload.pending_renewal_info
    : [];
  const renewal = pendingRenewals.find((item) => item.product_id === productId);
  const autoRenew = String(renewal?.auto_renew_status || "0") === "1";

  return {
    isActive: expiresAtMillis > now && !isCanceled,
    platform: "ios",
    productId,
    storeState: isCanceled ? "CANCELED" : "ACTIVE_OR_EXPIRED",
    expiresAtMillis,
    autoRenew,
    transactionId: latest.transaction_id || null,
    raw: payload,
  };
}

async function verifyGoogleSubscription({ purchaseToken, productId, packageName }) {
  const auth = new google.auth.GoogleAuth({
    scopes: ["https://www.googleapis.com/auth/androidpublisher"],
  });
  const client = await auth.getClient();
  const androidPublisher = google.androidpublisher({
    version: "v3",
    auth: client,
  });
  const appPackage = String(packageName || ANDROID_PACKAGE_NAME).trim();
  if (!appPackage) {
    throw new HttpsError("invalid-argument", "packageName이 필요합니다.");
  }

  const response = await androidPublisher.purchases.subscriptionsv2.get({
    packageName: appPackage,
    token: purchaseToken,
  });
  const payload = response.data || {};
  const lineItems = Array.isArray(payload.lineItems) ? payload.lineItems : [];
  const lineItem =
    lineItems.find((item) => item.productId === productId) || lineItems[0];
  if (!lineItem) {
    return {
      isActive: false,
      platform: "android",
      productId,
      storeState: "NOT_FOUND",
      expiresAtMillis: 0,
      autoRenew: false,
      transactionId: payload.latestOrderId || null,
      raw: payload,
    };
  }
  const expiresAtMillis = Date.parse(lineItem.expiryTime || "");
  const subscriptionState = String(payload.subscriptionState || "UNKNOWN");
  const isActiveState = [
    "SUBSCRIPTION_STATE_ACTIVE",
    "SUBSCRIPTION_STATE_IN_GRACE_PERIOD",
  ].includes(subscriptionState);
  const isActive = Number.isFinite(expiresAtMillis) && expiresAtMillis > Date.now() && isActiveState;
  const autoRenew = lineItem.autoRenewingPlan?.autoRenewEnabled === true;
  return {
    isActive,
    platform: "android",
    productId: lineItem.productId || productId,
    storeState: subscriptionState,
    expiresAtMillis: Number.isFinite(expiresAtMillis) ? expiresAtMillis : 0,
    autoRenew,
    transactionId: payload.latestOrderId || null,
    raw: payload,
  };
}

exports.verifyPremiumPurchase = onCall(
  {
    region: "asia-northeast3",
    timeoutSeconds: 60,
  },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
    }
    const uid = request.auth.uid;
    const platform = String(request.data?.platform || "").trim().toLowerCase();
    const productId = String(request.data?.productId || "").trim();
    if (!platform || !productId) {
      throw new HttpsError("invalid-argument", "platform/productId는 필수입니다.");
    }
    if (!PREMIUM_PRODUCT_IDS.includes(productId)) {
      throw new HttpsError("permission-denied", "허용되지 않은 상품입니다.");
    }

    let verification;
    if (platform === "android") {
      const purchaseToken = String(request.data?.purchaseToken || "").trim();
      if (!purchaseToken) {
        throw new HttpsError("invalid-argument", "purchaseToken이 필요합니다.");
      }
      verification = await verifyGoogleSubscription({
        purchaseToken,
        productId,
        packageName: request.data?.androidPackageName,
      });
    } else if (platform === "ios") {
      const receiptData = String(request.data?.purchaseToken || "").trim();
      if (!receiptData) {
        throw new HttpsError("invalid-argument", "receipt 데이터가 필요합니다.");
      }
      verification = await verifyAppleReceipt({
        receiptData,
        productId,
      });
    } else {
      throw new HttpsError("invalid-argument", "지원하지 않는 플랫폼입니다.");
    }

    const db = getFirestore();
    const userRef = db.collection("users").doc(uid);
    const expiresAtDate = verification.expiresAtMillis
      ? new Date(verification.expiresAtMillis)
      : null;
    const premiumUntilIso = expiresAtDate ? expiresAtDate.toISOString() : null;
    await userRef.set(
      {
        premiumActive: verification.isActive === true,
        premiumPlan: verification.productId,
        premiumPlatform: verification.platform,
        premiumAutoRenew: verification.autoRenew === true,
        premiumStoreState: verification.storeState,
        premiumUntil: premiumUntilIso,
        premiumVerifiedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    await userRef.collection("premiumPurchases").add({
      productId: verification.productId,
      platform: verification.platform,
      storeState: verification.storeState,
      isActive: verification.isActive === true,
      autoRenew: verification.autoRenew === true,
      expiresAt: premiumUntilIso,
      transactionId: verification.transactionId,
      createdAt: FieldValue.serverTimestamp(),
    });

    return {
      isActive: verification.isActive === true,
      premiumUntil: premiumUntilIso,
      platform: verification.platform,
      productId: verification.productId,
      storeState: verification.storeState,
      autoRenew: verification.autoRenew === true,
    };
  },
);

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
