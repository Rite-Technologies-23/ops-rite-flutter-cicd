# 🚀 Flutter Reusable CI/CD Workflows

A reusable **GitHub Actions CI/CD pipeline for Flutter applications**: a full quality gate built from free tooling, APK/AAB and iOS archive builds, signing, Google Play, TestFlight and Esper deployment, and GitHub release management.

It follows the same structure and gate semantics as `ops-rite-android-pipeline` and `ops-rite-ios-pipeline`.

---

## ✨ Features

### CI: a complete quality gate built from free tooling

| Concern | Tool | Gate |
|---|---|---|
| **Formatting** | `dart format --set-exit-if-changed` (tracked, hand-written files only) | fails on diff |
| **Lint / static typing** | `dart analyze --fatal-warnings` (optional `--fatal-infos`), with a shared `analysis_options.yaml` fallback | fails on error/warning |
| **Secret scanning** | gitleaks (binary, so no org licence is needed), with Flutter/Firebase allowlists | fails on any leak |
| **SAST** | Semgrep OSS (`p/secrets` + Flutter rules: trust-all TLS, secrets in SharedPreferences, cleartext HTTP, weak hash/random, logging secrets) | fails on ERROR |
| **Dependency CVEs** | Trivy over `pubspec.lock`, `Podfile.lock`, Gradle files | report-only by default |
| **Dead code** | Analyzer `unused_*` diagnostics + `dependency_validator` (unused/missing pub deps), plus optional `dart_code_linter` unused code/files | report-only by default |
| **Tests** | `flutter test` (JUnit report) | fails on any failure |
| **Coverage** | lcov line coverage, generated code excluded | fails below threshold |

Shared configs and scripts are checked out from this repo into `.pipeline` by the `setup-flutter` action, so a caller repo **needs no file changes**. A caller-owned `analysis_options.yaml` always wins.

### Platform

- Flutter SDK + pub caching
- Parallel CI jobs with an aggregated GitHub job summary
- APK & AAB build, unsigned iOS `xcarchive` (one compile via `flutter build ipa --no-codesign`)
- APK/AAB re-signing with the upload key, plus IPA export with manual signing
- Google Play, TestFlight and Esper (Android + iOS) deployment
- GitHub Release creation with signed artifacts attached
- Automatic semantic version conflict resolution
- Optional **"What's New"** release notes from file

---

## 📦 Repository Structure

```
.github/
├── workflows/
│   ├── push.yml                   # Reusable Flutter CI workflow
│   └── release.yml                # Reusable Flutter CD workflow
├── actions/setup-flutter/         # Shared setup: .pipeline checkout, Flutter, optional JDK
└── tool/
    ├── analysis_options.yaml      # Fallback analyzer config (used only if the caller has none)
    ├── gitleaks.toml              # Secret-scanning rules + Flutter allowlists
    ├── semgrep/flutter-rules.yml  # Dart/Flutter SAST rules
    ├── json_to_junit.dart         # flutter test --machine → JUnit XML
    ├── analyzer_to_html.dart      # dart analyze --format=machine → HTML
    └── scripts/generate_summary_md.sh
```

---

## 🧠 Architecture Overview

### Reusable CI Workflow (`push.yml`)

```
                 ┌─ Lint & Format ──── dart format + dart analyze
                 │
Checkout         ├─ Security ───────── gitleaks + Semgrep + Trivy   (ubuntu, no SDK)
+ setup-flutter ─┤
(every job)      ├─ Dead Code ──────── dependency_validator (+ optional dart_code_linter)
                 │
                 └─ Tests & Coverage ─ flutter test + lcov gate
                                               ↓
                              Build APK + AAB   │   Build iOS xcarchive (optional, macOS)
                                               ↓
                                     CI Summary (job summary + artifacts)
```

Only the builds depend on **Tests**. Everything else runs in parallel, so a formatting failure and a coverage failure show up in the same run instead of one at a time.

### Reusable CD Workflow (`release.yml`)

```
Create GitHub Release
        ↓
Download CI artifacts ──┬── Sign APK + AAB ──┬── Play Store (optional)
                        │                    └── Esper Android (optional)
                        └── Export signed IPA ┬─ TestFlight (optional)
                                              └─ Esper iOS (optional)
        ↓
Upload signed artifacts to the GitHub Release
```

---

## Consolidated CI+CD build

`release.yml` **builds nothing**. Earlier versions rebuilt the AAB from source for the Play Store, which meant a second compile whose version could drift from what CI tested. Now CD only signs and ships the artifacts the caller's own CI job built earlier **in the same workflow run**. Reusable-workflow calls share one run, so CD sees those artifacts through plain `actions/download-artifact`.

