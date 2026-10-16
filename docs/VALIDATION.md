# Validation

## Study companion — 2026-10-16

- Flutter 3.44.2: `flutter analyze --no-pub` reports no issues.
- `flutter test --no-pub`: all 107 tests passed. New checks cover exact focus
  boundaries, overnight restore, manual pause, explicit break resume, failed
  persistence, invalid settings, and Persian/English at 320px with 1.5× text.
- All previous database migration, backup, timer and analytics tests still pass.
- No new Pub dependencies; the existing lockfile is unchanged.
- Local Linux database tests used the installed SQLite library via a temporary
  `libsqlite3.so` link. Android compilation is included in the PR CI job.
- Actual speaker/headphone output, incoming calls, screen-off delivery and OEM
  battery restrictions need a physical Android device; no device was connected.


## More insights — 2026-10-13

- `flutter analyze --no-pub`: no issues.
- `flutter test --no-pub`: all 99 tests passed, including 22 new analytics
  checks for completed-day averages, future-entry filtering, review priorities,
  tomorrow budgets, tiny timer logs, plan switching, live data refresh, back
  navigation, and Persian/English layouts at 320px with 1.5× text scaling.
- Local checks used `PUB_HOSTED_URL=https://pub.myket.ir` and
  `FLUTTER_STORAGE_BASE_URL=https://pub.myket.ir`; no new dependency was needed.
- Existing subject chart accessibility labels were corrected without changing
  the visible chart: progress-bar values remain numeric, while localized hours
  are announced in the label.
- No APK build was run, as requested. Research and calculation definitions are
  in [ANALYTICS_MORE.md](ANALYTICS_MORE.md).

## Previous release validation

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
