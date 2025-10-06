import 'package:intl/intl.dart';
import 'constants.dart';

/// Utility functions for common operations
class AppUtils {
  AppUtils._();

  /// Format a DateTime to yyyy-MM-dd string
  static String formatDate(DateTime date) {
    return DateFormat(AppConstants.dateFormat).format(date);
  }

  /// Parse yyyy-MM-dd string to DateTime
  static DateTime parseDate(String dateStr) {
    return DateFormat(AppConstants.dateFormat).parse(dateStr);
  }

  /// Get today's date as yyyy-MM-dd string
  static String today() {
    return formatDate(DateTime.now());
  }

  /// Validate workspace name
  static String? validateWorkspaceName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Name is required';
    }
    if (value.length > AppConstants.maxWorkspaceNameLength) {
      return 'Name must be ${AppConstants.maxWorkspaceNameLength} characters or less';
    }
    return null;
  }

  /// Validate date string format
  static String? validateDate(String? value) {
    if (value == null || value.isEmpty) {
      return 'Date is required';
    }
    // Enforce strict yyyy-MM-dd format first
    final strictPattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');
    if (!strictPattern.hasMatch(value)) {
      return 'Invalid date format (use yyyy-MM-dd)';
    }
    try {
      final parsed = DateFormat(AppConstants.dateFormat).parse(value);
      // Re-format and compare to ensure zero-padding and a valid calendar date
      final normalized = formatDate(parsed);
      if (normalized != value) {
        return 'Invalid date format (use yyyy-MM-dd)';
      }
      return null;
    } catch (e) {
      return 'Invalid date format (use yyyy-MM-dd)';
    }
  }

  /// Validate date range (end must be after start)
  static String? validateDateRange(String startDate, String endDate) {
    try {
      final start = parseDate(startDate);
      final end = parseDate(endDate);
      if (end.isBefore(start)) {
        return 'End date must be after start date';
      }
      return null;
    } catch (e) {
      return 'Invalid date range';
    }
  }

  /// Validate entry title
  static String? validateEntryTitle(String? value) {
    if (value == null || value.isEmpty) {
      return 'Title is required';
    }
    if (value.length > AppConstants.maxEntryTitleLength) {
      return 'Title must be ${AppConstants.maxEntryTitleLength} characters or less';
    }
    return null;
  }

  /// Validate hours value
  static String? validateHours(String? value) {
    if (value == null || value.isEmpty) {
      return 'Hours is required';
    }
    final hours = double.tryParse(value);
    if (hours == null) {
      return 'Invalid number';
    }
    if (hours < AppConstants.minHours) {
      return 'Minimum ${AppConstants.minHours} hours';
    }
    if (hours > AppConstants.maxHours) {
      return 'Maximum ${AppConstants.maxHours} hours';
    }
    return null;
  }

  /// Calculate days between two dates (inclusive)
  static int daysBetween(DateTime start, DateTime end) {
    final startDate = DateTime(start.year, start.month, start.day);
    final endDate = DateTime(end.year, end.month, end.day);
    return endDate.difference(startDate).inDays + 1;
  }

  /// Format hours to display string (e.g., "2.5h", "1.0h")
  static String formatHours(double hours) {
    return '${hours.toStringAsFixed(1)}h';
  }

  /// Format percentage (e.g., "75.5%")
  static String formatPercentage(double percentage) {
    return '${percentage.toStringAsFixed(1)}%';
  }
}
