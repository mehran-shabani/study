/// Application-wide constants
class AppConstants {
  AppConstants._();

  // Database
  static const String dbName = 'study.db';
  static const int dbVersion = 1;

  // Validation limits
  static const int maxWorkspaceNameLength = 50;
  static const int maxEntryTitleLength = 80;
  static const double minHours = 0.25;
  static const double maxHours = 24.0;

  // Date format
  static const String dateFormat = 'yyyy-MM-dd';

  // Chart settings
  static const int minTargetFps = 60;
  static const int maxChartRenderMs = 100;
  static const int maxDataPoints = 365;

  // Default values
  static const double avgDailyTargetHours = 4.0;
}
