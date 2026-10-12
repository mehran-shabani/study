# Validation

- `flutter analyze`: no issues.
- `flutter test`: all 77 tests passed, including timer pause/resume/storage,
  database migrations, quarter-hour boundaries, audio-failure persistence,
  Persian CSV import, backup merging and repeated-import handling.
- Local release APK built successfully using Myket. The final local wrapper
  script was also verified with:
  `./scripts/build-myket.ps1 -SkipChecks -UseWindowsCertificates -Offline -BuildNumber 2`.
- Official Gradle wrapper/repositories and official Pub URLs remain in tracked
  files for GitHub. Only the local script uses a separate wrapper and Myket init.
- APK package: `com.example.study`; version: `1.1.0`; versionCode: `2`;
  minimum Android SDK: 24; target: 34; compile SDK: 36.
- APK signing certificate SHA-256:
  `6329cde89bdde26232c926569d6c4f78d03fae9a293d5a1dcb279e85aac39550`.
- The supplied previous APK has a different signing certificate. It cannot be
  directly updated using this new key. Its CSV export capability was confirmed.
- Four signing secrets were configured before the user's request to manage them
  manually arrived. Their copyable values and signing backup are local ignored
  files under `release/`. No source changes were pushed to GitHub.
- No Android phone was connected. Actual speaker output, screen-off delivery and
  device-specific battery restrictions still need checking on the user's phone.
- GitHub workflows were updated locally; a GitHub Actions run was not executed.
