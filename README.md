# 🚀 Flutter Reusable CI/CD Workflows

A production-ready reusable GitHub Actions CI/CD pipeline for Flutter applications supporting Android and iOS builds, testing, store deployments, and release management.

Features:
- Dart analyzer
- Flutter unit tests with coverage enforcement
- Android APK & AAB build
- iOS XCArchive build
- Google Play Store deployment
- Apple TestFlight deployment
- GitHub Release creation
- Secure Android and iOS signing
- “What’s New” release notes from file

---

## 📦 Repository Structure

.github/workflows
- push.yml (Reusable CI workflow)
- release.yml (Reusable CD workflow)

.github/actions
- setup-flutter (Flutter setup action)

---

## 🧠 Architecture Overview

Caller App Repository triggers:

Reusable CI Workflow (push.yml)  
→ Flutter setup  
→ Dart analyzer  
→ Unit tests  
→ Coverage check  
→ Android build  
→ iOS archive (optional)

Reusable CD Workflow (release.yml)  
→ GitHub Release  
→ Android signing  
→ Google Play upload  
→ iOS signing  
→ TestFlight upload  
→ "What’s New" from file

---

## 🧪 Reusable CI Workflow (push.yml)

Handles:
- Flutter setup
- Dart analyzer
- Flutter tests
- Coverage threshold enforcement
- Android APK & AAB build
- Optional iOS archive build

Inputs:
- flutter_version
- flutter_channel
- coverage_threshold
- build_ios
- package_name
- ios_bundle_id
- version_name

---

## 🚀 Reusable CD Workflow (release.yml)

Handles:
- GitHub Release creation
- Android signing
- Google Play upload
- iOS signing
- TestFlight upload
- Optional “What’s New” release notes

Inputs:
- version
- deploy_to_playstore
- deploy_to_testflight
- playstore_track
- playstore_status
- package_name
- ios_bundle_id
- build_number
- enable_whats_new
- whats_new_file

---

## 📝 “What’s New” (Release Notes from File)

Create a file in your app repo, for example:

release_notes.txt

Content example:
- Added profile screen
- Improved login performance
- Fixed crash on Android 14

Enable it in your caller workflow:

enable_whats_new: true  
whats_new_file: release_notes.txt

This same file is used for:
- Google Play Store changelog
- TestFlight build release notes

---

## 📲 Android Support

- APK signing
- AAB publishing
- Track selection (internal, alpha, beta, production)
- Draft or completed releases
- Play Store metadata support
- Changelog from file

---

## 🍎 iOS Support

- XCArchive export
- Manual provisioning profile signing
- P12 certificate signing
- App Store Connect API key authentication
- TestFlight upload
- Changelog from file

---

## 🔐 Required Secrets

Android:
- ANDROID_KEYSTORE
- KEYSTORE_PASSWORD
- KEY_PASSWORD
- KEY_ALIAS
- PLAYSTORE_SERVICE_ACCOUNT

iOS:
- IOS_CERT_P12_BASE64
- IOS_CERT_PASSWORD
- IOS_PROVISION_PROFILE_BASE64
- IOS_TEAM_ID

App Store Connect:
- APPSTORE_ISSUER_ID
- APPSTORE_KEY_ID
- APPSTORE_PRIVATE_KEY

---

## 🧩 Example Caller Workflow Usage

call-cd-workflow:
uses: your-org/flutter-reusable/.github/workflows/release.yml@main
with:
version: 1.2.0
deploy_to_playstore: true
deploy_to_testflight: true
package_name: com.example.app
ios_bundle_id: com.example.app
build_number: ${{ github.run_number }}
enable_whats_new: true
whats_new_file: release_notes.txt
secrets:
ANDROID_KEYSTORE: ${{ secrets.ANDROID_KEYSTORE }}
KEYSTORE_PASSWORD: ${{ secrets.KEYSTORE_PASSWORD }}
KEY_PASSWORD: ${{ secrets.KEY_PASSWORD }}
KEY_ALIAS: ${{ secrets.KEY_ALIAS }}
PLAYSTORE_SERVICE_ACCOUNT: ${{ secrets.PLAYSTORE_SERVICE_ACCOUNT }}
APPSTORE_ISSUER_ID: ${{ secrets.APPSTORE_ISSUER_ID }}
APPSTORE_KEY_ID: ${{ secrets.APPSTORE_KEY_ID }}
APPSTORE_PRIVATE_KEY: ${{ secrets.APPSTORE_PRIVATE_KEY }}
IOS_TEAM_ID: ${{ secrets.IOS_TEAM_ID }}
IOS_CERT_P12_BASE64: ${{ secrets.IOS_CERT_P12_BASE64 }}
IOS_CERT_PASSWORD: ${{ secrets.IOS_CERT_PASSWORD }}
IOS_PROVISION_PROFILE_BASE64: ${{ secrets.IOS_PROVISION_PROFILE_BASE64 }}

---

## 📁 Example App Repository Layout

your-app
- pubspec.yaml
- release_notes.txt
- ios
- android
- .github/workflows/main.yml

---

## 🏗️ Design Principles

- Fully reusable
- Secure secret handling
- Modular pipeline
- CI and CD separated
- Android and iOS capable
- Store-compliant
- Optional deployments
- No secrets in repository

---

## 🧭 Roadmap

- Firebase App Distribution
- Slack notifications
- PR preview builds
- Play Store staged rollout
- Multi-language changelogs
- App Store metadata sync

---

## 🤝 Contributing

Pull requests are welcome for:
- Bug fixes
- Performance improvements
- New integrations
- Documentation improvements

---

## 📜 License

MIT License

---

## ⭐ Why use this?

Because it is:
- Fully automated
- Secure
- Reusable
- Enterprise-ready
- Android and iOS capable
- Release-note aware
- GitHub Release integrated

---

## 👨‍💻 Author

**Rite Technologies - DevOps Competency**

---

## 🎯 One-command releases

Push to main branch automatically:
- Runs tests
- Builds Android and iOS
- Publishes to Play Store and TestFlight
- Creates GitHub Release

Happy shipping 🚀
