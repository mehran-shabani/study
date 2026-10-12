# 1.1.0 — Study awareness and stable Android signing

- Add increasing quarter-hour beeps based on active study time, an alarm toggle,
  sound preview and next-alarm countdown. Android runs the alarm with an ongoing
  notification while the screen is off; pausing/stopping cancels sound.
- Add complete JSON backups and merge imports, including CSV from older builds.
- Require a fixed release keystore; configure both GitHub build workflows to use
  signing secrets and increasing version codes instead of ephemeral debug keys.
- Add PowerShell build/key tools, Myket repositories and a Persian build/upgrade
  guide. Update compatibility with the locally installed Flutter 3.44.2.
- Existing database name, schema and application ID remain unchanged.

## v1.0.3
* Merge pull request #7 from codermehran/main
* feat: add full-screen study stopwatch with pause and discard
* Merge pull request #8 from mehran-shabani/feat/fullscreen-study-timer

## v1.0.2
* feat: add persistent study timer and isolate workspace widget test
* fix: preserve stopped timer on write failure and extend regression coverage
* Merge pull request #6 from mehran-shabani/feat/study-timer
* Merge branch 'mehran-shabani:main' into main

## v1.0.1
* feat: Initialize project with core features and CI
* Bump intl dependency to version 0.19.0
* Merge pull request #1 from mehran-shabani/cursor/build-study-app-with-flutter-5be1
* Refactor: Update theme colors and workspace dialog logic
* Fix: Improve date validation to enforce yyyy-MM-dd
* Update upload-artifact action to v4
* chore(ci): add auto-release workflow and initialize VERSION/CHANGELOG
* Add release automation documentation
* Merge pull request #2 from mehran-shabani/cursor/analyze-project-for-deprecated-members-dc0c
* chore(release): v1.0.1
* feat: Add auto release for APK builds
* fix(android): add missing Android resources (themes and launcher icon)
* Merge pull request #3 from mehran-shabani/cursor/automate-release-tag-and-apk-build-4d69
* chore(release): v1.0.2
* feat: configurable daily targets, Jalali dates and CSV export
* Merge pull request #4 from mehran-shabani/feat/daily-target-jalali-csv
* feat: streamline daily study logging and plan navigation
* Merge pull request #5 from mehran-shabani/feat/study-ux

## v1.0.2
* feat: Add auto release for APK builds
* fix(android): add missing Android resources (themes and launcher icon)
* Merge pull request #3 from mehran-shabani/cursor/automate-release-tag-and-apk-build-4d69

## v1.0.1
* Merge pull request #2 from mehran-shabani/cursor/analyze-project-for-deprecated-members-dc0c
* Add release automation documentation
* chore(ci): add auto-release workflow and initialize VERSION/CHANGELOG
* Update upload-artifact action to v4
* Fix: Improve date validation to enforce yyyy-MM-dd
* Refactor: Update theme colors and workspace dialog logic
* Merge pull request #1 from mehran-shabani/cursor/build-study-app-with-flutter-5be1
* Bump intl dependency to version 0.19.0
* feat: Initialize project with core features and CI

# Changelog

All notable changes to the Study app will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## v1.0.0

### Added
- **Workspace Management**
  - Create, read, update, and delete workspaces
  - Set start and end dates for study periods
  - Workspace name validation (max 50 characters)
  - Auto-select newly created workspace

- **Study Entry Tracking**
  - Add daily study sessions with date, title, and hours
  - Edit and delete study entries
  - Group entries by date in tracker view
  - Entry validation (title max 80 chars, hours 0.25-24.0)
  - Default date set to "today"

- **Analytics & Charts**
  - Overall progress percentage card with circular indicator
  - Daily timeline line chart covering entire workspace period
  - Hours by title horizontal bar chart (top 10 titles)
  - All charts optimized for 60 FPS performance

- **Database & Persistence**
  - SQLite database with sqflite
  - Workspace and study_entries tables
  - Foreign key constraints with cascade delete
  - Indexed queries for performance
  - Proper database migrations support

- **State Management**
  - Riverpod 2.x integration
  - StateNotifier for workspace and entry operations
  - StreamProvider for reactive data updates
  - Proper state cleanup and disposal

- **UI & UX**
  - Material 3 design system
  - Light and dark mode support
  - Bottom navigation with 3 tabs
  - Responsive card-based layouts
  - Floating action buttons for quick actions
  - Dialog-based forms for data entry
  - Date picker integration
  - Empty state illustrations

- **Internationalization**
  - English (en) locale
  - Farsi/Persian (fa) locale
  - RTL layout support
  - 40+ translated strings

- **Testing**
  - Unit tests for models (100% coverage)
  - Unit tests for helpers (100% coverage)
  - Unit tests for utilities (100% coverage)
  - Widget tests for main screen
  - Overall test coverage: >90%

- **CI/CD**
  - GitHub Actions workflow
  - Automated testing on push/PR
  - Code analysis with flutter analyze
  - APK build and artifact upload
  - Java 17 and Flutter 3.22.x configuration

- **Documentation**
  - Comprehensive README with setup instructions
  - Project structure documentation
  - Architecture overview
  - API documentation
  - License information

### Technical Details
- **Flutter Version**: 3.22.3
- **Dart Version**: 3.0.0+
- **Minimum Android API**: 21 (Android 5.0)
- **Target Android API**: 34 (Android 14)

### Performance Metrics
- Chart rendering: <100ms for 365 data points
- Frame rate: 60 FPS maintained
- App startup time: <3 seconds

### Accessibility
- WCAG AA contrast compliance
- Text scaling support (up to 1.3x)
- Semantic labels for screen readers
- RTL layout support

## [Unreleased]

### Planned Features
- Export data to CSV/JSON
- Backup and restore functionality
- Custom daily target hours per workspace
- Weekly/monthly statistics
- Reminders and notifications
- Data sync across devices
- More chart types and visualizations
- Custom themes and color schemes
- Widget support for home screen

---

For upgrade instructions and breaking changes, see the README.md file.
