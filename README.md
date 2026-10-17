# Study - Study Tracking App

A production-ready Flutter application for tracking study sessions and visualizing progress through interactive charts.

## Features

- 📚 **Workspace Management**: Create and manage unlimited study workspaces with start/end dates
- ⏱️ **Study Logging**: Track daily study sessions with title, date, and hours
- 🕒 **Study Timer**: Full-screen stopwatch with start, pause, continue, stop and discard
- 🔔 **Awareness alarm**: Increasing beep counts every 15 active study minutes, including screen-off study
- 🎧 **Study companion**: Focus/rest blocks, sleepy-break actions, active recall, offline instrumental/rain/brown sound and optional keep-screen-on. See [guide and research](docs/FOCUS_COMPANION.md).
- 💾 **Backup and transfer**: Full JSON backup and import of older CSV exports
- 📊 **Analytics**: Visualize progress with three interactive charts:
  - Overall progress percentage
  - Daily timeline chart
  - Hours aggregation by title
- 🌙 **Dark Mode**: Full Material 3 theme support with light and dark modes
- ✨ **More insights**: Keep the existing Reports view and open More for an
  adjustable tomorrow plan, spaced-review candidates, completed-week trends,
  and study-time goal outlook. See [research and calculation notes](docs/ANALYTICS_MORE.md).
- **Share with AI**: Preview or copy a complete analysis request for the selected
  plan and send it through the device share menu to a compatible AI app. Long
  histories share as a text file; the request includes all eligible saved logs.
- **Refreshed interface**: Coordinated light/dark surfaces, readable cards and
  controls, and responsive report charts with narrow-screen and RTL support.
- 🌍 **Internationalization**: Support for English and Farsi (Persian)
- ⚙️ **Settings**: Switch language immediately, choose light/dark/device theme,
  adjust text size, set defaults for new study blocks and daily goals, and manage
  sound, awareness cues and backups from a dedicated fourth tab.
- 🎵 **12 offline sounds**: Six original instrumental textures and six nature/noise
  options, with saved volume and synchronized controls in Settings and the timer.
- 💾 **Offline-First**: All data stored locally with SQLite

## Screenshots

[Screenshots will be added here]

## Getting Started

### Prerequisites

- Flutter SDK 3.44.2
- Dart SDK 3.9.0 or higher
- Android SDK 36 (app minimum API follows Flutter)
- Java 17

### Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd study
```

2. Get dependencies:
```bash
flutter pub get
```

3. Run the app:
```bash
flutter run
```

## Building

For signed local builds in Iran with Myket, fixed signing across local/GitHub
releases, and data transfer from the old APK, see [راهنمای بیلد و آپدیت](docs/BUILD_FA.md).
Release builds require `android/key.properties`; they never fall back to debug signing.

### Debug Build
```bash
flutter build apk --debug
```

### Release Build
```bash
flutter build apk --release
```

The APK will be available at: `build/app/outputs/flutter-apk/app-release.apk`

## Testing

### Run all tests
```bash
flutter test
```

### Run tests with coverage
```bash
flutter test --coverage
```

### View coverage report
```bash
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

## Project Structure

```
study/
├── lib/
│   ├── core/              # Constants, theme, utilities
│   ├── data/              # Database, DAOs, models, providers
│   ├── domain/            # Business logic and helpers
│   ├── presentation/      # UI screens and widgets
│   │   ├── workspaces/    # Workspace management
│   │   ├── tracker/       # Study entry tracking
│   │   └── analytics/     # Charts and analytics
│   └── l10n/              # Internationalization files
├── test/
│   ├── unit/              # Unit tests
│   └── widget/            # Widget tests
└── android/               # Android-specific configuration
```

## Architecture

The app follows clean architecture principles:

- **Core Layer**: Shared utilities, constants, and theming
- **Data Layer**: Database operations, models, and state management
- **Domain Layer**: Business logic and domain-specific helpers
- **Presentation Layer**: UI components and screens

### State Management

The app uses **Riverpod 2.x** for state management with `StateNotifier` for complex state operations.

### Database

SQLite via `sqflite` package with the following schema:

#### Tables

**workspaces**
- `id`: INTEGER PRIMARY KEY AUTOINCREMENT
- `name`: TEXT NOT NULL (max 50 chars)
- `start_date`: TEXT NOT NULL (yyyy-MM-dd)
- `end_date`: TEXT NOT NULL (yyyy-MM-dd)

**study_entries**
- `id`: INTEGER PRIMARY KEY AUTOINCREMENT
- `workspace_id`: INTEGER NOT NULL (FK to workspaces)
- `entry_date`: TEXT NOT NULL (yyyy-MM-dd)
- `title`: TEXT NOT NULL (max 80 chars)
- `hours`: REAL NOT NULL (manual: 0.25–24; timer: exact positive elapsed hours)

**study_timer** (database version 6)
- One pending session: original workspace, UTC timestamps, subject and active interval history
- Running, paused and stopped timers survive app restarts
- Pending timers prevent deletion of their workspace until saved

**app_settings** (added in version 6)
- One JSON preference row: language, appearance, text size, focus default and
  daily target for new plans. Upgrading preserves existing plans and timers.
