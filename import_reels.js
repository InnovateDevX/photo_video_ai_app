// Run with: node import_reels.js
// Requirements: npm install firebase-admin

const admin = require("firebase-admin");
const data = require("./firestore_reels_seed.json");

// Replace with the path to your downloaded service account key JSON
const serviceAccount = require("./service-account-key.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function importReels() {
  const batch = db.batch();
  const reels = data.reels;

  reels.forEach((reel) => {
    const docRef = db.collection("reels").doc(); // Auto-generated ID
    batch.set(docRef, reel);
  });

  await batch.commit();
  console.log(`✅ Successfully imported ${reels.length} reels into Firestore!`);
}

importReels().catch(console.error);
