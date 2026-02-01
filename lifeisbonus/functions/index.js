const { onRequest } = require("firebase-functions/v2/https");
const { initializeApp } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");

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