- Settings load before the first screen. Changes save automatically; failed
  writes retain the previous selection and allow retry.
- Resetting app preferences preserves study data and alarm/sound choices.
- JSON/CSV study backups contain plans and sessions; preferences stay on-device.

## Key Dependencies

- **flutter_riverpod**: State management
- **sqflite**: Local database
- **fl_chart**: Interactive charts
- **intl**: Internationalization

See `pubspec.yaml` for complete list.

## Accessibility

- Supports text scaling up to 1.3x
- High contrast mode (WCAG AA compliant)
- RTL (Right-to-Left) layout support for Farsi
- Semantic labels for screen readers

## Performance

- Chart rendering: < 100ms for 365 data points
- 60 FPS maintained for all animations
- Efficient database queries with proper indexing

## Security

- No network permissions required
- All data stored locally
- No external API calls

## Localization

Supported languages:
- English (en)
- Farsi/Persian (fa)

To add a new language:
1. Create `intl_<locale>.arb` in `lib/l10n/`
2. Add locale to `supportedLocales` in `main.dart`
3. Run `flutter gen-l10n`

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests and ensure they pass
5. Submit a pull request

## License

This project uses MIT/BSD-style licensed dependencies. See [LICENSES.md](LICENSES.md) for details.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history.

## Release Automation

The plain-text `VERSION` file is the release-name source for both GitHub
workflows. Put one version on its own line, for example:

```text
1.1.0
```

- `.github/workflows/auto-release.yml` runs on pushes to `main` or manually.
  It validates `VERSION`, builds the APK with that exact `--build-name`, then
  creates or updates the `v1.1.0` release and uploads the APK.
- `.github/workflows/android-release.yml` uses the same reader for its debug
  and release APKs, overriding the fallback version in `pubspec.yaml`.
- Neither workflow reads previous versions/tags, increments a version, skips a
  build because a tag exists, or commits changes to `VERSION`/`CHANGELOG.md`.
- Invalid or missing `VERSION` stops the workflow before installing Flutter or
  building. The format is `X.Y.Z`, without `v`, prerelease suffixes, or `+code`.
- Android's internal `versionCode` remains time-based so separate builds can be
  installed as updates. It does not determine the displayed version name.
- Rerunning the same version builds again and replaces the APK asset in the
  existing release. Existing tags stay in place; new tags use the built commit.
- Release signing still uses the fixed GitHub signing secrets.

Validate version handling without building:

```bash
python3 scripts/read-version.py
python3 -m unittest discover -s test/ci -p 'test_*.py'
```

## Support

For issues and feature requests, please create an issue on GitHub.

## Daily target, Jalali dates, and CSV export

- Set **Daily target (hours)** when creating or editing a workspace (0.25–24 hours).
  Overall progress and today's progress use this workspace-specific target.
  Existing workspaces keep their previous 4-hour target after the database upgrade.
- Dates in forms, the workspace list, study sessions, and timeline labels use the
  Jalali calendar. Tap a date field to open the Persian calendar picker. ISO
  Gregorian dates remain in SQLite so previous sessions and sorting stay intact.
- Select a workspace and tap **Export CSV** in Tracker or Analytics. Android's
  share sheet lets you save/send the file using a compatible installed app.
  The export contains all sessions for that workspace in chronological order:
  `workspace,date_jalali,date_iso,title,hours,daily_target_hours`. UTF-8 BOM
  preserves Persian text in Excel; commas, quotes, and newlines are escaped.
  The exported target is the current workspace target, not a historical snapshot.

Validation: `flutter analyze` and `flutter test`. Database migration, target
calculations, Jalali New Year/leap dates, and CSV escaping have regression tests.

## Usability improvements

- Tap a plan to open Study directly, or change plans using the selector in Study/Reports.
- Today's card shows logged time, the remaining time to the goal, completion, and a shortcut to edit the goal.
- Log sessions using 15/30/60/90/120-minute presets, recent subjects, and Today/Yesterday shortcuts. Manual hours remain available.
- Forms preserve entered data on failure, show a saving state, and block repeated submissions. Empty/error screens have clear next actions.
- Data refreshes after successful changes instead of polling SQLite twice a second.
- Quarter-hour durations retain their precision; Persian screens use localized duration labels.

## Study timer

- In the middle **Study** tab, tap the pale pink square clock above **Log study**.
  Both buttons align on the physical right, including Persian layouts.
- A dedicated full-screen timer shows hours, minutes and seconds. Tap **Start**.
- **Pause** freezes the elapsed time; **Continue** resumes it. Breaks are excluded
  from daily study totals, including breaks spanning midnight or app restarts.
- The elapsed time continues across tab changes, screen locking, and app restarts.
- Tap **Stop** to finish. Enter the subject and save; date and duration are automatic.
- **Delete timer session** asks for confirmation and discards only the pending
  session. Previously saved studies stay intact.
- **Save later** keeps the stopped time and entered subject, with no extra time counted.
- Changing the selected plan does not move an active timer to another plan.
- Sessions crossing local midnight are recorded separately for each day. Even
  sessions shorter than fifteen minutes retain their actual duration.
- Saving all daily entries and clearing the timer is one SQLite transaction;
  a failed save keeps the pending session for retry.
