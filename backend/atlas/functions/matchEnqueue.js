// Atlas Function: matchEnqueue
// Enqueue user for matching or pair immediately with best candidate.
//
// Deploy: Atlas App Services → Functions → matchEnqueue
// Auth: requires logged-in user (context.user.id)

const { canPair, matchScore, canonicalPair, getISOWeekUTC } = require("./canPair");

const SESSION_HOURS = 24;
const DB_NAME = "povstranger";

exports = async function (arg, context) {
  const userId = context.user?.id;
  if (!userId) {
    return { error: "Unauthorized" };
  }

  const countryCode = arg?.countryCode || "XX";
  const timezoneId = arg?.timezoneId || "UTC";

  const cluster = context.services.get("mongodb-atlas");
  const db = cluster.db(DB_NAME);
  const users = db.collection("users");
  const queue = db.collection("match_queue");
  const sessions = db.collection("sessions");
  const pairHistory = db.collection("pair_history");

  const now = new Date();

  await users.updateOne(
    { _id: userId },
    {
      $set: { countryCode, timezoneId, updatedAt: now },
      $setOnInsert: { createdAt: now, isBanned: false },
    },
    { upsert: true }
  );

  const existing = await sessions.findOne({
    status: { $in: ["active", "farewell"] },
    expiresAt: { $gt: now },
    $or: [{ userA: userId }, { userB: userId }],
  });

  if (existing) {
    return {
      status: "matched",
      session: serializeSession(existing, userId),
    };
  }

  const candidates = await queue.find({ userId: { $ne: userId } }).toArray();
  let best = null;
  let bestScore = -1;

  const me = { userId, countryCode, timezoneId };

  for (const candidate of candidates) {
    if (!(await canPair(db, userId, candidate.userId))) continue;
    const score = matchScore(me, candidate);
    if (score > bestScore) {
      bestScore = score;
      best = candidate;
    }
  }

  if (best) {
    const [userA, userB] = canonicalPair(userId, best.userId);
    const startedAt = now;
    const expiresAt = new Date(startedAt.getTime() + SESSION_HOURS * 60 * 60 * 1000);
    const { isoWeek, isoWeekYear } = getISOWeekUTC(now);

    const userADoc = userA === userId ? me : best;
    const userBDoc = userB === userId ? me : best;

    const sessionDoc = {
      userA,
      userB,
      startedAt,
      expiresAt,
      status: "active",
      userACountry: userADoc.countryCode,
      userBCountry: userBDoc.countryCode,
      userATimezone: userADoc.timezoneId,
      userBTimezone: userBDoc.timezoneId,
      isoWeek,
      isoWeekYear,
      createdAt: now,
    };

    const insertResult = await sessions.insertOne(sessionDoc);
    const sessionId = insertResult.insertedId;

    await pairHistory.insertOne({
      userA,
      userB,
      sessionId,
      matchedAt: now,
      isoWeek,
      isoWeekYear,
    });

    await queue.deleteMany({ userId: { $in: [userId, best.userId] } });

    const created = await sessions.findOne({ _id: sessionId });
    return {
      status: "matched",
      session: serializeSession(created, userId),
    };
  }

  await queue.updateOne(
    { userId },
    {
      $set: { countryCode, timezoneId, enqueuedAt: now },
    },
    { upsert: true }
  );

  return { status: "waiting" };
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
    partnerCountryName: countryCodeToName(partnerCountry),
    partnerTimeZoneIdentifier: partnerTimezone,
    partnerWeatherSummary: "—",
    partnerDistanceKm: estimateDistanceKm(
      isUserA ? session.userACountry : session.userBCountry,
      partnerCountry
    ),
  };
}

function countryCodeToName(code) {
  const map = {
    IS: "Iceland",
    BR: "Brazil",
    JP: "Japan",
    NO: "Norway",
    KE: "Kenya",
    VN: "Vietnam",
    US: "United States",
  };
  return map[code] || code;
}

function estimateDistanceKm(codeA, codeB) {
  const centroids = {
    VN: { lat: 14.0583, lon: 108.2772 },
    IS: { lat: 64.9631, lon: -19.0208 },
    BR: { lat: -14.235, lon: -51.9253 },
    JP: { lat: 36.2048, lon: 138.2529 },
    NO: { lat: 60.472, lon: 8.4689 },
    KE: { lat: -0.0236, lon: 37.9062 },
    US: { lat: 37.0902, lon: -95.7129 },
  };
  const a = centroids[codeA] || centroids.VN;
  const b = centroids[codeB] || centroids.IS;
  return Math.round(haversineKm(a.lat, a.lon, b.lat, b.lon));
}

function haversineKm(lat1, lon1, lat2, lon2) {
  const R = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;
  const x =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLon / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(x));
}
