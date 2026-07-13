// Atlas Function: getActiveSession
const DB_NAME = "povstranger";

exports = async function (arg, context) {
  const userId = context.user?.id;
  if (!userId) return { error: "Unauthorized" };

  const db = context.services.get("mongodb-atlas").db(DB_NAME);
  const now = new Date();

  const session = await db.collection("sessions").findOne({
    status: { $in: ["active", "farewell", "ended"] },
    expiresAt: { $gt: new Date(now.getTime() - 60 * 60 * 1000) },
    $or: [{ userA: userId }, { userB: userId }],
  });

  if (!session) return { session: null };

  return { session: serializeSession(session, userId) };
};

function serializeSession(session, viewerId) {
  const isUserA = session.userA.toString() === viewerId.toString();
  const partnerCountry = isUserA ? session.userBCountry : session.userACountry;
  const partnerTimezone = isUserA ? session.userBTimezone : session.userATimezone;

  return {
    id: session._id.toString(),
    startedAt: session.startedAt,
    expiresAt: session.expiresAt,
    status: session.status,
    partnerCountryCode: partnerCountry,
    partnerCountryName: partnerCountry,
    partnerTimeZoneIdentifier: partnerTimezone,
    partnerWeatherSummary: "—",
    partnerDistanceKm: 10000,
  };
}
