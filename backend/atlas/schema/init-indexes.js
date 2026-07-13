// POV-Stranger — MongoDB index & TTL setup
// Run: mongosh "<connection-string>" --file backend/atlas/schema/init-indexes.js

const dbName = "povstranger";
const db = db.getSiblingDB(dbName);

print(`Setting up indexes on database: ${dbName}`);

// users
db.users.createIndex({ createdAt: 1 });
db.users.createIndex({ isBanned: 1 });

// device_tokens
db.device_tokens.createIndex({ userId: 1 }, { unique: true });
db.device_tokens.createIndex({ token: 1 });

// match_queue
db.match_queue.createIndex({ enqueuedAt: 1 });
db.match_queue.createIndex({ countryCode: 1, timezoneId: 1 });

// sessions
db.sessions.createIndex({ userA: 1, startedAt: -1 });
db.sessions.createIndex({ userB: 1, startedAt: -1 });
db.sessions.createIndex({ expiresAt: 1 });
db.sessions.createIndex({ status: 1, expiresAt: 1 });

// hour_uploads — TTL 25 hours
db.hour_uploads.createIndex(
  { sessionId: 1, userId: 1, hourIndex: 1 },
  { unique: true }
);
db.hour_uploads.createIndex(
  { createdAt: 1 },
  { expireAfterSeconds: 90000 }
);

// farewells — TTL 25 hours
db.farewells.createIndex({ sessionId: 1, userId: 1 }, { unique: true });
db.farewells.createIndex(
  { createdAt: 1 },
  { expireAfterSeconds: 90000 }
);

// pair_history — weekly rematch (kept permanently)
db.pair_history.createIndex({ userA: 1, userB: 1, isoWeekYear: 1, isoWeek: 1 });
db.pair_history.createIndex({ matchedAt: -1 });

// blocks
db.blocks.createIndex({ blockerId: 1, blockedId: 1 }, { unique: true });
db.blocks.createIndex({ blockedId: 1 });

// reports
db.reports.createIndex({ createdAt: -1 });
db.reports.createIndex({ reporterId: 1 });

print("Done.");
