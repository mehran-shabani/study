# Study - Study Tracking App

A production-ready Flutter application for tracking study sessions and visualizing progress through interactive charts.

## Features

- 📚 **Workspace Management**: Create and manage unlimited study workspaces with start/end dates
- ⏱️ **Study Logging**: Track daily study sessions with title, date, and hours
- 📊 **Analytics**: Visualize progress with three interactive charts:
  - Overall progress percentage
  - Daily timeline chart
  - Hours aggregation by title
- 🌙 **Dark Mode**: Full Material 3 theme support with light and dark modes
- 🌍 **Internationalization**: Support for English and Farsi (Persian)
- 💾 **Offline-First**: All data stored locally with SQLite

## Screenshots

[Screenshots will be added here]

## Getting Started

### Prerequisites

- Flutter SDK 3.22.x or higher
- Dart SDK 3.0.0 or higher
- Android SDK with API level 21+
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
- `hours`: REAL NOT NULL (0.25 - 24.0)

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

This repository uses a GitHub Actions workflow to automatically bump the patch version, tag, and publish a GitHub Release on every push to `main`.

- Trigger: pushes to `main`
- Versioning: Semantic Versioning (patch only auto-increment)
- Files updated: `VERSION`, `CHANGELOG.md`
- Tags: annotated tags in the form `vX.Y.Z`
- Release: Created with the contents of `CHANGELOG.md`

Workflow details:

- Workflow file: `.github/workflows/auto-release.yml`
- Actions used: `actions/checkout@v4`, `EndBug/add-and-commit@v9`, `softprops/action-gh-release@v2`
- Permissions: `contents: write`, `packages: write`

Manual usage notes:

- To bootstrap the first version if no tags exist, the workflow treats the last tag as `v1.0.0` and will create `v1.0.1` on the next push to `main`.
- If you re-run a workflow and the computed tag already exists, it exits early without changes.

## Support

For issues and feature requests, please create an issue on GitHub.
