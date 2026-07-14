// Atlas Function: uploadPhoto
// Upload JPEG to GridFS bucket "photos" and record hour_uploads.
//
// Body: { sessionId, hourIndex, weatherSummary, imageBase64 }

const { GridFSBucket } = require("mongodb");
const { notifyPartnerPhoto } = require("../_lib/apns");
const { getSessionForUser, partnerUserId, currentHourIndex } = require("../_lib/session");

const DB_NAME = "povstranger";
const MAX_BYTES = 120 * 1024;

exports = async function (arg, context) {
  const userId = context.user?.id;
  if (!userId) return { error: "Unauthorized" };

  const sessionId = arg?.sessionId;
  const hourIndex = arg?.hourIndex;
  const weatherSummary = arg?.weatherSummary || "—";
  const imageBase64 = arg?.imageBase64;

  if (!sessionId || hourIndex === undefined || !imageBase64) {
    return { error: "Missing sessionId, hourIndex, or imageBase64" };
  }
  if (!Number.isInteger(hourIndex) || hourIndex < 0 || hourIndex > 23) {
    return { error: "Invalid hourIndex" };
  }

  const db = context.services.get("mongodb-atlas").db(DB_NAME);
  const session = await getSessionForUser(db, sessionId, userId);
  if (!session) return { error: "Session not found or expired" };

  const allowedHour = currentHourIndex(session);
  if (hourIndex > allowedHour) {
    return { error: "Cannot upload for a future hour" };
  }

  let imageBuffer;
  try {
    imageBuffer = Buffer.from(imageBase64, "base64");
  } catch {
    return { error: "Invalid imageBase64" };
  }
  if (imageBuffer.length === 0 || imageBuffer.length > MAX_BYTES) {
    return { error: "Image empty or too large" };
  }

  const sessionOid = session._id;
  const uploads = db.collection("hour_uploads");

  const existing = await uploads.findOne({
    sessionId: sessionOid,
    userId,
    hourIndex,
  });
  if (existing) return { error: "Already uploaded for this hour" };

  const now = new Date();
  const bucket = new GridFSBucket(db, { bucketName: "photos" });
  const filename = `${sessionId}_${userId}_${hourIndex}.jpg`;

  const uploadStream = bucket.openUploadStream(filename, {
    metadata: { sessionId: sessionOid, userId, hourIndex },
  });

  await new Promise((resolve, reject) => {
    uploadStream.on("error", reject);
    uploadStream.on("finish", resolve);
    uploadStream.end(imageBuffer);
  });

  const gridfsFileId = uploadStream.id;

  await uploads.insertOne({
    sessionId: sessionOid,
    userId,
    hourIndex,
    gridfsFileId,
    weatherSummary: String(weatherSummary).slice(0, 120),
    capturedAt: now,
    createdAt: now,
  });

  const partnerId = partnerUserId(session, userId);
  await notifyPartnerPhoto(db, context, partnerId, sessionOid.toString(), hourIndex);

  return {
    ok: true,
    hourIndex,
    gridfsFileId: gridfsFileId.toString(),
  };
};
