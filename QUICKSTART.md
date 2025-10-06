# Quick Start Guide

This guide will help you get the Study app up and running quickly.

## Prerequisites Check

Before starting, ensure you have:

- [ ] Flutter SDK 3.22.x installed
- [ ] Dart SDK 3.0.0+ installed
- [ ] Android Studio or VS Code with Flutter extension
- [ ] Android SDK with API level 21+
- [ ] Java 17 installed

### Verify Installation

```bash
flutter --version
dart --version
java --version
```

## Setup Steps

### 1. Clone and Navigate
```bash
git clone <your-repo-url>
cd study
```

### 2. Get Dependencies
```bash
flutter pub get
```

This will download all required packages listed in `pubspec.yaml`.

### 3. Generate Localizations
```bash
flutter gen-l10n
```

This generates the localization files from the ARB files in `lib/l10n/`.

### 4. Verify Setup
```bash
flutter doctor -v
```

Ensure all checks pass (especially Android toolchain).

### 5. Run the App

#### On an Emulator/Device
```bash
# List available devices
flutter devices

# Run on specific device
flutter run -d <device-id>
```

#### In Debug Mode
```bash
flutter run
```

#### In Release Mode
```bash
flutter run --release
```

## Building

### Debug APK
```bash
flutter build apk --debug
```
Output: `build/app/outputs/flutter-apk/app-debug.apk`

### Release APK
```bash
flutter build apk --release
```
Output: `build/app/outputs/flutter-apk/app-release.apk`

### App Bundle (for Play Store)
```bash
flutter build appbundle --release
```
Output: `build/app/outputs/bundle/release/app-release.aab`

## Testing

### Run All Tests
```bash
flutter test
```

### Run with Coverage
```bash
flutter test --coverage
```

### View Coverage Report (requires lcov)
```bash
# Install lcov (macOS)
brew install lcov

# Install lcov (Ubuntu/Debian)
sudo apt-get install lcov

# Generate HTML report
genhtml coverage/lcov.info -o coverage/html

# Open report
open coverage/html/index.html  # macOS
xdg-open coverage/html/index.html  # Linux
```

## Code Analysis

### Run Static Analysis
```bash
flutter analyze
```

This checks for code issues based on `analysis_options.yaml`.

### Format Code
```bash
flutter format lib/ test/
```

## Development Tips

### Hot Reload
While the app is running in debug mode:
- Press `r` in terminal for hot reload
- Press `R` for hot restart
- Press `q` to quit

### VS Code
- Use `F5` to start debugging
- Use `Ctrl+F5` to run without debugging
- Hot reload happens automatically on save

### Android Studio
- Click the run button (▶️)
- Use `Ctrl+R` (Windows/Linux) or `Cmd+R` (macOS) for hot reload

## Troubleshooting

### "Gradle build failed"
```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
flutter run
```

### "CocoaPods not installed" (if iOS support added later)
```bash
sudo gem install cocoapods
cd ios
pod install
cd ..
```

### "License not accepted"
```bash
flutter doctor --android-licenses
```

### Dependencies Not Resolving
```bash
flutter clean
flutter pub cache repair
flutter pub get
```

### Database Issues During Development
The app stores data in SQLite. To reset during development:
1. Uninstall the app from device/emulator
2. Reinstall: `flutter run`

Or manually delete app data from device settings.

## Project Structure Overview

```
study/
├── lib/
│   ├── main.dart              # App entry point
│   ├── core/                  # Shared utilities
│   │   ├── constants.dart
│   │   ├── theme.dart
│   │   └── utils.dart
│   ├── data/                  # Data layer
│   │   ├── models.dart
│   │   ├── database.dart
│   │   ├── workspace_dao.dart
│   │   ├── study_entry_dao.dart
│   │   └── providers.dart
│   ├── domain/                # Business logic
│   │   └── helpers.dart
│   ├── presentation/          # UI layer
│   │   ├── workspaces/
│   │   ├── tracker/
│   │   └── analytics/
│   └── l10n/                  # Internationalization
│       ├── intl_en.arb
│       └── intl_fa.arb
├── test/                      # Tests
│   ├── unit/
│   └── widget/
├── android/                   # Android config
└── pubspec.yaml              # Dependencies
```

## Next Steps

1. **Explore the App**: Run it and try creating workspaces and entries
2. **Read the Code**: Start from `lib/main.dart` and follow the flow
3. **Run Tests**: Ensure all tests pass
4. **Make Changes**: Try modifying the UI or adding features
5. **Check CI**: Push to GitHub and watch the CI pipeline

## Useful Commands Reference

```bash
# Check Flutter version
flutter --version

# Get dependencies
flutter pub get

# Run app
flutter run

# Run tests
flutter test

# Build APK
flutter build apk --release

# Analyze code
flutter analyze

# Format code
flutter format .

# Clean build
flutter clean

# Generate localization
flutter gen-l10n

# List devices
flutter devices

# Check setup
flutter doctor -v
```

## Support

- Check [README.md](README.md) for detailed documentation
- See [CHANGELOG.md](CHANGELOG.md) for version history
- Review [LICENSES.md](LICENSES.md) for dependency licenses

Happy coding! 🚀