What the caller needs to do:

- Call `push.yml` first. Pass `run_build: true` (for Android) and/or `build_ios: true` (for iOS) on release triggers.
- Pass the **final** `version_name` and `build_number` to `push.yml`. Those are the versionCode/CFBundleVersion that ship.
- Call `release.yml` with `needs: [ci]`.

The CI-built APK/AAB carry Flutter's default debug signature. `sign_android` re-signs the APK with `apksigner` and strips and re-signs the AAB with `jarsigner`, both using your upload key. The caller's `build.gradle` does **not** need to read `key.properties`.

---

## 🧪 Reusable CI Workflow (`push.yml`)

### Core inputs

| Input | Default | Description |
|---|---|---|
| `flutter_version` | `3.35.5` | Flutter version |
| `flutter_channel` | `stable` | Flutter channel |
| `version_name` | `1.0.0` | `--build-name` |
| `build_number` | `1` | `--build-number`. Pass `${{ github.run_number }}` |
| `java_version` | `17` | JDK for the Android build |
| `android_runner` | `ubuntu-latest` | Runner for the Flutter jobs |
| `ios_runner` | `macos-latest` | Runner for the iOS build |
| `security_runner` | `ubuntu-latest` | Runner for the security stage |

### Stage toggles

| Input | Default | Description |
|---|---|---|
| `run_formatting` | `true` | `dart format` |
| `run_static_analysis` | `true` | `dart analyze` |
| `run_security` | `true` | gitleaks + Semgrep |
| `run_dependency_audit` | `true` | Trivy |
| `run_dead_code` | `true` | `dependency_validator` |
| `run_deep_dead_code` | `false` | `dart_code_linter` unused code/files (slower, noisy) |
| `run_tests` | `true` | `flutter test` + coverage |
| `run_build` | `true` | APK + AAB. Turn off for checks-only runs |
| `build_ios` | `false` | Unsigned xcarchive (macOS bills at 10x) |

### Tuning

| Input | Default | Description |
|---|---|---|
| `coverage_threshold` | `80` | Minimum LINE coverage % |
| `enforce_coverage` | `true` | Fail below the threshold |
| `coverage_exclude` | generated-code regex | ERE of files left out of the coverage figure (`*.g.dart`, `*.freezed.dart`, ...) |
| `analyzer_fatal_infos` | `false` | Fail the analyzer on info-level lints too |

### Gates

Each gate switches its stage between *blocking* and *report-only*.

| Input | Default | Blocks the build on |
|---|---|---|
| `fail_on_formatting` | `true` | Formatting differences |
| `fail_on_lint` | `true` | Analyzer errors/warnings |
| `fail_on_security` | `true` | Semgrep ERRORs and leaked secrets |
| `fail_on_vulnerabilities` | `false` | HIGH/CRITICAL dependency CVEs |
| `fail_on_dead_code` | `false` | Unused/missing dependencies, unused code |

### Secrets and outputs

| Name | Description |
|---|---|
| secret `PIPELINE_TOKEN` | Only needed when **this** repo is private and the caller lives elsewhere |
| output `coverage_percent` | Computed line coverage (empty when no tests ran) |

`package_name`, `ios_bundle_id`, `playstore_track`, `SONAR_TOKEN` and `CODACY_PROJECT_TOKEN` are still accepted but unused. They are kept so existing callers don't break.

### Artifacts (contract with `release.yml`, do not rename)

- `android-build`: `app-release.apk` + `*.aab`
- `ios-archive-unsigned`: `Runner.xcarchive`

---

## 🚀 Reusable CD Workflow (`release.yml`)

| Input | Description |
|---|---|
| `version` | Base semver (`1.2.3`) for the release tag; auto-bumps the patch if the tag exists |
| `package_name` | Android package name |
| `deploy_to_playstore`, `playstore_track`, `playstore_status` | Google Play upload |
| `deploy_to_testflight`, `ios_bundle_id` | TestFlight upload |
| `deploy_to_esper_android`, `deploy_to_esper_ios`, `esper_org_id`, `esper_tenant` | Esper upload |
| `enable_whats_new`, `whats_new_file` | Release notes for Play and TestFlight |
| `android_build_tools_version` | Build-tools for zipalign/apksigner (default `34.0.0`) |
| `android_runner`, `ios_runner` | Runners |
| `build_number` | Informational only; the build number is baked in by `push.yml` |

`flutter_version`, `flutter_channel`, `deploy_to_cloud`, `enable_aws`, `terraform_working_dir`, `playstore_metadata_path`, `playstore_images_path` and the AWS secrets are still accepted but unused.

The calling job must allow `contents: write` (release creation and asset upload).

