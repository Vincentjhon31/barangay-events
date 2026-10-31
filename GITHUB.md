# GitHub Push & Release Guide

Quick reference for pushing updates and cutting app releases for **barangay-events**.
All commands are for PowerShell, run from the project root (`c:\Windows_Applications\barangay_events`).

---

## 1. Pushing a normal update (no release)

Use this when you changed code but do **not** want to ship a new APK to users yet.

```powershell
# 1. See what changed
git status
git diff

# 2. Stage the files
git add .          # everything, or list specific files: git add lib/main.dart

# 3. Double-check what is staged (make sure no secrets/junk files)
git status

# 4. Commit with a clear message
git commit -m "fix: describe what you changed here"

# 5. Push to GitHub
  git push origin main
```

### Commit message style used in this repo

| Prefix      | When to use                          | Example                                     |
| ----------- | ------------------------------------ | ------------------------------------------- |
| `feat:`     | New feature                          | `feat: add event details view modal`        |
| `fix:`      | Bug fix                              | `fix: tab bar highlight not updating`       |
| `chore:`    | Maintenance, configs, cleanup        | `chore: remove unused CI workflow`          |
| `refactor:` | Code restructure, no behavior change | `refactor: extract liquid-glass components` |

> Pushing to `main` alone does **NOT** build an APK or notify users.
> Only a **tag** starting with `v` triggers the release workflow.

---

## 2. Releasing a new version of the app

This is the flow that builds the signed APK and publishes it so the app's
built-in updater ("Update available" banner) can see it.

### How it works in this project

1. `pubspec.yaml` holds the version: `version: 1.1.1+8` → format is `major.minor.patch+build`.
2. Pushing a tag named `v*` (e.g. `v1.1.2+9`) triggers `.github/workflows/release.yml`.
3. The workflow builds a **signed release APK** and the **Windows installer**, uploads both to the download page **https://calendar.bongabong.gov.ph/download/** (with the version's "What's new" notes from `assets/whats_new.md`), and also creates a **GitHub Release** with them attached.
4. The app (1.18 and newer) checks `https://calendar.bongabong.gov.ph/download/latest.json` on startup and compares that version with its own — if it's newer, users see the update prompt. (1.17 and older check GitHub's `releases/latest` instead — see section 5.)
5. After both builds, everyone gets an "update available" notification.

### Rules for the version number

- The tag **must exactly match** the version in `pubspec.yaml`, with a `v` in front.
  - `pubspec.yaml`: `version: 1.1.2+9` → tag: `v1.1.2+9`
- **Always increase the build number** (the part after `+`) — never reuse one.
- The updater compares `major.minor.patch.build`, so the new tag must be higher than the last one in at least one of those numbers.
- When to bump what:
  - `major` (1.x.x) — huge redesign or breaking change
  - `minor` (x.1.x) — new feature
  - `patch` (x.x.1) — bug fix
  - `build` (+9) — increases **every release**, no exceptions

### Step-by-step release

```powershell
# 0. Make sure everything is committed and pushed first (see section 1)
git status                # should say "working tree clean"

# 1. Edit pubspec.yaml — change the version line, e.g.:
#    version: 1.1.1+8  ->  version: 1.1.2+9

# 2. (Recommended) sanity check before releasing
flutter analyze
flutter test

# 3. Commit the version bump
git add pubspec.yaml
git commit -m "chore: bump version to 1.1.2+9"
git push origin main

# 4. Create the tag (MUST match pubspec version, with a leading v)
git tag v1.1.2+9

# 5. Push the tag — THIS is what triggers the release build
git push origin v1.1.2+9
```

### After pushing the tag

1. Go to **https://github.com/Vincentjhon31/barangay-events/actions** and watch the **Release** workflow (takes several minutes — it runs an Android job and a Windows job, the Windows one starts after the Android one finishes).
2. When it turns green, open **https://calendar.bongabong.gov.ph/download/** — the new version should be at the top with **Download for Android** and **Download for Windows** (a proper installer, not a zip — running it over an existing install upgrades it in place), and its notes under What's new.
3. Open the app on a phone with the old version — it should show the "Update available" banner/dialog.

---

## 3. If something goes wrong

### The workflow failed (red X in Actions)

