// Atlas Function: submitFarewell
// Body: { sessionId, text }

const { getSessionForUser } = require("../_lib/session");
const { sendSilentPush } = require("../_lib/apns");

const DB_NAME = "povstranger";
const FAREWELL_WINDOW_MS = 2 * 60 * 60 * 1000;
const MAX_TEXT_LENGTH = 280;

exports = async function (arg, context) {
  const userId = context.user?.id;
  if (!userId) return { error: "Unauthorized" };

  const sessionId = arg?.sessionId;
  const text = String(arg?.text ?? "").trim();

  if (!sessionId) return { error: "Missing sessionId" };
  if (!text) return { error: "Empty farewell text" };
  if (text.length > MAX_TEXT_LENGTH) return { error: "Text too long" };

  const db = context.services.get("mongodb-atlas").db(DB_NAME);
  const session = await getSessionForUser(db, sessionId, userId);
  if (!session) return { error: "Session not found or expired" };

  const now = new Date();
  const remainingMs = new Date(session.expiresAt).getTime() - now.getTime();
  if (remainingMs <= 0) return { error: "Session expired" };
  if (remainingMs > FAREWELL_WINDOW_MS) {
    return { error: "Farewell window not open yet" };
  }

  const sessionOid = session._id;
  const farewells = db.collection("farewells");

  const existing = await farewells.findOne({ sessionId: sessionOid, userId });
  if (existing) return { error: "Farewell already sent" };

  await farewells.insertOne({
    sessionId: sessionOid,
    userId,
    text,
    sentAt: now,
    createdAt: now,
  });

  if (session.status === "active") {
    await db.collection("sessions").updateOne(
      { _id: sessionOid },
      { $set: { status: "farewell" } }
    );
  }

  const partnerId =
    session.userA.toString() === userId.toString() ? session.userB : session.userA;
  const tokenDoc = await db.collection("device_tokens").findOne({ userId: partnerId });
  if (tokenDoc?.token) {
    await sendSilentPush(context, tokenDoc.token, {
      type: "session.farewell",
      sessionId: sessionOid.toString(),
    });
  }

  return { ok: true, text };
};
