# Validation

## Medical daily companion — 2026-10-21

- `flutter analyze --no-pub`: no issues.
- `flutter test --no-pub --reporter compact`: all 152 tests passed.
- New coverage includes per-plan/day persistence, version 6-to-7 migration,
  backup ID remapping and repeated imports, failed-load/write recovery, medical
  course customization, planned tasks and reflections, subject transfer into
  the timer, pausing study for practice, all three complete game flows and
  background/resume behavior.
- Persian/English light/dark layouts checked at 320px with 1.3x app text.
  Persian widget renders were visually inspected with readable text and icons;
  screenshots and design decisions are in [the design guide](DESIGN_SYSTEM_FA.md).
- `git diff --check`: passed. No dependencies, release versions or workflows
  changed. No APK build was run, as requested. Native installation and device
  behavior were not exercised in this change.

## AI study sharing and interface refresh — 2026-10-17

- `flutter analyze --no-pub`: no issues.
- `flutter test --no-pub --reporter compact`: all 133 tests passed. Eleven new
  checks cover report filtering, accurate completed-week statistics, adjusted
  tomorrow budgets, empty/finished plans, Persian text and tiny timer durations,
  complete long histories, matching preview/copy/share payloads, UTF-8 text-file
  sharing, retry after platform errors, and narrow/wide Persian/English layouts.
- Persian Reports, More insights and the sharing preview were rendered for
  visual inspection, including dark appearance. Layout tests cover 320px with
  1.5× text and 1200px with dark appearance. Compact report actions prevent
  toolbar overflow with large text.
- Native sharing is verified at the platform-channel boundary. Availability
  and behavior of a particular installed AI app still depend on that device;
  complete-text copying remains available.
- No dependency, database, version or workflow changes. No APK build was run.
  The commit uses `[skip ci]` to avoid the repository's automatic APK workflows
  when pushing these changes.

## File-driven release versions — 2026-10-17

- Both GitHub workflows validate VERSION before build setup, then pass its
  exact value as Flutter's `--build-name`. The release tag uses the same value.
- `python -m unittest discover -s test/ci -p 'test_*.py' -v`: all 7 tests pass,
  including UTF-8 BOM/CRLF, missing and malformed files, unsafe/multiline values,
  step outputs, unchanged source files, and operation without Git history.
- `actionlint` v1.7.12 reports no workflow errors. Validation used the official
  Windows binary after checking its published SHA-256 checksum. Optional
  shellcheck/pyflakes integrations were disabled because they are not installed.
- VERSION is initialized to 1.1.0, matching the app's existing version name.
  No package changes, local APK build or manual workflow dispatch were needed.

## Settings and expanded offline audio — 2026-10-17

- `flutter gen-l10n` regenerated the stale localization output. The initial 33
  missing-localization analyzer errors are resolved.
- `flutter analyze --no-pub`: no issues.
- `flutter test --no-pub`: all 122 tests passed. Fifteen new tests cover saved
  preferences across database reopen, safe defaults for malformed values,
  version 5 → 6 migration with a pending timer, simultaneous database access,
  failed writes and retry, immediate Persian/English and theme switching,
  defaults in new plans/timers, all 12 sound choices, Persian number input,
  reset preserving study data, and 320px layouts at 1.95× combined text scaling.
- Offline dependency resolution succeeded using the existing Myket cache.
  All package versions and checksums match the original lockfile, which remains
  byte-for-byte unchanged. No new dependency or SDK change was needed.
- All four Android Kotlin sources compiled for JVM 17 with Kotlin 2.2.20,
  Android API 36, Flutter's installed embedding and cached AndroidX lifecycle.
  A temporary `R` stub supplied resource constants; no Gradle task or APK build
  was run. The pre-API-26 notification fallback emits its existing deprecation
  warning.
- JVM audio checks passed for all 12 generated tracks: 32-second length,
  non-silent output, bounded PCM amplitude, zero-valued loop endpoints,
  distinct output and deterministic regeneration.
- Settings were rendered for visual review in Persian/light and English/dark.
  Automated layout checks include the timer and the new settings at narrow
  widths with large text. Physical speaker/headphone output, screen-off
  playback and OEM battery handling still require a real Android device.
- No APK was built and nothing was published.

## Study companion — 2026-10-16

- Flutter 3.44.2: `flutter analyze --no-pub` reports no issues.
- `flutter test --no-pub`: all 107 tests passed. New checks cover exact focus
  boundaries, overnight restore, manual pause, explicit break resume, failed
  persistence, invalid settings, and Persian/English at 320px with 1.5× text.
- All previous database migration, backup, timer and analytics tests still pass.
- No new Pub dependencies; the existing lockfile is unchanged.
- Local Linux database tests used the installed SQLite library via a temporary
  `libsqlite3.so` link. Android compilation is included in the PR CI job.
- All four Android Kotlin sources compile with Kotlin 2.2.20 against the
  official Android API 36 classes and this Flutter engine’s real embedding JAR.
  Resource IDs were represented by a temporary stub generated from the XML.
  This is source compilation, not APK packaging.
- JVM smoke checks for all three generated soundscapes confirmed the expected
  16-second length, non-silent output, no PCM clipping and zero-valued loop ends.
- GitHub CI run 38873674078 could not start: the account is locked due to a
  billing issue. No runner step or APK build ran there.
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
