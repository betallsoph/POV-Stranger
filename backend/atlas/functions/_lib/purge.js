const { GridFSBucket } = require("mongodb");

async function purgeSessionMedia(db, sessionId) {
  const uploads = await db.collection("hour_uploads").find({ sessionId }).toArray();
  const bucket = new GridFSBucket(db, { bucketName: "photos" });

  for (const upload of uploads) {
    try {
      await bucket.delete(upload.gridfsFileId);
    } catch {
      // File may already be deleted by TTL.
    }
  }

  await db.collection("hour_uploads").deleteMany({ sessionId });
  await db.collection("farewells").deleteMany({ sessionId });
}

module.exports = { purgeSessionMedia };
