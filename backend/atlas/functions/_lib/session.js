const { ObjectId } = require("mongodb");

async function getSessionForUser(db, sessionId, userId) {
  let sessionOid;
  try {
    sessionOid = new ObjectId(sessionId);
  } catch {
    return null;
  }

  return db.collection("sessions").findOne({
    _id: sessionOid,
    $or: [{ userA: userId }, { userB: userId }],
    status: { $in: ["active", "farewell"] },
    expiresAt: { $gt: new Date() },
  });
}

function partnerUserId(session, viewerId) {
  const isUserA = session.userA.toString() === viewerId.toString();
  return isUserA ? session.userB : session.userA;
}

function currentHourIndex(session, now = new Date()) {
  const elapsedMs = now.getTime() - new Date(session.startedAt).getTime();
  const hours = Math.floor(elapsedMs / (60 * 60 * 1000));
  return Math.min(23, Math.max(0, hours));
}

module.exports = { getSessionForUser, partnerUserId, currentHourIndex };
