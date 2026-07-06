/*
Script: fix_empty_verification_user_ids.js
Purpose: Scan Firestore verification collections for documents with missing or empty 'userId' fields.

Usage:
1. Ensure you have a Firebase service account JSON and set:
   $env:GOOGLE_APPLICATION_CREDENTIALS = "C:\path\to\serviceAccountKey.json"
2. Install dependencies (once):
   npm install firebase-admin
3. Run the script (dry-run):
   node fix_empty_verification_user_ids.js
4. To actually fix documents by setting userId = doc.id, pass --fix:
   node fix_empty_verification_user_ids.js --fix

Notes:
- The script will print a summary of affected documents.
- When --fix is supplied it will perform updates in Firestore.
- Review findings before using --fix in production.
*/

const admin = require('firebase-admin');
const argv = require('yargs/yargs')(process.argv.slice(2)).argv;

if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
  console.error('ERROR: Please set GOOGLE_APPLICATION_CREDENTIALS to your service account JSON path.');
  process.exit(1);
}

admin.initializeApp({ credential: admin.credential.applicationDefault() });
const db = admin.firestore();

const collections = ['identity_verifications', 'student_verifications', 'verification_applications'];
const dryRun = !argv.fix;

(async () => {
  console.log(`Starting scan (dryRun=${dryRun})...`);

  for (const coll of collections) {
    console.log(`\nScanning collection: ${coll}`);
    const snap = await db.collection(coll).get();
    let count = 0;
    const problematic = [];

    snap.docs.forEach(doc => {
      const data = doc.data();
      const userId = data.userId;
      if (userId === undefined || userId === null || (typeof userId === 'string' && userId.trim() === '')) {
        problematic.push({ id: doc.id, data });
      }
    });

    console.log(`Found ${problematic.length} problematic docs in ${coll}.`);
    for (const p of problematic) {
      console.log(` - docId: ${p.id} userId: ${p.data.userId}`);
    }

    if (!dryRun && problematic.length > 0) {
      console.log('\nApplying fixes: setting userId = doc.id for problematic documents...');
      for (const p of problematic) {
        try {
          await db.collection(coll).doc(p.id).update({ userId: p.id });
          console.log(`Updated ${coll}/${p.id} -> userId='${p.id}'`);
          count++;
        } catch (e) {
          console.error(`Failed to update ${coll}/${p.id}:`, e);
        }
      }
      console.log(`Applied fixes to ${count} documents in ${coll}.`);
    }
  }

  console.log('\nScan complete.');
  process.exit(0);
})();

