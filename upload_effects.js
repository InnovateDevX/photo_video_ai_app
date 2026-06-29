// Run with: node upload_effects.js
// Requirements: npm install firebase-admin

const admin = require("firebase-admin");
const path = require("path");
const fs = require("fs");

// Path to service account key
const SERVICE_ACCOUNT_PATH = "./service-account-key.json";
const BUCKET_NAME = "imagegen-trail.firebasestorage.app";
const LOCAL_EFFECTS_DIR = path.join(__dirname, "assets", "effects");

// Check for service account key
if (!fs.existsSync(SERVICE_ACCOUNT_PATH)) {
  console.error("❌ Error: service-account-key.json not found in the root directory!");
  console.error("Please download your Firebase Service Account Key JSON from the Firebase Console:");
  console.error("Project Settings -> Service Accounts -> Generate New Private Key");
  console.error(`And save it as: ${path.resolve(SERVICE_ACCOUNT_PATH)}`);
  process.exit(1);
}

const serviceAccount = require(SERVICE_ACCOUNT_PATH);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  storageBucket: BUCKET_NAME,
});

const bucket = admin.storage().bucket();

// Helper to recursively walk a directory and list all files
function getFilesRecursively(dir, fileList = []) {
  const files = fs.readdirSync(dir);
  files.forEach((file) => {
    const filePath = path.join(dir, file);
    if (fs.statSync(filePath).isDirectory()) {
      getFilesRecursively(filePath, fileList);
    } else {
      fileList.push(filePath);
    }
  });
  return fileList;
}

async function uploadEffects() {
  if (!fs.existsSync(LOCAL_EFFECTS_DIR)) {
    console.error(`❌ Local effects directory not found at: ${LOCAL_EFFECTS_DIR}`);
    process.exit(1);
  }

  console.log("🔍 Scanning local effects directory...");
  const localFiles = getFilesRecursively(LOCAL_EFFECTS_DIR);
  
  // Filter for PNG files only
  const pngFiles = localFiles.filter(file => file.toLowerCase().endsWith('.png'));
  console.log(`Found ${pngFiles.length} PNG files to upload.`);

  let successCount = 0;
  let errorCount = 0;

  for (let i = 0; i < pngFiles.length; i++) {
    const localPath = pngFiles[i];
    
    // Get relative path from assets/effects
    const relativePath = path.relative(LOCAL_EFFECTS_DIR, localPath);
    
    // Normalize path to use forward slashes for Firebase Storage
    const remotePath = "effects/" + relativePath.split(path.sep).join("/");

    console.log(`[${i + 1}/${pngFiles.length}] Uploading: ${relativePath} -> ${remotePath}...`);

    try {
      await bucket.upload(localPath, {
        destination: remotePath,
        metadata: {
          contentType: "image/png",
          cacheControl: "public, max-age=31536000",
        },
      });
      console.log(`  ✓ Success`);
      successCount++;
    } catch (error) {
      console.error(`  ✗ Failed to upload ${relativePath}:`, error.message);
      errorCount++;
    }
  }

  console.log("\n--- Upload Summary ---");
  console.log(`Total Files: ${pngFiles.length}`);
  console.log(`Successfully Uploaded: ${successCount}`);
  console.log(`Errors/Failed: ${errorCount}`);
  
  if (errorCount === 0) {
    console.log("🎉 All effect files uploaded successfully!");
  } else {
    console.log("⚠️ Some files failed to upload. Please check the logs above.");
  }
}

uploadEffects().catch((err) => {
  console.error("❌ Script crashed with error:", err);
});
