# SUMVILTAD Android App - Copilot Instructions

## Current Version: v1.2.1

---

# 📌 Git Tag & APK Versioning Rules

**Use Semantic Versioning for ALL releases, git tags, and APK builds. Follow this exact pattern:**

**Format:** `MAJOR.MINOR.PATCH`

---

## 1️⃣ PATCH Updates (Bug Fixes, Small UI Tweaks)

**When to use:**

- Fixed crashes or errors
- UI alignment or spacing fixes
- Performance optimizations
- Minor text/translation corrections
- Security patches (non-breaking)

**Rules:**

- Increase **PATCH** by 1
- Do NOT change MAJOR or MINOR
- Git tag format: `v1.1.4` → `v1.1.5`
- APK name format: `sumviltad-v1.1.5-release.apk`

**Examples:**

```
v1.0.0 → v1.0.1   (Fixed navigation drawer scroll issue)
v1.0.1 → v1.0.2   (Corrected typo in Dashboard)
v1.1.3 → v1.1.4   (Improved chart rendering)
```

---

## 2️⃣ MINOR Updates (New Features, Enhancements)

**When to use:**

- Added new screens or features
- New API integrations
- Enhanced existing functionality
- New user-facing capabilities
- Backward-compatible changes

**Rules:**

- Increase **MINOR** by 1
- Reset PATCH to **0**
- Git tag format: `v1.1.5` → `v1.2.0`
- APK name format: `sumviltad-v1.2.0-release.apk`

**Examples:**

```
v1.0.5 → v1.1.0   (Added Irrigation Request feature)
v1.1.4 → v1.2.0   (Added offline mode support)
v1.3.7 → v1.4.0   (Implemented push notifications)
```

---

## 3️⃣ MAJOR Updates (Breaking Changes, Redesigns)

**When to use:**

- Complete UI/UX redesign
- API version upgrade (breaking compatibility)
- Database schema changes requiring migration
- Removed deprecated features
- Architecture overhaul (e.g., MVVM → MVI)

**Rules:**

- Increase **MAJOR** by 1
- Reset MINOR and PATCH to **0**
- Git tag format: `v1.4.2` → `v2.0.0`
- APK name format: `sumviltad-v2.0.0-release.apk`

**Examples:**

```
v1.4.2 → v2.0.0   (Migrated to Jetpack Compose)
v2.3.9 → v3.0.0   (New Laravel API v2 integration)
v3.5.1 → v4.0.0   (Removed Firebase, migrated to Supabase)
```

---

## 📋 Version Progression Template

**Starting version:**

```
v1.0.0
```

**PATCH increments (fixes/tweaks):**

```
v1.0.1
v1.0.2
v1.0.3
v1.0.4
...
```

**MINOR increments (new features):**

```
v1.1.0
v1.1.1   ← patches to v1.1.0
v1.1.2
v1.1.3
v1.2.0   ← new feature release
v1.2.1
v1.2.2
v1.3.0   ← another feature release
...
```

**MAJOR increments (breaking changes):**

```
v2.0.0
v2.0.1   ← patches to v2.0.0
v2.0.2
v2.1.0   ← new features in v2
v2.1.1
v2.1.2
v3.0.0   ← major breaking change
...
```

---

## 🚀 Release Workflow (Agent Instructions)

### Step 1: Determine Version Type

**Ask yourself:**

- Is this a bug fix or small tweak? → **PATCH**
- Is this a new feature (backward-compatible)? → **MINOR**
- Is this a breaking change or major redesign? → **MAJOR**

### Step 2: Update Version Number

**Follow the rules:**

- PATCH: Increment last digit (`v1.1.4` → `v1.1.5`)
- MINOR: Increment middle digit, reset last (`v1.1.5` → `v1.2.0`)
- MAJOR: Increment first digit, reset others (`v1.4.9` → `v2.0.0`)

### Step 3: Commit Changes

```bash
git add .
git commit -m "feat: [Brief description]

- [Change 1]
- [Change 2]
- [Change 3]"
```

### Step 4: Create Git Tag

```bash
git tag -a v1.1.5 -m "Version 1.1.5 - [Update Type]

[Category]:
- [Change 1]
- [Change 2]
- [Change 3]"
```

### Step 5: Push to GitHub

```bash
git push origin main
git push origin v1.1.5
```

### Step 6: Build APK (Optional)

```bash
.\gradlew assembleRelease
```

**Name the APK:** `sumviltad-v1.1.5-release.apk`

---

## 📐 Versioning Rules Summary

| Rule                       | Description                                         |
| -------------------------- | --------------------------------------------------- |
| ✅ **Always increment**    | Never decrease or reuse version numbers             |
| ✅ **Match git tag & APK** | Tag `v1.1.5` = APK `sumviltad-v1.1.5-release.apk`   |
| ✅ **Use `v` prefix**      | All git tags start with lowercase `v`               |
| ✅ **No skipping**         | If you skip a version, never reuse it               |
| ✅ **Document changes**    | Include clear commit messages and tag descriptions  |
| ❌ **Never go backward**   | `v1.1.5` can never become `v1.1.4`                  |
| ❌ **No arbitrary jumps**  | Don't jump from `v1.1.5` to `v1.3.0` without reason |

---

## 🔍 Examples for Common Scenarios

### Scenario 1: Fixed drawer scroll bug

**Type:** PATCH  
**Version:** `v1.1.3` → `v1.1.4`  
**Commit:** `fix: Make navigation drawer scrollable on small screens`

### Scenario 2: Added irrigation request feature

**Type:** MINOR  
**Version:** `v1.1.4` → `v1.2.0`  
**Commit:** `feat: Add irrigation scheduling request feature`

### Scenario 3: Migrated to new API version

**Type:** MAJOR  
**Version:** `v1.9.3` → `v2.0.0`  
**Commit:** `feat!: Migrate to Laravel API v2 (BREAKING CHANGE)`

---

## ⚠️ Important Notes

1. **Current version must always be tracked** in this file (see top)
2. **APK version code** must also increment in `build.gradle.kts`
3. **Changelog** should be maintained in `CHANGELOG.md` (if exists)
4. **Pre-release versions** can use suffixes: `v1.2.0-alpha`, `v1.2.0-beta`, `v1.2.0-rc1`
5. **Hotfix branches** should still follow semantic versioning

---

## 🎯 Quick Reference

| Change Type     | Version Change      | Example                   |
| --------------- | ------------------- | ------------------------- |
| Bug fix         | `v1.1.3` → `v1.1.4` | Fixed crash on login      |
| New feature     | `v1.1.4` → `v1.2.0` | Added dark mode           |
| Breaking change | `v1.9.9` → `v2.0.0` | New authentication system |

---

**Last Updated:** November 26, 2025  
**Maintained by:** GitHub Copilot Agent
