const { partnerUserId } = require("./session");

async function getFarewellTexts(db, session, viewerId) {
  const farewells = db.collection("farewells");
  const sessionId = session._id;

  const mine = await farewells.findOne({ sessionId, userId: viewerId });
  const myFarewellText = mine?.text ?? null;

  let theirFarewellText = null;
  if (session.status === "ended" || session.status === "purged") {
    const partnerId = partnerUserId(session, viewerId);
    const theirs = await farewells.findOne({ sessionId, userId: partnerId });
    theirFarewellText = theirs?.text ?? null;
  }

  return { myFarewellText, theirFarewellText };
}

module.exports = { getFarewellTexts };