- Open the failed run in the Actions tab and read the log of the failing step.
- Common causes: missing signing secrets (`KEYSTORE_FILE`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD` in repo **Settings → Secrets and variables → Actions**), a missing or wrong `RELEASE_UPLOAD_SECRET` (the "Publish … to the download page" steps — see `hostinger/README.md`, "App downloads"), or a build error you didn't catch locally.
- Fix the problem, commit, push, then delete and recreate the tag (below) to rerun the release.

### Redo a bad tag/release

```powershell
# Delete the tag locally and on GitHub
git tag -d v1.1.2+9
git push origin --delete v1.1.2+9

# If a broken Release was already created, delete it on the
# GitHub Releases page too (Releases -> the release -> Delete).

# Then fix your code, commit, push, and tag again
git tag v1.1.2+9
git push origin v1.1.2+9
```

### I tagged the wrong commit

Same as above — delete the tag, make sure `main` has the right code and you have pulled/pushed it, then tag again.

### Users don't see the update

- The tag must be **higher** than the version installed on the phone (check `major.minor.patch+build`).
- The download page must show the new version (the workflow's "Publish" steps must be green). Check https://calendar.bongabong.gov.ph/download/latest.json.
- Phones on **1.17 or older** still look at GitHub instead — see section 5.

---

## 4. Quick cheat sheet

```powershell
# Normal update
git add . ; git commit -m "fix: ..." ; git push origin main

# Release (after bumping version in pubspec.yaml to X.Y.Z+N)
git add pubspec.yaml
git commit -m "chore: bump version to X.Y.Z+N"
git push origin main
git tag vX.Y.Z+N
git push origin vX.Y.Z+N
```

---

## 5. Making the code repository private

Downloads and update checks live on **calendar.bongabong.gov.ph** since 1.18, so the code can be private. Two things still point at this repository's public name, and both keep working through a small **public** repository that holds **no code** (`scripts/public-stub/`):

- **Old links and printed QR codes** (`vincentjhon31.github.io/barangay-events/…`) — GitHub Pages can't publish from a private repository on a free account, so the public one serves redirect pages instead.
- **Installs on 1.17 or older** ask GitHub's `barangay-events/releases/latest` for updates. The public repository gets one release — 1.18.0, the first version that checks the download page — so they update once and never ask GitHub again.

**Do this only after 1.18.0 is released and on the download page.** Run from the repository folder:

```powershell
# 1. Rename the code repository (secrets, Actions and history move with it)
gh repo rename ecalendar-source --repo Vincentjhon31/barangay-events --yes

# 2. IMPORTANT, before step 4: point this clone (and any other clone, on any
#    computer) at the new name. Otherwise a later push would go to the
#    PUBLIC repository created in step 4.
git remote set-url origin https://github.com/Vincentjhon31/ecalendar-source.git
git remote -v

# 3. Make it private (its GitHub Pages site goes away with this)
gh repo edit Vincentjhon31/ecalendar-source --visibility private --accept-visibility-change-consequences

# 4. Create the public stub under the OLD name, with GitHub Pages from /docs
python scripts/public-stub/make_stub.py ../barangay-events-public
cd ../barangay-events-public
git init -b main
git add .
git commit -m "Downloads moved to calendar.bongabong.gov.ph"
gh repo create Vincentjhon31/barangay-events --public --source . --push --description "eBongabong Calendar - download at https://calendar.bongabong.gov.ph/download/"
gh api -X POST repos/Vincentjhon31/barangay-events/pages -f "source[branch]=main" -f "source[path]=/docs"

# 5. The one bridge release for old installs (use the real 1.18.0 tag)
gh release download v1.18.0+30 --repo Vincentjhon31/ecalendar-source -p "*.apk" -p "*-setup.exe"
python ../barangay_events/scripts/whats_new_for_release.py v1.18.0+30 > notes.txt
# Wrap the notes in the markers old apps read, then publish:
#   ## What's new / <!-- whats-new --> / (notes.txt) / <!-- /whats-new --> /
#   Download at https://calendar.bongabong.gov.ph/download/
gh release create v1.18.0+30 --repo Vincentjhon31/barangay-events --title "v1.18.0+30" --notes-file body.md e-calendar-1.18.0.apk e-calendar-1.18.0-setup.exe
```

Check afterwards:
- https://api.github.com/repos/Vincentjhon31/barangay-events/releases/latest shows `v1.18.0+30` with the `.apk` attached.
- https://vincentjhon31.github.io/barangay-events/ and `…/lgu-admin/#users/new` forward to calendar.bongabong.gov.ph (Pages can take a few minutes the first time).
- `git push` from this folder goes to `ecalendar-source`.

A private repository on a free account has **2,000 free Actions minutes a month**; a release uses about 50 (Windows minutes count double).
