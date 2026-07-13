// Atlas Function: getPartnerPhoto
// Return partner's uploaded photo for a given hour as base64.
//
// Body: { sessionId, hourIndex }

const { GridFSBucket } = require("mongodb");
const { getSessionForUser, partnerUserId } = require("../_lib/session");

const DB_NAME = "povstranger";

exports = async function (arg, context) {
  const userId = context.user?.id;
  if (!userId) return { error: "Unauthorized" };

  const sessionId = arg?.sessionId;
  const hourIndex = arg?.hourIndex;

  if (!sessionId || hourIndex === undefined) {
    return { error: "Missing sessionId or hourIndex" };
  }
  if (!Number.isInteger(hourIndex) || hourIndex < 0 || hourIndex > 23) {
    return { error: "Invalid hourIndex" };
  }

  const db = context.services.get("mongodb-atlas").db(DB_NAME);
  const session = await getSessionForUser(db, sessionId, userId);
  if (!session) return { error: "Session not found or expired" };

  const partnerId = partnerUserId(session, userId);
  const upload = await db.collection("hour_uploads").findOne({
    sessionId: session._id,
    userId: partnerId,
    hourIndex,
  });

  if (!upload) return { photo: null };

  const bucket = new GridFSBucket(db, { bucketName: "photos" });
  const chunks = [];

  await new Promise((resolve, reject) => {
    bucket
      .openDownloadStream(upload.gridfsFileId)
      .on("data", (chunk) => chunks.push(chunk))
      .on("error", reject)
      .on("end", resolve);
  });

  return {
    photo: {
      imageBase64: Buffer.concat(chunks).toString("base64"),
      hourIndex,
      capturedAt: upload.capturedAt,
      weatherSummary: upload.weatherSummary,
    },
  };
};
