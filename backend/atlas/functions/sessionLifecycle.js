// Atlas Scheduled Trigger: sessionLifecycle
// Run every 15 minutes — farewell window, session end, media purge.
//
// Atlas App Services → Triggers → Scheduled → link this function.

const { purgeSessionMedia } = require("./_lib/purge");
const { sendAlertPush, sendSilentPush } = require("./_lib/apns");

const DB_NAME = "povstranger";
const FAREWELL_WINDOW_MS = 2 * 60 * 60 * 1000;
const PURGE_GRACE_MS = 60 * 60 * 1000;

exports = async function (context) {
  const db = context.services.get("mongodb-atlas").db(DB_NAME);
  const sessions = db.collection("sessions");
  const now = new Date();
  const farewellCutoff = new Date(now.getTime() + FAREWELL_WINDOW_MS);

  // active → farewell (T-2h)
  const enteringFarewell = await sessions
    .find({
      status: "active",
      expiresAt: { $gt: now, $lte: farewellCutoff },
      farewellNotified: { $ne: true },
    })
    .toArray();

  for (const session of enteringFarewell) {
    await sessions.updateOne(
      { _id: session._id },
      { $set: { status: "farewell", farewellNotified: true } }
    );
    await notifyBothUsers(db, context, session, {
      title: "Last hours together",
      body: "You can send one farewell message before they disappear.",
      type: "session.farewell",
      sessionId: session._id.toString(),
    });
  }

  // active/farewell → ended
  const ending = await sessions
    .find({
      status: { $in: ["active", "farewell"] },
      expiresAt: { $lte: now },
    })
    .toArray();

  for (const session of ending) {
    await sessions.updateOne(
      { _id: session._id },
      { $set: { status: "ended", endedAt: now } }
    );
    await notifyBothUsers(db, context, session, {
      title: "They're gone",
      body: "Your stranger has vanished. Open POV-Stranger to read their message.",
      type: "session.ended",
      sessionId: session._id.toString(),
    });
  }

  // ended → purged (after grace period)
  const purging = await sessions
    .find({
      status: "ended",
      expiresAt: { $lte: new Date(now.getTime() - PURGE_GRACE_MS) },
    })
    .toArray();

  for (const session of purging) {
    await purgeSessionMedia(db, session._id);
    await sessions.updateOne({ _id: session._id }, { $set: { status: "purged" } });
  }

  return {
    farewellTransitions: enteringFarewell.length,
    endedSessions: ending.length,
    purgedSessions: purging.length,
  };
};

async function notifyBothUsers(db, context, session, { title, body, type, sessionId }) {
  const userIds = [session.userA, session.userB];
  for (const userId of userIds) {
    const tokenDoc = await db.collection("device_tokens").findOne({ userId });
    if (!tokenDoc?.token) continue;

    if (type === "session.ended") {
      await sendAlertPush(context, tokenDoc.token, { title, body, type, sessionId });
    } else {
      await sendSilentPush(context, tokenDoc.token, { type, sessionId });
    }
  }
}
