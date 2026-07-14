const http2 = require("http2");
const crypto = require("crypto");

function base64url(value) {
  return Buffer.from(value)
    .toString("base64")
    .replace(/=/g, "")
    .replace(/\+/g, "-")
    .replace(/\//g, "_");
}

function makeApnsJwt(teamId, keyId, privateKeyPem) {
  const header = base64url(JSON.stringify({ alg: "ES256", kid: keyId }));
  const claims = base64url(
    JSON.stringify({ iss: teamId, iat: Math.floor(Date.now() / 1000) })
  );
  const unsigned = `${header}.${claims}`;
  const signature = crypto.sign("sha256", Buffer.from(unsigned), {
    key: privateKeyPem,
    dsaEncoding: "ieee-p1363",
  });
  return `${unsigned}.${base64url(signature)}`;
}

function apnsHost(context) {
  const useSandbox = context.values.get("APNS_USE_SANDBOX");
  if (useSandbox === "false") {
    return "api.push.apple.com";
  }
  return "api.sandbox.push.apple.com";
}

async function sendSilentPush(context, deviceToken, customPayload) {
  const keyId = context.values.get("APNS_KEY_ID");
  const teamId = context.values.get("APNS_TEAM_ID");
  const bundleId = context.values.get("APNS_BUNDLE_ID");
  const privateKey = context.values.get("APNS_PRIVATE_KEY");

  if (!keyId || !teamId || !bundleId || !privateKey) {
    console.log("APNs not configured — skipping push");
    return false;
  }

  const jwt = makeApnsJwt(teamId, keyId, privateKey);
  const body = JSON.stringify({
    aps: { "content-available": 1 },
    ...customPayload,
  });

  const host = apnsHost(context);
  const path = `/3/device/${deviceToken}`;

  return new Promise((resolve) => {
    const client = http2.connect(`https://${host}`);

    client.on("error", (error) => {
      console.log(`APNs connection error: ${error.message}`);
      client.close();
      resolve(false);
    });

    const request = client.request({
      ":method": "POST",
      ":path": path,
      authorization: `bearer ${jwt}`,
      "apns-topic": bundleId,
      "apns-push-type": "background",
      "apns-priority": "5",
    });

    let responseBody = "";

    request.on("response", (headers) => {
      const status = headers[":status"];
      request.on("data", (chunk) => {
        responseBody += chunk;
      });
      request.on("end", () => {
        client.close();
        if (status === 200) {
          resolve(true);
        } else {
          console.log(`APNs push failed (${status}): ${responseBody}`);
          resolve(false);
        }
      });
    });

    request.on("error", (error) => {
      console.log(`APNs request error: ${error.message}`);
      client.close();
      resolve(false);
    });

    request.end(body);
  });
}

async function sendAlertPush(context, deviceToken, { title, body, ...customPayload }) {
  const keyId = context.values.get("APNS_KEY_ID");
  const teamId = context.values.get("APNS_TEAM_ID");
  const bundleId = context.values.get("APNS_BUNDLE_ID");
  const privateKey = context.values.get("APNS_PRIVATE_KEY");

  if (!keyId || !teamId || !bundleId || !privateKey) {
    console.log("APNs not configured — skipping push");
    return false;
  }

  const jwt = makeApnsJwt(teamId, keyId, privateKey);
  const payload = JSON.stringify({
    aps: { alert: { title, body }, sound: "default" },
    ...customPayload,
  });

  const host = apnsHost(context);
  const path = `/3/device/${deviceToken}`;

  return new Promise((resolve) => {
    const client = http2.connect(`https://${host}`);

    client.on("error", (error) => {
      console.log(`APNs connection error: ${error.message}`);
      client.close();
      resolve(false);
    });

    const request = client.request({
      ":method": "POST",
      ":path": path,
      authorization: `bearer ${jwt}`,
      "apns-topic": bundleId,
      "apns-push-type": "alert",
      "apns-priority": "10",
    });

    let responseBody = "";

    request.on("response", (headers) => {
      const status = headers[":status"];
      request.on("data", (chunk) => {
        responseBody += chunk;
      });
      request.on("end", () => {
        client.close();
        if (status === 200) {
          resolve(true);
        } else {
          console.log(`APNs alert failed (${status}): ${responseBody}`);
          resolve(false);
        }
      });
    });

    request.on("error", (error) => {
      console.log(`APNs request error: ${error.message}`);
      client.close();
      resolve(false);
    });

    request.end(payload);
  });
}

async function notifyPartnerPhoto(db, context, partnerUserId, sessionId, hourIndex) {
  const tokenDoc = await db.collection("device_tokens").findOne({ userId: partnerUserId });
  if (!tokenDoc?.token) {
    console.log("No device token for partner — skipping push");
    return false;
  }

  return sendSilentPush(context, tokenDoc.token, {
    type: "partner.photo",
    sessionId: String(sessionId),
    hourIndex,
  });
}

module.exports = { sendSilentPush, sendAlertPush, notifyPartnerPhoto };
