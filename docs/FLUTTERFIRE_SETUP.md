# FlutterFire CLI Setup — NerZero MRV

This document walks Manuel through executing `flutterfire configure` on a local workstation to register per-platform Firebase apps and regenerate `lib/firebase_options.dart` with the canonical multi-platform configuration.

The sandbox environment cannot perform this step because `flutterfire configure` requires interactive Google OAuth (browser-based login). Run these commands on your own machine.

---

## Prerequisites

| Tool | Minimum Version | Install Command |
|------|-----------------|-----------------|
| Flutter SDK | 3.35.4 (locked) | https://docs.flutter.dev/get-started/install |
| Dart SDK | 3.9.2 (bundled with Flutter) | — |
| Node.js | 18+ | https://nodejs.org/ |
| Firebase CLI | 14.x | `npm install -g firebase-tools` |
| FlutterFire CLI | 1.3.2+ | `dart pub global activate flutterfire_cli` |

Add the Dart pub-cache bin directory to your PATH (one-time, per OS):

**macOS / Linux** — add to `~/.zshrc` or `~/.bashrc`:
```bash
export PATH="$PATH:$HOME/.pub-cache/bin"
```

**Windows (PowerShell)** — add to `$PROFILE`:
```powershell
$env:Path += ";$env:LOCALAPPDATA\Pub\Cache\bin"
```

---

## Step-by-Step Execution

### 1. Authenticate the Firebase CLI

```bash
firebase login
```

This opens a browser. Sign in with the Google account that owns the `nzcsmrvmobile` Firebase project (or has at least Editor access). The CLI stores credentials in `~/.config/configstore/firebase-tools.json`.

Verify access to the project:
```bash
firebase projects:list
```
You should see `nzcsmrvmobile` in the output.

### 2. Clone the Repository

```bash
git clone https://github.com/moche77/app.nzcs.mrv.git
cd app.nzcs.mrv
```

### 3. Run `flutterfire configure`

From the repository root:

```bash
flutterfire configure --project=nzcsmrvmobile
```

