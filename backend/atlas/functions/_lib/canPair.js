const { getISOWeekUTC } = require("./isoWeek");

function canonicalPair(userA, userB) {
  return userA < userB ? [userA, userB] : [userB, userA];
}

async function isBlocked(db, userA, userB) {
  const block = await db.collection("blocks").findOne({
    $or: [
      { blockerId: userA, blockedId: userB },
      { blockerId: userB, blockedId: userA },
    ],
  });
  return Boolean(block);
}

async function hasActiveSession(db, userId) {
  const now = new Date();
  const session = await db.collection("sessions").findOne({
    status: { $in: ["active", "farewell"] },
    expiresAt: { $gt: now },
    $or: [{ userA: userId }, { userB: userId }],
  });
  return Boolean(session);
}

async function pairedThisISOWeek(db, userA, userB) {
  const [a, b] = canonicalPair(userA, userB);
  const { isoWeek, isoWeekYear } = getISOWeekUTC(new Date());
  const hit = await db.collection("pair_history").findOne({
    userA: a,
    userB: b,
    isoWeek,
    isoWeekYear,
  });
  return Boolean(hit);
}

async function canPair(db, userA, userB) {
  if (userA === userB) return false;
  if (await isBlocked(db, userA, userB)) return false;
  if (await hasActiveSession(db, userA)) return false;
  if (await hasActiveSession(db, userB)) return false;
  if (await pairedThisISOWeek(db, userA, userB)) return false;
  return true;
}

function timezoneOffsetMinutes(timezoneId) {
  try {
    const now = new Date();
    const utc = new Date(now.toLocaleString("en-US", { timeZone: "UTC" }));
    const local = new Date(now.toLocaleString("en-US", { timeZone: timezoneId }));
    return Math.round((local - utc) / 60000);
  } catch {
    return 0;
  }
}

function matchScore(a, b) {
  const offsetDiff = Math.abs(
    timezoneOffsetMinutes(a.timezoneId) - timezoneOffsetMinutes(b.timezoneId)
  );
  const countryBonus = a.countryCode !== b.countryCode ? 1000 : 0;
  return offsetDiff * 10 + countryBonus;
}

module.exports = {
  canonicalPair,
  canPair,
  matchScore,
  getISOWeekUTC,
};
