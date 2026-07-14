// Atlas Function: reportAndBlock
// Body: { sessionId, reason? }
// Inserts report + block, ends active session for reporter.

const { getSessionForUser, partnerUserId } = require("../_lib/session");

const DB_NAME = "povstranger";

exports = async function (arg, context) {
  const userId = context.user?.id;
  if (!userId) return { error: "Unauthorized" };

  const sessionId = arg?.sessionId;
  const reason = String(arg?.reason ?? "inappropriate_content").slice(0, 200);

  if (!sessionId) return { error: "Missing sessionId" };

  const db = context.services.get("mongodb-atlas").db(DB_NAME);
  const session = await getSessionForUser(db, sessionId, userId);
  if (!session) return { error: "Session not found" };

  const partnerId = partnerUserId(session, userId);
  const now = new Date();

  await db.collection("reports").insertOne({
    reporterId: userId,
    reportedId: partnerId,
    sessionId: session._id,
    reason,
    createdAt: now,
  });

  await db.collection("blocks").updateOne(
    { blockerId: userId, blockedId: partnerId },
    { $set: { blockerId: userId, blockedId: partnerId, createdAt: now } },
    { upsert: true }
  );

  await db.collection("sessions").updateOne(
    { _id: session._id },
    { $set: { status: "ended", endedAt: now, endReason: "report" } }
  );

  return { ok: true };
};