The CLI will:
1. Detect existing platforms in the project (`android`, `ios`, `web`, `macos`, `linux`, `windows`).
2. Prompt you to select which platforms to register. **Select at minimum `android` and `ios`**. Select `web` if you intend to build a web dashboard.
3. For each selected platform, register an app variant in your Firebase project (if one doesn't already exist).
4. Write a new `lib/firebase_options.dart` containing real `FirebaseOptions` for every selected platform.
5. Place platform-specific config files in the correct locations:
   - `android/app/google-services.json`
   - `ios/Runner/GoogleService-Info.plist`
   - `macos/Runner/GoogleService-Info.plist` (if selected)
   - `web/index.html` is updated with Firebase JS SDK config (if selected)

When prompted for **Android package name**, the CLI auto-detects `app.nzcsmrv.mobile` from `android/app/build.gradle.kts`. Confirm this.

When prompted for **iOS bundle ID**, set it to `app.nzcsmrv.mobile` to match the Android package and the existing Firebase configuration.

### 4. Verify the Generated File

Open `lib/firebase_options.dart` and confirm it contains real configuration blocks for each platform you registered (not the hand-authored stub currently in the repo):

```dart
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform { ... }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSy...',                              // real key
    appId: '1:649373538088:android:...',
    messagingSenderId: '649373538088',
    projectId: 'nzcsmrvmobile',
    storageBucket: 'nzcsmrvmobile.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(...);  // NEW
  static const FirebaseOptions web = FirebaseOptions(...);  // NEW if selected
}
```

### 5. Commit and Push

```bash
git add lib/firebase_options.dart \
        android/app/google-services.json \
        ios/Runner/GoogleService-Info.plist \
        ios/firebase_app_id_file.json \
        web/index.html \
        firebase.json \
        .firebaserc
git status   # verify only Firebase-related files are staged
git commit -m "Register per-platform Firebase apps via FlutterFire CLI"
git push origin main
```

The next sandbox build from CI/cloud will pick up the canonical multi-platform configuration automatically.

---

## Domain-Restricted Authentication (Optional Hardening)

Independent of the CLI work, you should enable Firebase Authentication and restrict signups to the `netzerocarbon.solutions` domain. The Flutter app already enforces this at the application layer (see `IdentityPolicy.isEmailAllowed` in `lib/models/user_role.dart`), but Firebase-side enforcement adds defence in depth.

### Option A — Allow-list via Firebase Authentication Settings

1. Firebase Console → **Authentication** → **Sign-in method** → **Email/Password** → Enable.
2. Firebase Console → **Authentication** → **Settings** → **Authorized domains**. Remove `localhost` for production; keep `nzcsmrvmobile.firebaseapp.com`.
3. There is **no built-in email-domain whitelist** in Firebase Auth. To enforce server-side:

### Option B — Cloud Function blocking signup

Deploy a `beforeUserCreated` Auth blocking function that rejects any non-`@netzerocarbon.solutions` and non-Owner sign-up. Sample:

```javascript
// functions/index.js (Node 18)
const { beforeUserCreated } = require("firebase-functions/v2/identity");
const { HttpsError } = require("firebase-functions/v2/https");

const OWNER_EMAIL = "manuel@titantradersltd.com";
const ALLOWED_DOMAIN = "@netzerocarbon.solutions";

exports.enforceDomain = beforeUserCreated((event) => {
  const email = (event.data.email || "").toLowerCase();
  if (email === OWNER_EMAIL) return;
  if (email.endsWith(ALLOWED_DOMAIN)) return;
  throw new HttpsError("invalid-argument",
    `Email must be ${ALLOWED_DOMAIN} or the Owner identity. ` +
    `Contact ${OWNER_EMAIL} for access.`);
});
```

Deploy:
```bash
cd functions
npm install
firebase deploy --only functions:enforceDomain
```

### Option C — Cloud Function adding `developer`/`admin` custom claims

Once a user is created with an `@netzerocarbon.solutions` email, you can assign role claims that the Flutter app reads via Firebase ID-token claims:

```javascript
const admin = require("firebase-admin");
admin.initializeApp();

exports.assignDefaultRole = beforeUserCreated(async (event) => {
  const email = (event.data.email || "").toLowerCase();
  let role = "department_user";
  if (email === OWNER_EMAIL) role = "owner";
  // First Admin must be promoted manually by the Owner via console.

  await admin.auth().setCustomUserClaims(event.data.uid, { role });
});
```

This gives you cross-device role propagation; the in-app Hive role mapping continues to serve as the offline-first source of truth.

---

## Firestore Security Rules (Production)

Once authentication is live, replace the development rules with:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    function isAuthenticated() {
      return request.auth != null;
    }
    function isOwner() {
      return request.auth.token.email == "manuel@titantradersltd.com";
    }
    function isAdmin() {
      return request.auth.token.role == "administrator"
          || request.auth.token.role == "owner";
    }
    function isNzcsDomain() {
      return request.auth.token.email.matches(".*@netzerocarbon\\.solutions$")
          || isOwner();
    }

    // All MRV collections — Admins read/write, Department users write own dept,
    // Owner has full authority.
    match /{module}/{docId} {
      allow read: if isAuthenticated() && isNzcsDomain();
      allow create, update: if isAuthenticated() && isNzcsDomain() && isAdmin();
      allow delete: if isOwner();
    }

    // Reports collection — Owner only.
    match /reports/{reportId} {
      allow read, write: if isOwner();
    }
  }
}
```

Deploy:
```bash
firebase deploy --only firestore:rules
```

---

## Troubleshooting

**Error: `Failed to authenticate, have you run firebase login?`**
→ Run `firebase login --reauth` and try again.

**Error: `Could not find project nzcsmrvmobile`**
→ Your Google account is not a member of the Firebase project. Add it via Firebase Console → Project Settings → Users and permissions.

**FlutterFire generates an empty/partial `firebase_options.dart`**
→ The selected platforms in the CLI prompt were too few. Re-run and select all relevant platforms.

**iOS Pod install fails after configure**
→ Run `cd ios && pod install --repo-update` then rebuild.

---

## Reference

- Official docs: https://firebase.flutter.dev/docs/cli/
- FlutterFire repository: https://github.com/firebase/flutterfire
- Project: `nzcsmrvmobile`
- App ID (Android): `1:649373538088:android:d251c500785d01c234221d`
- Package: `app.nzcsmrv.mobile`
