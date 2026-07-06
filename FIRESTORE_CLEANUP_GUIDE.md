# Firestore Verification Cleanup Guide

## Problem
When running the verification cleanup script, you get:
```
ERROR: Please set GOOGLE_APPLICATION_CREDENTIALS to your service account JSON path.
```

## Solution: Get Firebase Service Account Key

### Step 1: Download Service Account Key from Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your **UniHub** project
3. Click the **⚙️ Settings icon** (top-left) → **Project Settings**
4. Click the **Service Accounts** tab
5. Click **Generate New Private Key**
6. A JSON file will download to your computer (e.g., `unihub-firebase-adminsdk-xxxxx.json`)
7. **Save this file in a safe location** (do NOT commit it to git!)

### Step 2: Set Environment Variable

**Option A: Temporary (Current Session Only)**
```powershell
$env:GOOGLE_APPLICATION_CREDENTIALS = "C:\path\to\unihub-firebase-adminsdk-xxxxx.json"
```

**Option B: Permanent (All Sessions)**
1. Search for "Edit environment variables" in Windows
2. Click "Edit the system environment variables"
3. Click "Environment Variables..." button
4. Click "New..." under "User variables"
5. Variable name: `GOOGLE_APPLICATION_CREDENTIALS`
6. Variable value: `C:\path\to\unihub-firebase-adminsdk-xxxxx.json`
7. Click OK and restart your terminal

### Step 3: Run the Cleanup Script

**Dry-run (scan only, don't fix)**:
```powershell
cd C:\Users\user.DESKTOP-OMQ89VA\AndroidStudioProjects\unihub_mobile\scripts
node fix_empty_verification_user_ids.js
```

**Actually fix the documents**:
```powershell
cd C:\Users\user.DESKTOP-OMQ89VA\AndroidStudioProjects\unihub_mobile\scripts
node fix_empty_verification_user_ids.js --fix
```

---

## What the Script Does

### Dry-Run (without --fix)
- Scans all verification collections:
  - `identity_verifications`
  - `student_verifications`
  - `verification_applications`
- Identifies documents with missing or empty `userId` fields
- **Does NOT modify any data**
- Reports findings in console

### Fix Mode (with --fix)
- Same scan as dry-run
- For each problematic document found:
  - Sets `userId = document_id`
  - This ensures the userId field is no longer empty
- Logs successful updates
- Fixes the data corruption

---

## Expected Output

### Dry-Run Output Example
```
Starting scan (dryRun=true)...

Scanning collection: identity_verifications
Found 2 problematic docs in identity_verifications.
 - docId: identity_abc123 userId: 
 - docId: identity_def456 userId: 

Scanning collection: student_verifications
Found 0 problematic docs in student_verifications.

Scanning collection: verification_applications
Found 1 problematic docs in verification_applications.
 - docId: app_xyz789 userId: undefined

Scan complete.
```

### Fix Mode Output Example
```
Starting scan (dryRun=false)...

Scanning collection: identity_verifications
Found 2 problematic docs in identity_verifications.
 - docId: identity_abc123 userId: 
 - docId: identity_def456 userId: 

Applying fixes: setting userId = doc.id for problematic documents...
Updated identity_verifications/identity_abc123 -> userId='identity_abc123'
Updated identity_verifications/identity_def456 -> userId='identity_def456'
Applied fixes to 2 documents in identity_verifications.

Scanning collection: student_verifications
Found 0 problematic docs in student_verifications.

Scanning collection: verification_applications
Found 1 problematic docs in verification_applications.
 - docId: app_xyz789 userId: undefined

Applying fixes: setting userId = doc.id for problematic documents...
Updated verification_applications/app_xyz789 -> userId='app_xyz789'
Applied fixes to 1 documents in verification_applications.

Scan complete.
```

---

## Common Issues

### Issue 1: "Cannot find module 'firebase-admin'"
**Solution**: Install dependencies:
```powershell
cd scripts
npm install firebase-admin yargs
```

### Issue 2: "Invalid service account JSON"
**Solution**: Ensure you downloaded the correct file from Firebase Console > Service Accounts > Generate New Private Key

### Issue 3: "Permission denied"
**Solution**: Ensure your Firebase rules allow admin access with the service account. This is normal for admin operations.

---

## Verification After Fix

Once the cleanup is complete:

1. ✅ Return to the app
2. ✅ Open admin verification queue
3. ✅ Try to approve a verification
4. ✅ Should see success (or clear error message if data is still missing)
5. ✅ Check console for debug logs with all IDs and values

---

## Next Steps

1. **Generate service account key** from Firebase Console
2. **Set GOOGLE_APPLICATION_CREDENTIALS** environment variable
3. **Run dry-run** to see how many documents need fixing:
   ```powershell
   node fix_empty_verification_user_ids.js
   ```
4. **Run fix** if problems found:
   ```powershell
   node fix_empty_verification_user_ids.js --fix
   ```
5. **Test the admin approval** to confirm it works

---

## Security Note

🔒 **IMPORTANT**: The Firebase service account JSON contains sensitive credentials:
- ⚠️ **DO NOT** commit it to git
- ⚠️ **DO NOT** share it publicly
- ⚠️ **DO NOT** upload it to repositories
- ✅ **DO** store it in a safe, local directory
- ✅ **DO** use environment variable to reference it

If you accidentally commit it, regenerate the key in Firebase Console immediately.

---

## Questions?

Refer to the complete bug fix documentation: `VERIFICATION_APPROVAL_BUG_FIX.md`

