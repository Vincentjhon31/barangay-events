# 📦 Barangay Events – Release & CI/CD Cheat‑Sheet

This document shows the exact terminal commands you need to run **after you have made changes** to the app, bumped the version, and want to push a new release that will be built and published automatically by GitHub Actions.

---

## 📋 Overview of the workflow  

1. **Update version** in `pubspec.yaml` (optional but recommended).  
2. **Stage, commit, and push** changes → triggers GitHub Actions.  
3. GitHub Actions:  
   * Checks out code, sets up Flutter/JDK.  
   * Reads the version from `pubspec.yaml`.  
   * Builds a release APK (`flutter build apk --release --split-per-abi=false`).  
   * Creates a GitHub Release tagged `v<version>`.  
   * Uploads `app-release.apk` as an asset.  
4. **Monitor** the workflow run (Actions tab).  
5. **Download** the APK from the newly created release.  

If you have added the four signing secrets (`KEYSTORE_FILE`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`) the APK will be signed with your keystore; otherwise a debug keystore is generated automatically (suitable for testing on devices that allow “unknown sources”).

---

## 1️⃣  Bump the version (optional)

Edit `pubspec.yaml` manually **or** use one of the snippets below.

### Increment the patch number (e.g. `1.0.0+1 → 1.0.1+2`)

```bash
# Replace <new-version> with the exact string you want, e.g. "1.0.1+2"
sed -i "s/^version: .*/version: <new-version>/" pubspec.yaml
```

### Example – bump patch & increase build number

```bash
# Grab current version
CURRENT=$(grep '^version:' pubspec.yaml | cut -d' ' -f2)
# Split into version and build
VER=${CURRENT%+*}
BUILD=${CURRENT#*+}
# Increment patch (last number) and build
PATCH=$(echo $VER | cut -d'.' -f3)
NEW_PATCH=$((PATCH+1))
NEW_VER=$(echo $VER | cut -d'.' -f1-2).$NEW_PATCH
NEW_BUILD=$((BUILD+1))
NEW_VERSION="${NEW_VER}+${NEW_BUILD}"
# Write back
sed -i "s/^version: .*/version: $NEW_VERSION/" pubspec.yaml
echo "New version set to $NEW_VERSION"
```

> **Tip:** Keep the `+<build>` part – the workflow uses it for the Git tag (e.g. `v1.0.1+2`). If you prefer tags without the `+build`, adjust the “Extract version” step in `.github/workflows/release.yml` (but the current workflow works fine as‑is).

---

## 2️⃣  Stage, commit, and push

```bash
# 1️⃣  Go to the project root (adjust if you cloned elsewhere)
cd /c/Windows_Applications/barangay_events

# 2️⃣  Review what changed (optional but recommended)
git status

# 3️⃣  Stage all modified / new files
git add .

# 4️⃣  Commit with a clear message
#    Replace <new-version> with the version you just set, and add a short summary.
git commit -m "Release v$(grep '^version:' pubspec.yaml | cut -d' ' -f2): <short description of changes>"
# Example:
# git commit -m "Release v1.0.1+2: add RSVP button and fix typo in home screen"

# 5️⃣  Push to GitHub – this triggers the Actions workflow
git push origin HEAD   # pushes the current branch to its upstream (usually main/master)
```

> **What happens next?**  
> As soon as the push reaches GitHub, the workflow defined in `.github/workflows/release.yml` starts. You can watch its progress in the **Actions** tab of your repository.

---

## 3️⃣  Monitor the workflow (optional but handy)

Open the Actions page in your default browser:

```bash
# Replace <your-username> and <repo-name> with your actual values
start https://github.com/<your-username>/<repo-name>/actions
```

* Example: `start https://github.com/Vincentjhon31/barangay-events/actions`

In the Actions tab you’ll see the latest workflow run. Click it to view the live log. When it finishes with a **green check mark**, the release is ready.

---

## 4️⃣  Grab the generated APK

Open the Releases page:

```bash
start https://github.com/<your-username>/<repo-name>/releases
```

You should see a new release titled something like `Release v1.0.1+2`.  
Under **Assets** you’ll find `app-release.apk`.  

- **Download** it and distribute it to your barangay users (email, WhatsApp, Play Store internal testing, etc.).  
- If you added the signing secrets, this APK is properly signed and can be uploaded to the Google Play Store.  
- If you relied on the auto‑generated debug keystore, the APK works on devices that allow installation from unknown sources (enable “Install unknown apps” in Settings → Apps → *[your browser/file manager]* → Allow).

---

## 5️⃣  (Optional) Add signing secrets for a Play‑Store‑ready APK  

If you want a **production‑signed** APK (recommended for public distribution), add these four repository secrets **once**:

| Secret Name          | How to obtain the value |
|----------------------|--------------------------|
| `KEYSTORE_FILE`      | Base64‑encoded contents of your keystore file (`keystore.jks`).<br>Generate with: `base64 -i path/to/keystore.jks -o -` (Linux/macOS) or use an online Base64 encoder. |
| `KEYSTORE_PASSWORD`  | Password for the keystore. |
| `KEY_ALIAS`          | Alias of the key inside the keystore. |
| `KEY_PASSWORD`       | Password for the specific key (often same as the keystore password). |

**Steps to add them:**

1. Go to your repository on GitHub → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**.  
2. Enter the name (e.g., `KEYSTORE_FILE`) and paste the value.  
3. Repeat for the other three secrets.  

After they are stored, the next workflow run will automatically detect them and use your keystore to sign the APK.

---

## 📋 Quick “One‑liner” (if you already edited the version manually)

```bash
cd /c/Windows_Applications/barangay_events && git add . && git commit -m "Release v$(grep '^version:' pubspec.yaml | cut -d' ' -f2): automated version bump" && git push origin HEAD
```

After running that, just watch the **Actions** tab and download the APK from the **Releases** page.

---

### 🎉 That’s it!

Keep this `RELEASE_GUIDE.md` file in your repo (or copy it to your personal notes) and follow the steps each time you want to ship a new version. If anything goes wrong, check the **Logs** of the failed workflow run – they’ll tell you exactly what needs fixing (missing secret, version format, etc.).  

Happy coding and releasing! 🚀