---

## 🔐 Secrets

| Group | Secrets |
|---|---|
| Android signing | `ANDROID_KEYSTORE` (base64 .jks), `KEYSTORE_PASSWORD`, `KEY_PASSWORD`, `KEY_ALIAS` |
| Google Play | `PLAYSTORE_SERVICE_ACCOUNT` |
| iOS signing | `IOS_TEAM_ID`, `IOS_CERT_P12_BASE64`, `IOS_CERT_PASSWORD`, `IOS_PROVISION_PROFILE_BASE64` |
| App Store Connect | `APPSTORE_ISSUER_ID`, `APPSTORE_KEY_ID`, `APPSTORE_PRIVATE_KEY` (base64 .p8) |
| Esper | `ESPER_API_KEY` |
| Pipeline checkout | `PIPELINE_TOKEN` (optional) |

---

## 🧩 Example Caller Workflow

```yaml
name: Flutter CI/CD

on:
  pull_request:
  push:
    branches: [main]
    tags: ["v*-release"]

permissions:
  contents: write

jobs:
  ci:
    uses: Rite-Technologies-23/ops-rite-flutter-cicd/.github/workflows/push.yml@main
    with:
      flutter_version: "3.35.5"
      version_name: "1.2.0"
      build_number: ${{ github.run_number }}
      coverage_threshold: "60"
      # Build only for release tags -- the only case `cd` needs artifacts.
      run_build: ${{ startsWith(github.ref, 'refs/tags/') }}
      build_ios: ${{ startsWith(github.ref, 'refs/tags/') }}
      # Report-only while adopting:
      fail_on_formatting: false
    secrets:
      PIPELINE_TOKEN: ${{ secrets.PIPELINE_TOKEN }}

  cd:
    uses: Rite-Technologies-23/ops-rite-flutter-cicd/.github/workflows/release.yml@main
    if: startsWith(github.ref, 'refs/tags/')
    needs: [ci]
    with:
      version: "1.2.0"
      build_number: ${{ github.run_number }}
      package_name: com.example.app
      ios_bundle_id: com.example.app
      deploy_to_playstore: true
      playstore_track: internal
      playstore_status: draft
      deploy_to_testflight: true
      enable_whats_new: true
      whats_new_file: release_notes.txt
    secrets:
      ANDROID_KEYSTORE: ${{ secrets.ANDROID_KEYSTORE }}
      KEYSTORE_PASSWORD: ${{ secrets.KEYSTORE_PASSWORD }}
      KEY_PASSWORD: ${{ secrets.KEY_PASSWORD }}
      KEY_ALIAS: ${{ secrets.KEY_ALIAS }}
      PLAYSTORE_SERVICE_ACCOUNT: ${{ secrets.PLAYSTORE_SERVICE_ACCOUNT }}
      IOS_TEAM_ID: ${{ secrets.IOS_TEAM_ID }}
      IOS_CERT_P12_BASE64: ${{ secrets.IOS_CERT_P12_BASE64 }}
      IOS_CERT_PASSWORD: ${{ secrets.IOS_CERT_PASSWORD }}
      IOS_PROVISION_PROFILE_BASE64: ${{ secrets.IOS_PROVISION_PROFILE_BASE64 }}
      APPSTORE_ISSUER_ID: ${{ secrets.APPSTORE_ISSUER_ID }}
      APPSTORE_KEY_ID: ${{ secrets.APPSTORE_KEY_ID }}
      APPSTORE_PRIVATE_KEY: ${{ secrets.APPSTORE_PRIVATE_KEY }}
```

---

## 🪜 Adoption path

1. **Run it as-is.** Format, lint, security, tests and coverage gate from day one; CVEs and dead code report only. Set `fail_on_formatting: false` until a one-off `dart format .` lands.
2. **Commit `pubspec.lock`** (recommended for apps) so Trivy can audit Dart dependencies.
3. **Triage the dead-code report.** Add a `dart_dependency_validator.yaml` for false positives (e.g. `cupertino_icons`, `build_runner`), then set `fail_on_dead_code: true`.
4. **Triage the CVE report**, then set `fail_on_vulnerabilities: true`.
5. **Tighten the analyzer**: `analyzer_fatal_infos: true`, and `strict-casts` / `strict-inference` in your own `analysis_options.yaml`.

---

## 📝 "What's New" (Release Notes from File)

Add a file such as `release_notes.txt` to the app repo and set:

```yaml
enable_whats_new: true
whats_new_file: release_notes.txt
```

The same file is used for the Google Play changelog (`en-US`) and the TestFlight build notes.

---

## 👨‍💻 Author

**Rite Technologies - DevOps Competency**
