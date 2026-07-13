// Atlas Function: registerDeviceToken
const DB_NAME = "povstranger";

exports = async function (arg, context) {
  const userId = context.user?.id;
  if (!userId) return { error: "Unauthorized" };

  const token = arg?.token;
  if (!token || typeof token !== "string") {
    return { error: "Missing token" };
  }

  const db = context.services.get("mongodb-atlas").db(DB_NAME);
  const now = new Date();

  await db.collection("device_tokens").updateOne(
    { userId },
    { $set: { token, updatedAt: now } },
    { upsert: true }
  );

  return { ok: true };
};
